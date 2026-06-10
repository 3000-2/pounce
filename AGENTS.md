# Pounce Agent Guide

키보드로 화면 요소를 클릭/스크롤하는 macOS 도구. Swift/SPM, macOS 14+, 외부 의존성 없음. 사용자 관점 동작·사용법은 `README.md`, 설계 근거는 코드 주석과 커밋 메시지.

## Commands

```sh
make test      # 유닛 테스트
make bundle    # .app 생성 + 서명
```

변경 후 검증: `make test` → `make bundle` → `pkill -x Pounce; open Pounce.app` → 핫키로 수동 확인. 런타임 로그: `log show --predicate 'process == "Pounce"' --last 5m`.

## Rules

- `Sources/PounceCore/`에는 AppKit import 금지. 신규 로직은 가능한 한 여기에 순수 함수로 두고 테스트를 붙인다.
- 좌표 변환(AX top-left ↔ AppKit bottom-left ↔ Vision normalized)은 전부 `CoordinateConversion` 경유.
- 아래는 측정으로 확정된 설계다. 근거는 해당 코드의 주석과 커밋 메시지에 있다 — 임의로 되돌리지 말 것:
  - AX 순회의 visited-set, 배칭(`axScanSnapshot`), AXWebArea 검색 술어 fast path는 유지한다. 트리 순회를 병렬화하지 않는다.
  - Chromium wake 속성은 `ManualAccessibility.setIfNeeded` 경유로만 쓴다 (직접 `AXUIElementSetAttributeValue` 금지).
  - `BadgeLayout` 계약: 활성화당 1회 레이아웃, 타이핑은 필터만 — 생존 배지를 움직이는 변경 금지.
  - `GlobalHotkey`는 고유 `id` + 미스매치 시 `eventNotHandledErr` 반환.
- OCR/비전 폴백은 기본 off (메뉴바 옵트인). 이 게이팅과 화면 기록 권한 요청 시점을 우회하는 변경 금지.
- Makefile 서명을 ad-hoc(`-`)으로 바꾸지 말 것 — 재빌드마다 손쉬운 사용 권한이 풀린다.
- 커밋은 사용자가 요청할 때만.

## Gotchas

- 권한 2종: AX 트리 = 손쉬운 사용, 픽셀 캡처 = 화면 기록. "켜져 있는데 안 먹으면" `tccutil reset Accessibility com.poc.pounce` 후 재부여.
- Chrome AX가 스턱되면(윈도우 조회가 전부 메뉴 트리로 풀림) 외부 복구 불가 — Chrome 재시작.
- Mac App Store 배포 불가 (샌드박스가 크로스앱 AX 차단). Developer ID 직배포 전제.
