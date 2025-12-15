# WKWebView CORS Bypass 방법

## 현재 문제

1. **Network 탭**: fetch/XHR 훅으로 요청은 캡처하지만, cross-origin response body는 CORS 정책으로 읽기 불가
2. **Sources 탭**: 외부 스크립트/스타일시트 내용을 `fetch()`로 가져올 수 없음 (CORS 차단)
3. **정적 리소스**: 브라우저가 직접 로드하는 리소스(img, script, link)는 JS 훅 대상 아님

## 해결 방법

### 1. WKScriptMessageHandler 네이티브 프록시 (권장)

현재 프로젝트에서 이미 `consoleLog`, `networkRequest` 등에 이 패턴 사용 중. 확장만 하면 됨.

```
[JS] postMessage(url) → [Swift URLSession] → fetch 성공 → [JS] 콜백으로 결과 수신
```

**장점**:
- App Store 제출 가능
- 기존 코드 구조와 일치
- URLSession은 CORS 정책 적용 안 받음

**구현 위치**:
- `WebViewContainer.swift` Coordinator에 `fetchProxy` 핸들러 추가
- `WebViewScripts+Network.swift`에 프록시 호출 함수 추가

### 2. WKURLSchemeHandler

커스텀 스킴(`app://`)으로 요청 가로채서 네이티브가 대신 fetch.

```swift
config.setURLSchemeHandler(CORSBypassHandler(), forURLScheme: "app")
```

**단점**: 모든 URL을 커스텀 스킴으로 변환해야 함. 복잡도 높음.

### 3. Private API (비추천)

`_setWebSecurityEnabled:` 등 비공개 API로 CORS 완전 비활성화.

**단점**: App Store 리젝 사유. 디버깅/엔터프라이즈 앱 전용.

## 구현 계획 (방법 1 기준)

### Swift 측

```swift
// WebViewContainer.swift Coordinator
userContentController.add(context.coordinator, name: "fetchProxy")

func handleFetchProxy(_ message: WKScriptMessage) {
    guard let body = message.body as? [String: Any],
          let urlString = body["url"] as? String,
          let callbackId = body["callbackId"] as? String,
          let url = URL(string: urlString) else { return }

    Task {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            let text = String(data: data, encoding: .utf8) ?? ""
            let httpResponse = response as? HTTPURLResponse

            // JS 콜백 호출
            let script = """
                window.__fetchProxyCallbacks['\(callbackId)']({
                    ok: true,
                    status: \(httpResponse?.statusCode ?? 200),
                    body: \(text.jsonEscaped)
                });
                delete window.__fetchProxyCallbacks['\(callbackId)'];
            """
            await webView?.evaluateJavaScript(script)
        } catch {
            // 에러 콜백
        }
    }
}
```

### JS 측

```javascript
window.__fetchProxyCallbacks = {};

window.nativeFetch = function(url) {
    return new Promise(function(resolve, reject) {
        var callbackId = generateId();
        window.__fetchProxyCallbacks[callbackId] = function(result) {
            if (result.ok) resolve(result);
            else reject(result.error);
        };
        window.webkit.messageHandlers.fetchProxy.postMessage({
            url: url,
            callbackId: callbackId
        });
    });
};
```

### 사용 예시

```javascript
// CORS 차단되는 외부 스크립트 내용 가져오기
nativeFetch('https://cdn.example.com/app.js')
    .then(result => console.log(result.body));
```

## 적용 대상

1. **Sources 탭**: 외부 스크립트/CSS 내용 조회
2. **Network 탭**: CORS로 response body 못 읽는 경우 fallback
3. **기타**: cross-origin 리소스 내용이 필요한 모든 곳

## 참고 자료

- [WKWebView CORS Solution - Thor Chen](https://zzdjk6.medium.com/wkwebview-cors-solution-da20ca1194e8)
- [Disable Same Origin Policy in iOS WKWebView](https://worthdoingbadly.com/disablesameorigin/)
