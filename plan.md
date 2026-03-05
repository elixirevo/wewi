# macOS WebView Widget App 기획서

> 작성일: 2026-03-04  
> 작성자: elixirevo

---

## 1. 프로젝트 개요

### 1.1 프로젝트명

**wewi** *(확정)*

### 1.2 한 줄 소개

macOS 바탕화면에 웹페이지를 위젯으로 고정할 수 있는 네이티브 앱

### 1.3 핵심 개념

- 사용자가 원하는 URL을 입력하면 해당 웹페이지가 바탕화면 위젯으로 고정됨
- 위젯은 항상 바탕화면 레이어에 위치하며, 일반 앱 창보다 아래에 표시
- 스페이스(가상 데스크탑) 전환에도 위젯이 유지됨
- 다수의 위젯을 동시에 운용 가능

---

## 2. 문제 정의

### 2.1 기존 문제

| 앱 | 문제점 |
|---|---|
| Übersicht | HTML/JS 위젯 직접 작성 필요, 업데이트 중단 |
| WidgetKit | WebView 사용 불가 (Apple 정책) |
| MenubarX | 메뉴바 팝업 방식, 바탕화면 고정 불가 |

### 2.2 해결하려는 것

- URL만 입력하면 누구나 웹페이지를 바탕화면 위젯으로 설치 가능
- 개발 지식 없이도 사용 가능한 GUI 제공
- 가볍고 안정적인 네이티브 성능

---

## 3. 목표 사용자 (Target Users)

| 유형 | 사용 예시 |
|---|---|
| 개발자 | CI/CD 대시보드, Grafana, GitHub 위젯 |
| 트레이더 | 코인/주식 차트 실시간 표시 |
| 일반 사용자 | 날씨, 캘린더, 메모 웹앱 고정 |
| 크리에이터 | YouTube 실시간 구독자 통계 등 |

---

## 4. 핵심 기능 (MVP)

### 4.1 위젯 생성

- URL 입력으로 위젯 추가
- 위젯 크기 조절 (가로/세로 자유 조절)
- 위젯 위치 저장 (앱 재시작 후에도 유지)
- 투명도 조절

### 4.2 위젯 관리

- 다중 위젯 동시 운용
- 위젯 on/off 토글
- 위젯 이름 지정
- 위젯 목록 UI (메뉴바에서 접근)

### 4.3 동작 설정

- 인터랙션 모드: 클릭/스크롤 가능 여부 선택
- 항상 바탕화면 레이어 고정
- 모든 스페이스(가상 데스크탑)에서 표시
- 로그인 시 자동 시작

### 4.4 메뉴바 앱

- 상단 메뉴바 아이콘으로 접근
- 위젯 목록 및 빠른 on/off
- 환경설정 창 열기

---

## 5. 기술 스택

### 5.1 핵심 기술

| 레이어 | 기술 | 이유 |
|---|---|---|
| 위젯 창 관리 | AppKit (`NSPanel`) | Window Level 세밀한 제어 필수 |
| 웹 렌더링 | `WKWebView` | 네이티브 WebKit, 경량 |
| 설정 UI | SwiftUI | 빠른 UI 개발, AppKit 브릿지 가능 |
| 메뉴바 | `NSStatusItem` | 네이티브 메뉴바 아이콘 |
| 데이터 저장 | UserDefaults / JSON | 위젯 설정 영속화 |
| 언어 | Swift 5.9+ | 네이티브 macOS 전용 |

### 5.2 NSPanel 핵심 설정

```swift
panel.level = .init(rawValue: Int(CGWindowLevelKey.desktopWindowLevelKey.rawValue) + 1)
panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
panel.styleMask = [.borderless, .nonactivatingPanel]
panel.isOpaque = false
panel.backgroundColor = .clear
```

---

## 6. 시스템 아키텍처

```
┌─────────────────────────────────┐
│         MenuBar App             │  ← NSStatusItem
│  (위젯 목록 / 환경설정 진입점)      │
└────────────┬────────────────────┘
             │
┌────────────▼────────────────────┐
│       WidgetManager             │  ← 위젯 생성/삭제/저장 관리
│  (위젯 목록 상태 관리)             │
└────────────┬────────────────────┘
             │ (1:N)
┌────────────▼────────────────────┐
│       WidgetWindow              │  ← NSPanel + WKWebView
│  (각 위젯 인스턴스)               │
└─────────────────────────────────┘
```

---

## 7. 개발 로드맵

### Phase 1 — MVP (4주)

- [ ] NSPanel + WKWebView 기본 구현
- [ ] URL 입력 → 위젯 생성
- [ ] 위젯 위치/크기 저장
- [ ] 메뉴바 아이콘 및 위젯 목록

### Phase 2 — 완성도 (3주)

- [ ] 투명도 / 인터랙션 모드 설정
- [ ] 위젯 테두리 / 라운딩 커스터마이징
- [ ] 로그인 시 자동 시작
- [ ] 위젯 import/export (JSON)

### Phase 3 — 확장 (추후)

- [ ] 위젯 프리셋 마켓플레이스
- [ ] JavaScript Bridge (위젯 ↔ macOS 시스템 정보 연동)
- [ ] 위젯 갱신 주기 설정 (자동 새로고침)
- [ ] Homebrew Cask 배포

---

## 8. 배포 전략

- **직접 배포 (Direct Distribution)** — GitHub Releases + DMG
- App Store 미등록 (WebView 정책 우회, 자유로운 권한 사용)
- 오픈소스 공개 검토 (MIT License)
- 추후 Homebrew Cask 등록

---

## 9. 리스크 및 대응

| 리스크 | 대응 방안 |
|---|---|
| macOS 보안 정책 강화 (Gatekeeper) | 개발자 서명(Apple Developer ID) 적용 |
| WKWebView 도메인 제한 | `limitsNavigationsToAppBoundDomains = false` 설정 |
| 특정 사이트 WebView 차단 | User-Agent 커스터마이징 |
| 높은 CPU/메모리 사용 | 백그라운드 위젯 렌더링 스로틀링 적용 |

---

## 10. 성공 지표 (KPI)

- GitHub Stars 500+ (3개월 내)
- 월간 활성 사용자 1,000+
- 주요 커뮤니티 (Reddit r/macapps, 클리앙) 자연 확산
