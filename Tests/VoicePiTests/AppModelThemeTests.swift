import Foundation
import Testing
@testable import VoicePi

struct AppModelThemeTests {
    @Test
    @MainActor
    func interfaceThemeProvidesSegmentLabelsAndSymbols() {
        #expect(InterfaceTheme.allCases.map(\.title) == ["System", "Light", "Dark"])
        #expect(InterfaceTheme.allCases.map(\.symbolName) == ["circle.lefthalf.filled", "sun.max", "moon"])
    }

    @Test
    @MainActor
    func interfaceThemeDefaultsToSystem() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.interfaceThemeDefaultsToSystem.\(UUID().uuidString)")!
        defaults.removePersistentDomain(forName: defaultsSuiteName(defaults))

        let model = AppModel(defaults: defaults)

        #expect(model.interfaceTheme == .system)
    }

    @Test
    @MainActor
    func interfaceThemePersistsAcrossModelInstances() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.interfaceThemePersistsAcrossModelInstances.\(UUID().uuidString)")!
        defaults.removePersistentDomain(forName: defaultsSuiteName(defaults))

        let model = AppModel(defaults: defaults)
        model.interfaceTheme = .dark

        let reloadedModel = AppModel(defaults: defaults)

        #expect(reloadedModel.interfaceTheme == .dark)
    }

    @Test
    @MainActor
    func interfaceThemeWritesExpectedRawValue() {
        let defaults = UserDefaults(suiteName: "VoicePiTests.interfaceThemeWritesExpectedRawValue.\(UUID().uuidString)")!
        defaults.removePersistentDomain(forName: defaultsSuiteName(defaults))

        let model = AppModel(defaults: defaults)
        model.interfaceTheme = .light

        #expect(defaults.string(forKey: AppModel.Keys.interfaceTheme) == InterfaceTheme.light.rawValue)
    }

    private func defaultsSuiteName(_ defaults: UserDefaults) -> String {
        defaults.volatileDomainNames.first { $0 != UserDefaults.globalDomain } ?? ""
    }
}
