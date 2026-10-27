# Dozy — AI 일정 관리 앱

> 하루를 기록하고, 패턴을 발견하고, 더 나은 내일을 설계하는 iOS · macOS 생산성 앱

[![iOS](https://img.shields.io/badge/iOS-17.6+-black?style=flat&logo=apple)](https://developer.apple.com/ios/)
[![macOS](https://img.shields.io/badge/macOS-15.0+-black?style=flat&logo=apple)](https://developer.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.0-orange?style=flat&logo=swift)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-✓-blue?style=flat)](https://developer.apple.com/xcode/swiftui/)
[![Supabase](https://img.shields.io/badge/Supabase-✓-3FCF8E?style=flat&logo=supabase)](https://supabase.com)

---

## 소개

Dozy는 Apple Calendar, Google Calendar 등 기존 캘린더와 연동해 하루 일정을 한눈에 파악하고, AI 기반 일일 요약과 생산성 인사이트를 제공하는 iOS · macOS 앱입니다.

- 여러 캘린더 소스를 하나의 뷰에서 통합 관리
- 완료한 일정과 할 일을 기록하고 생산성 점수로 확인
- AI가 오늘 하루를 요약하고 다음 액션을 추천
- 주간/월간/분기별 패턴 분석으로 업무 흐름 파악
- 파트너와 공유 캘린더 + 메모 + 실시간 알림 카드
- macOS 메뉴바 팝오버 + 캘린더 단독 창 + 키보드 단축키

---

## 주요 기능

### 공통 (iOS · macOS)

| 기능 | 설명 |
|------|------|
| 홈 / 오늘 대시보드 | 오늘 일정, AI 요약, 빠른 메모, 생산성 통계, 날씨 카드 |
| 캘린더 | Apple·Google·Dozy 자체 캘린더 통합, 일정 생성·수정·삭제·반복 |
| 공유 캘린더 | 초대 코드로 두 사람 공유, 파트너와 일정·메모 실시간 동기화 |
| 외부 일정 공유 | Apple·Google 일정을 공유 캘린더로 미러링, 원본 변경 자동 반영 |
| 일정 완료 체크 | 완료 여부 기록, EventCompletion 기반 날짜별 상태 관리 |
| AI 일일 요약 | iOS 26+ Foundation Models / NaturalLanguage 로컬 폴백 |
| 인사이트 | 카테고리별 활동 분석, 완료율, 패턴 기반 추천 |
| 카테고리 관리 | 사용자 정의 카테고리 — 24색 프리셋 + 시스템 이모지 패널 |
| 알림 카드 | 파트너가 공유 일정을 등록하면 내 알림 화면에 카드 노출 |
| Lottie 애니메이션 | 일정 저장 / 로그인 성공 시 Success / Congratulation 모션 |
| 클라우드 동기화 | Supabase 기반 멀티 디바이스 데이터 동기화 |
| 다중 로그인 | Apple · Google · Email (iOS 는 Naver 추가) |

### macOS 전용

| 기능 | 설명 |
|------|------|
| 메뉴바 팝오버 | 메뉴바 아이콘에서 오늘 일정 + 빠른 추가 + 남은 일정 배지 |
| 캘린더 단독 창 | ⌘⇧C 로 사이드바 없는 풀 캘린더 윈도우 |
| 키보드 단축키 | ⌘1~4 탭 전환, ⌘N 새 일정, ⌘T 오늘로 이동, ⌘[/⌘] 기간 이동 등 |
| NavigationSplitView | 사이드바 + 디테일 2단 레이아웃 + Today / 캘린더 / 인사이트 / 설정 |

---

## 기술 스택

### Frontend
- **SwiftUI** — iOS · macOS 공통 선언형 UI
- **AppKit (NSViewRepresentable)** — macOS 전용 Lottie / 시스템 이모지 패널 wrapper
- **SwiftData** — 로컬 데이터 영속성 (`@ModelActor` 백그라운드 컨텍스트 활용)
- **Combine** — 비동기 이벤트 스트림
- **EventKit** — 시스템 캘린더·리마인더 연동
- **CoreLocation + Open-Meteo** — 위치 기반 날씨 카드
- **Lottie** — Success / Loading / Congratulation 애니메이션
- **NaturalLanguage** — 온디바이스 NLP 키워드 추출

### Backend
- **Supabase** — Auth, PostgreSQL, Realtime (공유 캘린더 INSERT/UPDATE 구독)
- **Google Sign-In SDK**
- **Naver Login SDK** (iOS only)

### 인프라 / 개발 도구
- **Fastlane** — iOS · macOS TestFlight·App Store 자동 배포
- **Swift Package Manager** — 의존성 관리
- **App Store Connect API** — 빌드 번호 자동 관리

---

## 아키텍처

Clean Architecture + MVVM 패턴을 적용했습니다. iOS·macOS가 Domain·Data 레이어를 **공유**하고 Presentation 만 플랫폼별로 분기합니다.

```
Presentation  ──▶  Domain  ──▶  Data
(View / ViewModel)  (UseCase / Model / Protocol)  (Service / Repository / SwiftData)
```

```
Dozy AI/                      iOS 타겟 + 공통 Domain·Data 레이어
├── App/                       앱 진입점
├── Presentation/              iOS UI (View + ViewModel)
│   ├── Home/
│   ├── Calendar/
│   ├── Insights/
│   ├── Settings/
│   ├── Notifications/
│   ├── SharedCalendar/
│   └── Components/            재사용 컴포넌트 (Lottie / Weather 등)
├── Domain/                    비즈니스 로직 (양 타겟 공유)
│   ├── UseCases/              (20+ UseCase)
│   ├── Models/                도메인 엔티티
│   └── Protocols/             서비스 추상화
├── Data/                      데이터 접근 (양 타겟 공유)
│   ├── Services/              Calendar, AI, Auth, Realtime 등
│   ├── Repositories/          SwiftData CRUD + Supabase 동기화
│   └── DTO/                   Supabase 매핑
└── Core/
    ├── DI/                    DependencyContainer
    ├── Extensions/
    └── Utilities/             Logger, Keychain 등

Dozy AI (macOS)/              macOS 타겟 — 자체 ViewModel·View 만 별도
├── App/                       MacAppRootView (signedOut/signedIn 분기)
├── ViewModels/                MacHome / MacCalendar / MacAuth / MacInsight 등
└── Views/
    ├── Shell/                 NavigationSplitView 메인 셸
    ├── Today/                 + WeatherCard
    ├── Calendar/              + Week/Day 뷰
    ├── EventEdit/             생성·상세
    ├── Settings/              + Category 관리·24색 프리셋
    ├── SharedCalendar/        목록·생성·참여·상세
    ├── Notifications/         알림 카드 리스트
    ├── DailySummary/          AI 요약
    ├── Insights/              인사이트 대시보드
    ├── MenuBar/               메뉴바 팝오버 + 빠른 추가
    ├── Login/
    └── Components/            MacLottieView (NSViewRepresentable)
```

**DependencyContainer**가 양 타겟의 모든 의존성을 조립하며, ViewModel은 UseCase만 주입받습니다.

---

## 시작하기

### 요구사항

- Xcode 16+
- iOS 17.6+ / macOS 15.0+
- [Supabase](https://supabase.com) 프로젝트 (Auth + DB 설정)
- Google OAuth 클라이언트 ID ([Google Cloud Console](https://console.cloud.google.com))

### 설치

```bash
git clone https://github.com/your-username/Dozy-AI.git
cd Dozy-AI
```

Xcode에서 `Dozy AI.xcodeproj`를 열면 Swift Package Manager가 의존성을 자동으로 설치합니다. 스킴은 두 개 — `Dozy AI` (iOS) / `Dozy AI (macOS)`.

### 환경 설정

`Dozy AI/Config/Secrets.xcconfig` 파일을 생성하고 아래 값을 채웁니다.

```
// Secrets.xcconfig — 버전 관리에서 제외됨 (.gitignore 적용)

SUPABASE_HOST = your-project.supabase.co
SUPABASE_ANON_KEY = your-anon-key

GOOGLE_CLIENT_ID = your-google-client-id.apps.googleusercontent.com
GOOGLE_REVERSED_CLIENT_ID = com.googleusercontent.apps.your-google-client-id

NAVER_CLIENT_ID = your-naver-client-id
NAVER_CLIENT_SECRET = your-naver-client-secret
```

> 프로덕션 환경은 `Dozy AI/Config/Production.xcconfig`에 별도로 관리합니다.

> macOS 타겟의 위치 권한·샌드박스 위치 entitlement 는 이미 프로젝트에 포함되어 있어 별도 설정 불필요.

### Supabase 스키마

`supabase/migrations/` 아래의 `.sql` 파일을 시간순으로 Supabase SQL Editor에서 실행하거나, Supabase CLI로 push하여 테이블·RLS 정책·Realtime publication을 적용합니다.

```bash
supabase db push
```

---

## 배포

[Fastlane](https://fastlane.tools)으로 iOS · macOS 빌드 및 배포를 자동화합니다.

```bash
# iOS TestFlight 베타 (빌드 번호 자동 증가)
fastlane ios beta

# iOS App Store 제출
fastlane ios release

# macOS TestFlight 베타
fastlane mac beta

# macOS 로컬 컴파일 검증 (서명·archive 없이 build 만)
fastlane mac build
```

`fastlane/api_key.p8` 파일은 App Store Connect API Key로, `.gitignore`에 포함되어 있습니다. iOS / macOS 둘 다 동일 키 + 팀으로 사용.

---

## 라이선스

이 프로젝트는 비공개 소프트웨어입니다. 무단 복제 및 배포를 금합니다.

© 2026 Dozy. All rights reserved.
