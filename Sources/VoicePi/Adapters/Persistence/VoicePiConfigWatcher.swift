import Darwin
import Foundation

enum VoicePiConfigWatcherError: LocalizedError {
    case openFailed(URL)

    var errorDescription: String? {
        switch self {
        case .openFailed(let url):
            return "Failed to open watched file at \(url.path)."
        }
    }
}

final class VoicePiConfigWatcher {
    private struct WatchedSource {
        let source: DispatchSourceFileSystemObject
    }

    private let urls: [URL]
    private let debounceInterval: TimeInterval
    private let queue: DispatchQueue
    private let fileManager: FileManager
    private let onChange: @Sendable () -> Void

    private var sources: [WatchedSource] = []
    private var pendingDebounceWorkItem: DispatchWorkItem?

    init(
        urls: [URL],
        debounceInterval: TimeInterval = 0.2,
        queue: DispatchQueue = DispatchQueue(label: "VoicePi.ConfigWatcher"),
        fileManager: FileManager = .default,
        onChange: @escaping @Sendable () -> Void
    ) {
        self.urls = urls
        self.debounceInterval = debounceInterval
        self.queue = queue
        self.fileManager = fileManager
        self.onChange = onChange
    }

    convenience init(
        paths: VoicePiConfigPaths,
        debounceInterval: TimeInterval = 0.2,
        queue: DispatchQueue = DispatchQueue(label: "VoicePi.ConfigWatcher"),
        fileManager: FileManager = .default,
        onChange: @escaping @Sendable () -> Void
    ) {
        self.init(
            urls: [
                paths.configFileURL,
                paths.userPromptURL,
                paths.promptPresetsDirectoryURL,
                paths.dictionaryURL,
                paths.dictionarySuggestionsURL,
                paths.processorsURL,
                paths.promptWorkspaceURL
            ],
            debounceInterval: debounceInterval,
            queue: queue,
            fileManager: fileManager,
            onChange: onChange
        )
    }

    func start() throws {
        pendingDebounceWorkItem?.cancel()
        pendingDebounceWorkItem = nil
        try rebuildSources()
    }

    func stop() {
        pendingDebounceWorkItem?.cancel()
        pendingDebounceWorkItem = nil

        clearSources()
    }

    private func clearSources() {
        for watched in sources {
            watched.source.cancel()
        }
        sources.removeAll()
    }

    private func rebuildSources() throws {
        clearSources()

        for url in urls {
            try ensureFileExists(at: url)
            let descriptor = open(url.path, O_EVTONLY)
            guard descriptor >= 0 else {
                throw VoicePiConfigWatcherError.openFailed(url)
            }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor,
                eventMask: [.write, .extend, .rename, .delete, .attrib],
                queue: queue
            )

            source.setEventHandler { [weak self] in
                self?.handleFileSystemEvent()
            }

            source.setCancelHandler {
                close(descriptor)
            }

            source.resume()
            sources.append(.init(source: source))
        }
    }

    deinit {
        stop()
    }

    private func handleFileSystemEvent() {
        scheduleDebouncedCallback()
        try? rebuildSources()
    }

    private func scheduleDebouncedCallback() {
        pendingDebounceWorkItem?.cancel()
        let item = DispatchWorkItem { [onChange] in
            onChange()
        }
        pendingDebounceWorkItem = item
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: item)
    }

    private func ensureFileExists(at url: URL) throws {
        if url.hasDirectoryPath {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            return
        }

        let directory = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        if !fileManager.fileExists(atPath: url.path) {
            try Data().write(to: url, options: .atomic)
        }
    }
}
