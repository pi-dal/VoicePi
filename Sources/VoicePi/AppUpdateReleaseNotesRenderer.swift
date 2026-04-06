import AppKit
import Foundation

enum AppUpdateReleaseNotesRenderer {
    static func attributedString(
        from markdown: String,
        textColor: NSColor = .secondaryLabelColor
    ) -> NSAttributedString {
        let output = NSMutableAttributedString()
        let blocks = parseBlocks(markdown)
        var collectedLinks: [URL] = []
        var seenLinks: Set<String> = []

        for (index, block) in blocks.enumerated() {
            if index > 0 {
                output.append(NSAttributedString(string: "\n"))
            }

            switch block {
            case .heading(let level, let text):
                let rendered = inlineAttributedString(
                    from: text,
                    attributes: headingAttributes(level: level, textColor: textColor),
                    textColor: textColor
                )
                output.append(rendered)
                collectLinks(from: rendered, links: &collectedLinks, seen: &seenLinks)
            case .unorderedListItem(let text):
                let rendered = listItemAttributedString(
                    marker: "•\t",
                    text: text,
                    attributes: listAttributes(textColor: textColor),
                    textColor: textColor
                )
                output.append(rendered)
                collectLinks(from: rendered, links: &collectedLinks, seen: &seenLinks)
            case .orderedListItem(let number, let text):
                let rendered = listItemAttributedString(
                    marker: "\(number).\t",
                    text: text,
                    attributes: listAttributes(textColor: textColor),
                    textColor: textColor
                )
                output.append(rendered)
                collectLinks(from: rendered, links: &collectedLinks, seen: &seenLinks)
            case .paragraph(let text):
                let rendered = inlineAttributedString(
                    from: text,
                    attributes: bodyAttributes(textColor: textColor),
                    textColor: textColor
                )
                output.append(rendered)
                collectLinks(from: rendered, links: &collectedLinks, seen: &seenLinks)
            }
        }

        appendLinkReferences(
            to: output,
            links: collectedLinks,
            textColor: textColor
        )

        return output
    }

    private enum Block {
        case heading(level: Int, text: String)
        case unorderedListItem(text: String)
        case orderedListItem(number: Int, text: String)
        case paragraph(text: String)
    }

    private static func parseBlocks(_ markdown: String) -> [Block] {
        let lines = markdown.components(separatedBy: .newlines)
        var blocks: [Block] = []
        var paragraphLines: [String] = []

        func flushParagraph() {
            let text = paragraphLines
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")

            guard !text.isEmpty else {
                paragraphLines.removeAll(keepingCapacity: true)
                return
            }

            blocks.append(.paragraph(text: text))
            paragraphLines.removeAll(keepingCapacity: true)
        }

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.isEmpty {
                flushParagraph()
                continue
            }

            if let heading = headingBlock(from: line) {
                flushParagraph()
                blocks.append(heading)
                continue
            }

            if let listItem = unorderedListBlock(from: line) {
                flushParagraph()
                blocks.append(listItem)
                continue
            }

            if let listItem = orderedListBlock(from: line) {
                flushParagraph()
                blocks.append(listItem)
                continue
            }

            paragraphLines.append(line)
        }

