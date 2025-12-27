# Wallnut App Store Screenshots

App Store 스크린샷 템플릿 및 에셋

## 📐 규격 (2024 기준)

| Device | Size | Template |
|--------|------|----------|
| iPhone 6.9" | 1260 × 2736 px | `screenshot-template-iphone.svg` |
| iPhone 6.9" (Minimal) | 1260 × 2736 px | `screenshot-template-minimal.svg` |
| iPhone 6.9" (Feature) | 1260 × 2736 px | `screenshot-template-feature.svg` |
| iPad 13" | 2048 × 2732 px | `screenshot-template-ipad.svg` |

> Apple은 2024년 9월부터 하나의 iPhone/iPad 크기만 업로드하면 자동 스케일링 지원

## 🎨 디자인 시스템

### 색상 팔레트

| Name | Hex | Usage |
|------|-----|-------|
| Background Dark | `#0D1117` | 기본 배경 |
| Background Mid | `#1A1D23` | 카드, 프레임 |
| Surface | `#21262D` | 컴포넌트 배경 |
| Primary (Cyan) | `#00BCD4` | 액센트, 강조 |
| Primary Light | `#4DD0E1` | 그라데이션 끝 |
| Text Primary | `#FFFFFF` | 헤드라인 |
| Text Secondary | `#8B949E` | 서브텍스트 |

### 폰트

- **Headline**: SF Pro Display Bold, -1px letter-spacing
- **Body**: SF Pro Text Regular
- **Badge**: SF Pro Text Semibold

## 📁 템플릿 설명

### `screenshot-template-iphone.svg`
- 디바이스 프레임 + Dynamic Island 포함
- 상단 헤드라인/서브헤드라인
- 하단 기능 배지 및 태그라인
- **Screenshot 영역**: 768 × 1618 px

### `screenshot-template-minimal.svg`
- 프레임 없는 풀블리드 스타일
- 좌측 정렬 타이틀
- 미니멀한 디자인
- **Screenshot 영역**: 1100 × 2200 px

### `screenshot-template-feature.svg`
- 단일 기능 강조용
- 큰 아이콘 + 기능명
- 기능 불릿 포인트
- **Screenshot 영역**: 1068 × 1668 px

### `screenshot-template-ipad.svg`
- iPad Pro 프레임
- 넓은 기능 필 레이아웃
- **Screenshot 영역**: 1460 × 1960 px

## 🛠 사용법

### Figma에서 사용
1. SVG 파일 Import
2. 플레이스홀더 영역에 스크린샷 배치
3. 텍스트 수정
4. PNG로 Export (1x)

### 코드로 PNG 변환

```bash
# ImageMagick 사용
magick screenshot-template-iphone.svg -density 72 screenshot-1.png

# Inkscape 사용
inkscape screenshot-template-iphone.svg --export-filename=screenshot-1.png
```

### 권장 스크린샷 세트

1. **Hero Shot**: 앱 전체 모습 + 핵심 가치
2. **Console**: JavaScript 콘솔 기능
3. **Network**: 네트워크 모니터링
4. **Storage**: 스토리지 인스펙터
5. **Settings**: 커스터마이징 옵션

## 📖 참고 자료

- [Apple Screenshot Specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [SplitMetrics ASO Guide](https://splitmetrics.com/blog/app-store-screenshots-aso-guide/)
- [AppShot Gallery](https://www.appshot.gallery/) - 디자인 영감

## ✅ 체크리스트

- [ ] 첫 3개 스크린샷에 핵심 기능 집중
- [ ] 텍스트는 썸네일 크기에서도 가독성 확보
- [ ] 한국어 로컬라이제이션 적용
- [ ] 실제 앱 스크린샷으로 플레이스홀더 교체
