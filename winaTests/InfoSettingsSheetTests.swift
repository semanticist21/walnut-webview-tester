import SwiftUI
import XCTest

@testable import wina

final class InfoSettingsSheetTests: XCTestCase {
    private func localizedKeyValue(_ key: LocalizedStringKey) -> String {
        let mirror = Mirror(reflecting: key)
        for child in mirror.children {
            if child.label == "key", let value = child.value as? String {
                return value
            }
        }
        return String(describing: key)
    }

    func testSafariVCInfoViewUsesBindingForWebViewID() {
        var id = UUID()
        let binding = Binding(get: { id }, set: { id = $0 })
        var view = SafariVCInfoView(webViewID: binding)

        XCTAssertEqual(view.webViewID, id)

        let newID = UUID()
        view.webViewID = newID
        XCTAssertEqual(id, newID)
    }

    func testInfoViewStoresBindingsWhenProvided() {
        var id = UUID()
        var url = "https://example.com"
        let idBinding = Binding(get: { id }, set: { id = $0 })
        let urlBinding = Binding(get: { url }, set: { url = $0 })
        let view = InfoView(navigator: nil, webViewID: idBinding, loadedURL: urlBinding)

        XCTAssertEqual(view.webViewID?.wrappedValue, id)
        XCTAssertEqual(view.loadedURL?.wrappedValue, url)

        let newID = UUID()
        let newURL = "https://apple.com"
        view.webViewID?.wrappedValue = newID
        view.loadedURL?.wrappedValue = newURL

        XCTAssertEqual(id, newID)
        XCTAssertEqual(url, newURL)
    }

    func testLiveSettingsDescriptionCopy() {
        XCTAssertEqual(localizedKeyValue(SettingsCopy.liveSettingsDescription), "Apply to save changes")
    }
}
