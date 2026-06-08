# SafariVC OAuth 콜백 캡처 기능 조사

## 요약

SafariVC 자체는 웹 콘텐츠 접근 불가하지만, **OAuth 리다이렉트 콜백은 캡처 가능**.
URL Scheme 또는 `ASWebAuthenticationSession`을 활용하면 개발 도구로서 유용한 기능 구현 가능.

---

## 1. 구현 방식 비교

| 방식 | 장점 | 단점 |
|------|------|------|
| **SFSafariViewController + URL Scheme** | Safari 쿠키 공유, 수동 제어 가능 | 직접 dismiss 처리 필요 |
| **ASWebAuthenticationSession** | 시스템 관리, 자동 콜백 처리 | iOS 12+, 쿠키 공유 제한적 |
| **SFAuthenticationSession** | iOS 11 전용 | Deprecated (iOS 12에서 대체됨) |

### 권장: ASWebAuthenticationSession

- iOS 12+ 표준
- Apple 권장 방식
- 시스템이 브라우저 세션 관리
- 콜백 URL 자동 캡처

---

## 2. URL Scheme vs Universal Links

| 항목 | Custom URL Scheme | Universal Links |
|------|-------------------|-----------------|
| **보안** | 낮음 (아무 앱이나 등록 가능) | 높음 (도메인 소유권 검증) |
| **OAuth 호환** | ✅ 잘 작동 | ❌ 리다이렉트에서 작동 안 함 |
| **설정** | Info.plist만 수정 | AASA 파일 서버 배포 필요 |
| **권장 용도** | OAuth 콜백 | 일반 딥링크 |

> **Universal Links의 한계**: 사용자 탭 인터랙션이 필요하며, 자동 리다이렉트에서는 작동하지 않음.
> OAuth 콜백에는 **Custom URL Scheme + PKCE**가 현실적인 선택.

---

## 3. 구현 코드

### 3.1 Info.plist URL Scheme 등록

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.walnut.oauth</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>walnut</string>
        </array>
    </dict>
</array>
```

### 3.2 ASWebAuthenticationSession 구현

```swift
import AuthenticationServices

class OAuthInspector: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func startOAuthFlow(url: URL, callbackScheme: String, completion: @escaping (OAuthResult) -> Void) {
        session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: callbackScheme  // "walnut" (://는 제외)
        ) { callbackURL, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let callbackURL = callbackURL else {
                completion(.failure(OAuthError.noCallback))
                return
            }

            // URL 파라미터 파싱
            let result = self.parseCallbackURL(callbackURL)
            completion(.success(result))
        }

        session?.presentationContextProvider = self
        session?.prefersEphemeralWebBrowserSession = false  // true면 쿠키 공유 안 함
        session?.start()
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            fatalError("No window found")
        }
        return window
    }

    private func parseCallbackURL(_ url: URL) -> CallbackParameters {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var params: [String: String] = [:]

        components?.queryItems?.forEach { item in
            params[item.name] = item.value
        }

        return CallbackParameters(
            url: url,
            code: params["code"],
            state: params["state"],
            error: params["error"],
            errorDescription: params["error_description"],
            idToken: params["id_token"],
            accessToken: params["access_token"],
            allParameters: params
        )
    }
}
```

### 3.3 콜백 파라미터 모델

```swift
struct CallbackParameters {
    let url: URL
    let code: String?
    let state: String?
    let error: String?
    let errorDescription: String?
    let idToken: String?
    let accessToken: String?
    let allParameters: [String: String]

    var isSuccess: Bool {
        error == nil && (code != nil || accessToken != nil || idToken != nil)
    }
}

struct OAuthResult {
    let callbackURL: URL
    let parameters: CallbackParameters
    let timestamp: Date
}
```

### 3.4 JWT 디코딩 (외부 라이브러리 없이)

```swift
struct JWTDecoder {
    struct DecodedJWT {
        let header: [String: Any]
        let payload: [String: Any]
        let signature: String

        // 자주 쓰는 클레임들
        var subject: String? { payload["sub"] as? String }
        var issuer: String? { payload["iss"] as? String }
        var audience: String? { payload["aud"] as? String }
        var expiration: Date? {
            guard let exp = payload["exp"] as? TimeInterval else { return nil }
            return Date(timeIntervalSince1970: exp)
        }
        var issuedAt: Date? {
            guard let iat = payload["iat"] as? TimeInterval else { return nil }
            return Date(timeIntervalSince1970: iat)
        }
        var email: String? { payload["email"] as? String }
        var name: String? { payload["name"] as? String }

        var isExpired: Bool {
            guard let exp = expiration else { return false }
            return exp < Date()
        }
    }

    static func decode(_ jwt: String) throws -> DecodedJWT {
        let parts = jwt.components(separatedBy: ".")
        guard parts.count == 3 else {
            throw JWTError.invalidFormat
        }

        let header = try decodeJWTPart(parts[0])
        let payload = try decodeJWTPart(parts[1])
        let signature = parts[2]

        return DecodedJWT(header: header, payload: payload, signature: signature)
    }

    private static func decodeJWTPart(_ part: String) throws -> [String: Any] {
        // Base64URL → Base64 변환
        var base64 = part
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // 패딩 추가
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw JWTError.decodingFailed
        }

        return json
    }
}

