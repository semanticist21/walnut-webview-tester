# WKWebView 디버깅 도구 구현 가능 여부 메모

## 구현 가능한 기능들

| 기능 | 가능 여부 | 구현 방법 |
|------|----------|----------|
| Console | ✅ 가능 | `WKScriptMessageHandler` + JS 주입으로 console 메서드 후킹 |
| Network | ⚠️ 부분 가능 | JS로 fetch/XHR 후킹 (완전한 네이티브 인터셉트는 제한적) |
| Performance | ✅ 가능 | JS Performance API 데이터 수집 |
| 스크린샷 | ✅ 가능 | `WKWebView.takeSnapshot()` 네이티브 API |
| DOM Tree | ✅ 가능 | JS로 DOM 트리 추출 → UI 표시 |
| CSS 추출 | ✅ 가능 | `classList`, `getComputedStyle()`, `document.styleSheets` |

---

## Console 로그 캡처

```swift
let script = """
(function() {
    const originalLog = console.log;
    console.log = function(...args) {
        window.webkit.messageHandlers.console.postMessage({
            type: 'log',
            message: args.map(a => String(a)).join(' ')
        });
        originalLog.apply(console, args);
    };
    // error, warn, info도 동일하게 처리
})();
"""
```

---

## DOM Tree 추출

```javascript
(function() {
    function serializeNode(node) {
        const obj = {
            type: node.nodeType,
            name: node.nodeName,
            children: []
        };
        if (node.nodeType === 1) { // Element
            obj.attributes = {};
            for (const attr of node.attributes) {
                obj.attributes[attr.name] = attr.value;
            }
        }
        if (node.nodeType === 3) { // Text
            obj.text = node.textContent.trim();
        }
        for (const child of node.childNodes) {
            obj.children.push(serializeNode(child));
        }
        return obj;
    }
    return JSON.stringify(serializeNode(document.documentElement));
})();
```

---

## CSS 추출

```javascript
// 요소의 클래스 목록
element.classList          // ['btn', 'btn-primary', 'active']
element.className          // "btn btn-primary active"

// 적용된 모든 computed 스타일
getComputedStyle(element)

// 페이지의 모든 스타일시트 규칙
Array.from(document.styleSheets).flatMap(sheet => {
    try {
        return Array.from(sheet.cssRules).map(rule => ({
            selector: rule.selectorText,
            styles: rule.cssText
        }));
    } catch(e) { return []; } // CORS 제한된 외부 CSS
});
```

---

## Performance API (W3C 표준)

```javascript
JSON.stringify({
    navigation: performance.getEntriesByType('navigation'),
    resources: performance.getEntriesByType('resource'),
    paint: performance.getEntriesByType('paint')
    // memory는 Chrome 전용, Safari 미지원
})
```

### Safari(WKWebView) 지원 여부

- ✅ `navigation` - 페이지 로딩 타이밍
- ✅ `resource` - 리소스별 로딩 타이밍
- ✅ `paint` - First Paint, First Contentful Paint
- ❌ `memory` - Chrome 전용

---

## 스크린샷

```swift
webView.takeSnapshot(with: nil) { image, error in
    if let image = image {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
}
```

---

## 제한사항

1. **Safari Web Inspector 수준의 완전한 기능은 불가능**
   - 소스 디버깅(breakpoint)은 Safari 연결 필요
   - 실시간 CSS 편집은 복잡한 구현 필요

2. **Network 완전 인터셉트 불가**
   - WebSocket, 이미지 로딩 등 일부는 JS 후킹으로 캡처 어려움
   - `URLProtocol`은 WKWebView에서 작동 안 함
   - `WKURLSchemeHandler`는 커스텀 스킴만 처리 가능

3. **외부 CSS 접근 제한**
   - CORS 정책으로 외부 도메인 스타일시트 규칙 읽기 불가

4. **SafariVC: Clear Website Data** (iOS 16+) - `SFSafariViewController.DataStore.default.clearWebsiteData()` 추가 고려
