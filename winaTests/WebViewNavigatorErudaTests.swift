import WebKit
import XCTest
@testable import wina

@MainActor
final class WebViewNavigatorErudaTests: XCTestCase {
    private static var retainedNavigators: [WebViewNavigator] = []

    private final class ErudaScriptSpyNavigator: WebViewNavigator {
        static let testBundleScript = "window.__wina_test_eruda_bundle_loaded__ = true;"

        var loadedResponses: [Bool] = []
        var entryResponses: [Bool] = []

        var loadedCheckCount: Int = 0
        var entryCheckCount: Int = 0
        var bundleLoadCount: Int = 0
        var initScriptCount: Int = 0
        var reinitializeScriptCount: Int = 0
        var ensureVisibleScriptCount: Int = 0

        override func erudaBundleScript() -> String? {
            Self.testBundleScript
        }

        override func evaluateJavaScript(_ script: String) async -> Any? {
            if script == WebViewNavigator.erudaLoadedCheckScript {
                loadedCheckCount += 1
                if !loadedResponses.isEmpty {
                    return loadedResponses.removeFirst()
                }
                return false
            }
            if script == WebViewNavigator.erudaEntryButtonCheckScript {
                entryCheckCount += 1
                if !entryResponses.isEmpty {
                    return entryResponses.removeFirst()
                }
                return false
            }
            if script == Self.testBundleScript {
                bundleLoadCount += 1
                return nil
            }
            if script == WebViewNavigator.erudaInitializeScript {
                initScriptCount += 1
                return nil
            }
            if script == WebViewNavigator.erudaReinitializeScript {
                reinitializeScriptCount += 1
                return nil
            }
            if script == WebViewNavigator.erudaEnsureEntryVisibleScript {
                ensureVisibleScriptCount += 1
                return nil
            }
            return nil
        }
    }

    private func makeNavigator() -> ErudaScriptSpyNavigator {
        // webView attach guard를 통과시키기 위해 테스트용 WKWebView를 연결합니다.
        let navigator = ErudaScriptSpyNavigator()
        navigator.attach(to: WKWebView(frame: .zero))
        Self.retainedNavigators.append(navigator)
        return navigator
    }

    func testInjectErudaInitializesWhenLoadedButEntryButtonMissing() async {
        // 로드된 상태지만 엔트리 버튼이 없으면 init 경로를 다시 타야 합니다.
        let navigator = makeNavigator()
        navigator.loadedResponses = [true]
        navigator.entryResponses = [false]

        await navigator.injectEruda()

        XCTAssertEqual(navigator.bundleLoadCount, 0)
        XCTAssertEqual(navigator.initScriptCount, 1)
        XCTAssertEqual(navigator.ensureVisibleScriptCount, 0)
    }

    func testInjectErudaEnsuresVisibilityWhenEntryButtonExists() async {
        // 엔트리 버튼이 이미 있으면 재초기화 대신 표시 복구만 수행해야 합니다.
        let navigator = makeNavigator()
        navigator.loadedResponses = [true]
        navigator.entryResponses = [true]

        await navigator.injectEruda()

        XCTAssertEqual(navigator.bundleLoadCount, 0)
        XCTAssertEqual(navigator.initScriptCount, 0)
        XCTAssertEqual(navigator.ensureVisibleScriptCount, 1)
    }

    func testInjectErudaLoadsBundleThenInitializesWhenMissing() async {
        // 미로드 상태라면 번들 주입 후 init까지 이어져야 합니다.
        let navigator = makeNavigator()
        navigator.loadedResponses = [false, true]
        navigator.entryResponses = [false]

        await navigator.injectEruda()

        XCTAssertEqual(navigator.loadedCheckCount, 2)
        XCTAssertEqual(navigator.bundleLoadCount, 1)
        XCTAssertEqual(navigator.initScriptCount, 1)
    }

    func testInjectErudaForceInitRunsReinitializeScript() async {
        // 새로고침 강제 경로에서는 재초기화 스크립트를 반드시 실행해야 합니다.
        let navigator = makeNavigator()
        navigator.loadedResponses = [true]

        await navigator.injectEruda(forceInit: true)

        XCTAssertEqual(navigator.reinitializeScriptCount, 1)
        XCTAssertEqual(navigator.entryCheckCount, 0)
    }

    func testInjectErudaForceInitLoadsBundleWhenMissing() async {
        // force-init이어도 미로드 상태면 번들 주입 후 재초기화가 이어져야 합니다.
        let navigator = makeNavigator()
        navigator.loadedResponses = [false, true]

        await navigator.injectEruda(forceInit: true)

        XCTAssertEqual(navigator.loadedCheckCount, 2)
        XCTAssertEqual(navigator.bundleLoadCount, 1)
        XCTAssertEqual(navigator.reinitializeScriptCount, 1)
        XCTAssertEqual(navigator.entryCheckCount, 0)
    }

    func testReloadCallsPreparationHandler() {
        // navigator.reload()가 coordinator 준비 콜백을 반드시 호출해야 합니다.
        let navigator = WebViewNavigator()
        // 테스트 종료 시점 deinit 경로 크래시를 피하기 위해 기존 테스트 패턴과 동일하게 보존합니다.
        Self.retainedNavigators.append(navigator)
        var callCount = 0
        navigator.setReloadPreparationHandler {
            callCount += 1
        }

        navigator.reload()

        XCTAssertEqual(callCount, 1)
    }
}
