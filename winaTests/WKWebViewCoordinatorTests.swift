import SwiftUI
import WebKit
import XCTest
@testable import wina

final class WKWebViewCoordinatorTests: XCTestCase {
    private static var retainedNavigators: [WebViewNavigator] = []

    private final class CoordinatorSpyNavigator: WebViewNavigator {
        var syncCallCount: Int = 0
        var onSync: (() -> Void)?

        override func syncErudaWithSettings() async {
            syncCallCount += 1
            onSync?()
        }
    }

    private final class ErudaSyncSpyNavigator: WebViewNavigator {
        var injectCallCount: Int = 0
        var destroyCallCount: Int = 0

        override func injectEruda() async {
            injectCallCount += 1
        }

        override func destroyEruda() async {
            destroyCallCount += 1
        }
    }

    @MainActor
    func testDidFinishTriggersErudaSync() {
        // didFinish 이후 Eruda 동기화가 항상 한 번 호출되는지 확인합니다.
        var isLoading = false
        let binding = Binding(
            get: { isLoading },
            set: { isLoading = $0 }
        )
        let navigator = CoordinatorSpyNavigator()
        Self.retainedNavigators.append(navigator)
        let expectation = expectation(description: "sync called")
        navigator.onSync = {
            expectation.fulfill()
        }

        let coordinator = WKWebViewCoordinator(isLoading: binding, navigator: navigator)
        let webView = WKWebView(frame: .zero)

        coordinator.webView(webView, didFinish: nil)

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(navigator.syncCallCount, 1)
    }

    @MainActor
    func testSyncErudaWithSettingsCallsInjectWhenEnabled() async {
        // 설정값이 true면 inject 경로를 타는지 검증합니다.
        let defaults = UserDefaults.standard
        let key = "erudaModeEnabled"
        let previousValue = defaults.object(forKey: key)
        defer {
            if let previousValue {
                defaults.set(previousValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        defaults.set(true, forKey: key)

        let navigator = ErudaSyncSpyNavigator()
        Self.retainedNavigators.append(navigator)
        navigator.attach(to: WKWebView(frame: .zero))

        await navigator.syncErudaWithSettings()

        XCTAssertEqual(navigator.injectCallCount, 1)
        XCTAssertEqual(navigator.destroyCallCount, 0)
    }

    @MainActor
    func testSyncErudaWithSettingsCallsDestroyWhenDisabled() async {
        // 설정값이 false면 destroy 경로를 타는지 검증합니다.
        let defaults = UserDefaults.standard
        let key = "erudaModeEnabled"
        let previousValue = defaults.object(forKey: key)
        defer {
            if let previousValue {
                defaults.set(previousValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        defaults.set(false, forKey: key)

        let navigator = ErudaSyncSpyNavigator()
        Self.retainedNavigators.append(navigator)
        navigator.attach(to: WKWebView(frame: .zero))

        await navigator.syncErudaWithSettings()

        XCTAssertEqual(navigator.injectCallCount, 0)
        XCTAssertEqual(navigator.destroyCallCount, 1)
    }
}
