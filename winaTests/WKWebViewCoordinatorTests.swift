import SwiftUI
import WebKit
import XCTest
@testable import wina

final class WKWebViewCoordinatorTests: XCTestCase {
    private static var retainedNavigators: [WebViewNavigator] = []

    private final class CoordinatorSpyNavigator: WebViewNavigator {
        var syncCallCount: Int = 0
        var syncForceInitValues: [Bool] = []
        var onSync: (() -> Void)?

        override func syncErudaWithSettings(forceInit: Bool = false) async {
            syncCallCount += 1
            syncForceInitValues.append(forceInit)
            onSync?()
        }
    }

    private final class ErudaSyncSpyNavigator: WebViewNavigator {
        var injectCallCount: Int = 0
        var destroyCallCount: Int = 0

        override func injectEruda(forceInit: Bool = false) async {
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
        XCTAssertEqual(navigator.syncForceInitValues, [false])
    }

    @MainActor
    func testDidFinishUsesForceInitWhenScheduled() {
        // reload 예약 플래그가 있으면 forceInit=true로 동기화되는지 확인합니다.
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

        coordinator.scheduleForceErudaInitOnNextFinish()
        coordinator.webView(webView, didFinish: nil)

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(navigator.syncForceInitValues.last, true)
    }

    @MainActor
    func testDidFailClearsPendingForceInitFlag() {
        // reload 실패 후에는 다음 didFinish에 forceInit이 남지 않아야 합니다.
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

        coordinator.scheduleForceErudaInitOnNextFinish()
        coordinator.webView(webView, didFail: nil, withError: URLError(.timedOut))
        coordinator.webView(webView, didFinish: nil)

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(navigator.syncForceInitValues.last, false)
    }

    @MainActor
    func testDidFailProvisionalNavigationClearsPendingForceInitFlag() {
        // provisional 실패 후에도 forceInit 잔존 없이 동기화되어야 합니다.
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

        coordinator.scheduleForceErudaInitOnNextFinish()
        coordinator.webView(webView, didFailProvisionalNavigation: nil, withError: URLError(.cannotFindHost))
        coordinator.webView(webView, didFinish: nil)

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(navigator.syncForceInitValues.last, false)
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