        flushParagraph()
        return blocks
    }

    private static func headingBlock(from line: String) -> Block? {
        guard line.first == "#" else { return nil }

        let level = line.prefix(while: { $0 == "#" }).count
        let text = line.dropFirst(level).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        return .heading(level: level, text: text)
    }

    private static func unorderedListBlock(from line: String) -> Block? {
        guard let marker = line.first, ["-", "*", "+"].contains(marker) else { return nil }

        let text = line.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        return .unorderedListItem(text: text)
    }

    private static func orderedListBlock(from line: String) -> Block? {
        let digits = line.prefix(while: \.isNumber)
        guard !digits.isEmpty else { return nil }

        let remainder = line.dropFirst(digits.count)
        guard remainder.first == "." else { return nil }

        let text = remainder.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let number = Int(digits) else { return nil }

        return .orderedListItem(number: number, text: text)
    }

    private static func listItemAttributedString(
        marker: String,
        text: String,
        attributes: [NSAttributedString.Key: Any],
        textColor: NSColor
    ) -> NSAttributedString {
        let line = NSMutableAttributedString(
            string: marker,
            attributes: attributes
        )
        line.append(
            inlineAttributedString(
                from: text,
                attributes: attributes,
                textColor: textColor
            )
        )
        return line
    }

    private static func inlineAttributedString(
        from text: String,
        attributes: [NSAttributedString.Key: Any],
        textColor: NSColor
    ) -> NSAttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        guard let parsed = try? AttributedString(markdown: text, options: options) else {
            return NSAttributedString(string: text, attributes: attributes)
        }

        let rendered = NSMutableAttributedString(attributedString: NSAttributedString(parsed))
        let fullRange = NSRange(location: 0, length: rendered.length)
        guard fullRange.length > 0 else {
            return NSAttributedString(string: text, attributes: attributes)
        }

        if let paragraphStyle = attributes[.paragraphStyle] {
            rendered.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
        }

        if let baseFont = attributes[.font] as? NSFont {
            applyBaseFont(baseFont, to: rendered)
        } else {
            rendered.addAttribute(.font, value: NSFont.systemFont(ofSize: 12), range: fullRange)
        }

        rendered.addAttribute(.foregroundColor, value: textColor, range: fullRange)
        rendered.enumerateAttribute(.link, in: fullRange, options: []) { value, range, _ in
            guard value != nil else { return }
            rendered.addAttribute(.foregroundColor, value: NSColor.linkColor, range: range)
            rendered.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }

        return rendered
    }

    private static func applyBaseFont(
        _ baseFont: NSFont,
        to attributedString: NSMutableAttributedString
    ) {
        let fullRange = NSRange(location: 0, length: attributedString.length)
        guard fullRange.length > 0 else { return }

        attributedString.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
            let sourceFont = (value as? NSFont) ?? baseFont
            attributedString.addAttribute(
                .font,
                value: mappedFont(baseFont: baseFont, sourceFont: sourceFont),
                range: range
            )
        }
    }

    private static func mappedFont(baseFont: NSFont, sourceFont: NSFont) -> NSFont {
        let manager = NSFontManager.shared
        let traits = manager.traits(of: sourceFont)
        let weight: NSFont.Weight = traits.contains(.boldFontMask) ? .semibold : .regular
        var mapped = traits.contains(.fixedPitchFontMask)
            ? NSFont.monospacedSystemFont(ofSize: baseFont.pointSize, weight: weight)
            : NSFont.systemFont(ofSize: baseFont.pointSize, weight: weight)

        if traits.contains(.italicFontMask) {
            mapped = manager.convert(mapped, toHaveTrait: .italicFontMask)
        }

        return mapped
    }

    private static func collectLinks(
        from attributedString: NSAttributedString,
        links: inout [URL],
        seen: inout Set<String>
    ) {
        let fullRange = NSRange(location: 0, length: attributedString.length)
        guard fullRange.length > 0 else { return }

        attributedString.enumerateAttribute(.link, in: fullRange, options: []) { value, _, _ in
            let url: URL?
            if let typed = value as? URL {
                url = typed
            } else if let raw = value as? String {
                url = URL(string: raw)
            } else {
                url = nil
            }

            guard let url else { return }
            let key = url.absoluteString
            guard !seen.contains(key) else { return }
            seen.insert(key)
            links.append(url)
        }
    }

    private static func appendLinkReferences(
        to output: NSMutableAttributedString,
        links: [URL],
        textColor: NSColor
    ) {
        guard !links.isEmpty else { return }

        if output.length > 0 {
            output.append(NSAttributedString(string: "\n\n"))
        }

        output.append(
            NSAttributedString(
                string: "Links",
                attributes: headingAttributes(level: 3, textColor: textColor)
            )
        )
        output.append(NSAttributedString(string: "\n"))

        for (index, url) in links.enumerated() {
            let line = NSMutableAttributedString(
                string: "\(index + 1).\t",
                attributes: listAttributes(textColor: textColor)
            )
            line.append(
                NSAttributedString(
                    string: url.absoluteString,
                    attributes: linkReferenceAttributes(
                        textColor: textColor,
                        url: url
                    )
                )
            )
            output.append(line)

            if index < links.count - 1 {
                output.append(NSAttributedString(string: "\n"))
            }
        }
    }

    private static func linkReferenceAttributes(
        textColor: NSColor,
        url: URL
    ) -> [NSAttributedString.Key: Any] {
        var attributes = listAttributes(textColor: textColor)
        attributes[.link] = url
        attributes[.foregroundColor] = NSColor.linkColor
        attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        return attributes
    }

    private static func headingAttributes(level: Int, textColor: NSColor) -> [NSAttributedString.Key: Any] {
        let clampedLevel = min(max(level, 1), 6)
        let fontSize = switch clampedLevel {
        case 1: 17.0
        case 2: 15.0
        case 3: 14.0
        default: 13.0
        }

        let style = NSMutableParagraphStyle()
        style.paragraphSpacing = 6

        return [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: textColor,
            .paragraphStyle: style
        ]
    }

    private static func bodyAttributes(textColor: NSColor) -> [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.paragraphSpacing = 6

        return [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: textColor,
            .paragraphStyle: style
        ]
    }

    private static func listAttributes(textColor: NSColor) -> [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.defaultTabInterval = 16
        style.tabStops = [NSTextTab(textAlignment: .left, location: 16)]
        style.firstLineHeadIndent = 0
        style.headIndent = 16
        style.paragraphSpacing = 4

        return [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: textColor,
            .paragraphStyle: style
        ]
    }
}