enum JWTError: Error {
    case invalidFormat
    case decodingFailed
}
```

### 3.5 SFSafariViewController 방식 (대안)

```swift
// AppDelegate 또는 SceneDelegate에서 URL 수신
func application(_ app: UIApplication,
                 open url: URL,
                 options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {

    // walnut://callback?code=abc123 형태로 들어옴
    if url.scheme == "walnut" {
        NotificationCenter.default.post(
            name: .oauthCallback,
            object: nil,
            userInfo: ["url": url]
        )
        return true
    }
    return false
}

extension Notification.Name {
    static let oauthCallback = Notification.Name("oauthCallback")
}
```

---

## 4. Walnut에서 구현 가능한 기능

### 4.1 OAuth Callback Inspector

| 기능 | 설명 |
|------|------|
| **URL 파싱** | code, state, error, token 등 파라미터 추출 |
| **JWT 디코딩** | id_token payload 파싱 (이름, 이메일, 만료시간 등) |
| **히스토리** | 이전 콜백들 저장 및 비교 |
| **복사** | 각 값 클립보드 복사 |
| **만료 체크** | 토큰 만료 여부 및 남은 시간 표시 |

### 4.2 UI 구성안

```
┌─ OAuth Inspector ─────────────────────────────────────┐
│                                                       │
│ [OAuth URL 입력]                                      │
│ ┌───────────────────────────────────────────────────┐ │
│ │ https://accounts.google.com/o/oauth2/v2/auth?...  │ │
│ └───────────────────────────────────────────────────┘ │
│                                                       │
│ Callback Scheme: [walnut    ]                        │
│                                                       │
│ [Start OAuth Flow]                                    │
│                                                       │
├───────────────────────────────────────────────────────┤
│ 📥 Callback Received                                  │
│ Time: 2024-01-15 14:32:05                            │
│                                                       │
│ ┌─ Parameters ──────────────────────────────────────┐ │
│ │ code        abc123def456...              [Copy]   │ │
│ │ state       xyz789                       [Copy]   │ │
│ │ scope       email profile openid         [Copy]   │ │
│ └───────────────────────────────────────────────────┘ │
│                                                       │
│ ┌─ ID Token (JWT) ──────────────────────────────────┐ │
│ │ iss: https://accounts.google.com                  │ │
│ │ sub: 1234567890                                   │ │
│ │ email: user@gmail.com                             │ │
│ │ name: John Doe                                    │ │
│ │ exp: 2024-01-15 15:32:05 (59분 남음)              │ │
│ │                                                   │ │
│ │ [View Full Payload]  [Copy JWT]                   │ │
│ └───────────────────────────────────────────────────┘ │
│                                                       │
│ ┌─ History ─────────────────────────────────────────┐ │
│ │ • 14:32:05 - Google OAuth ✅                      │ │
│ │ • 14:28:12 - Kakao OAuth ✅                       │ │
│ │ • 14:25:00 - GitHub OAuth ❌ (access_denied)      │ │
│ └───────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────┘
```

### 4.3 프리셋 제공

```swift
enum OAuthPreset: CaseIterable {
    case google
    case kakao
    case naver
    case apple
    case github
    case custom

    var authURL: String {
        switch self {
        case .google: return "https://accounts.google.com/o/oauth2/v2/auth"
        case .kakao: return "https://kauth.kakao.com/oauth/authorize"
        case .naver: return "https://nid.naver.com/oauth2.0/authorize"
        case .apple: return "https://appleid.apple.com/auth/authorize"
        case .github: return "https://github.com/login/oauth/authorize"
        case .custom: return ""
        }
    }

    var requiredParams: [String] {
        switch self {
        case .google: return ["client_id", "redirect_uri", "response_type", "scope"]
        case .kakao: return ["client_id", "redirect_uri", "response_type"]
        // ...
        }
    }
}
```

---

## 5. 제한사항 및 주의점

### 5.1 ASWebAuthenticationSession 제한

- **iOS 12+ 필요** (Walnut은 iOS 18.4+ 타겟이며 iOS 26 SDK 호환)
- **prefersEphemeralWebBrowserSession = true** 설정 시 Safari 쿠키 공유 안 됨
- 사용자에게 "앱이 로그인하려 합니다" 시스템 다이얼로그 표시됨

### 5.2 보안 고려사항

- **PKCE 권장**: code_challenge, code_verifier 사용
- **state 파라미터**: CSRF 방지용 랜덤 값 생성 및 검증
- **토큰 저장 금지**: 개발 도구이므로 세션 내에서만 표시, 영구 저장 X

### 5.3 URL Scheme 충돌

- `walnut://` 스킴을 다른 앱이 등록할 수 있음
- 앱 고유 식별자 포함 권장: `com.walnut.oauth://`

---

## 6. 구현 우선순위

| 우선순위 | 기능 | 난이도 |
|----------|------|--------|
| 1 | ASWebAuthenticationSession 기본 플로우 | 쉬움 |
| 2 | 콜백 URL 파라미터 파싱 및 표시 | 쉬움 |
| 3 | JWT 디코딩 (외부 라이브러리 없이) | 보통 |
| 4 | OAuth 프리셋 (Google, Kakao 등) | 보통 |
| 5 | 콜백 히스토리 저장 | 쉬움 |
| 6 | PKCE 자동 생성 | 보통 |

---

## 7. 참고 자료

- [ASWebAuthenticationSession - Apple Developer](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession)
- [OAuth 2.0 for Mobile Apps](https://www.oauth.com/oauth2-servers/mobile-and-native-apps/authorization/)
- [JWTDecode.swift - Auth0](https://github.com/auth0/JWTDecode.swift)
- [SFSafariViewController OAuth Example](https://github.com/strawberrycode/SafariOauthLogin)
- [iOS Deep Linking: URL Schemes vs Universal Links](https://byby.dev/ios-deep-linking)
- [Debugging ASWebAuthenticationSession](https://blog.eidinger.info/debugging-aswebauthenticationsession)
