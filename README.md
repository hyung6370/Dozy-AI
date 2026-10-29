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
- 온디바이스 AI가 오늘 하루를 요약하고 다음 액션을 추천, 저녁에 요약 알림
- 잠금화면 · 다이나믹 아일랜드 Live Activity 와 홈 · 잠금화면 위젯으로 진행 중 일정 확인
- 한 줄 문장이나 음성으로 일정 입력, Siri 단축어
- "지난주 회의 몇 시간 했지?"처럼 물으면 횟수 · 총 시간 · 완료율을 계산해 주는 검색
- 7일 · 30일 · 90일 패턴 분석과 카테고리별 시간 분배
- 파트너와 공유 캘린더(최대 4명) + 메모 + 실시간 알림 카드 + 앱이 꺼져 있어도 오는 푸시 알림(iOS)
- macOS 메뉴바 팝오버 + 캘린더 단독 창 + 키보드 단축키

---

## 주요 기능

### 공통 (iOS · macOS)

| 기능 | 설명 |
|------|------|
| 홈 / 오늘 대시보드 | 오늘 일정, AI 요약, 빠른 메모, 생산성 통계, 날씨 카드 |
| 캘린더 | Apple·Google·Dozy 자체 캘린더 통합, 월·주·일 보기, 일정 생성·수정·삭제·반복·상단 고정, 캘린더 스크린샷 |
| 자연어 · 음성 일정 입력 | "내일 오후 3시 치과 30분" 한 줄 또는 마이크로 제목·날짜·시간 자동 채움 (`NaturalLanguageEventParser`) |
| 공유 캘린더 | 초대 코드로 최대 4명 공유, 파트너와 일정·메모 실시간 동기화, 캘린더 필터. iOS 는 히어로 카드형 상세 · 멤버 아바타 · 초대 코드 카드 |
| 물어보는 검색 | "지난주 회의 몇 시간", "이번 달 운동 몇 번", "이번 주 완료율" → 기간 · 키워드 · 집계 해석(`QueryRuleParser`, iOS 26 은 Foundation Models 해석 후 규칙으로 검증) + 수치는 `SearchAggregator` 가 계산. 해석 칩으로 조건 해제, 한 단어 검색은 기존 키워드 검색 |
| 외부 일정 공유 | Apple·Google 일정을 공유 캘린더로 미러링, 원본 변경 자동 반영 |
| 일정 완료 체크 | 완료 여부 기록, EventCompletion 기반 날짜별 상태 관리 |
| AI 일일 요약 | iOS 26+ Foundation Models(온디바이스) / NaturalLanguage 로컬 폴백. 외부 LLM 호출 없음 |
| 저녁 요약 알림 · 일정 체크 | 정한 시각에 요약 알림(탭하면 요약 화면), BGAppRefreshTask 로 백그라운드 미리 생성, 저녁 미완료 일정 체크 |
| 인사이트 | 7 · 30 · 90일 완료율 · 연속 달성 · 생산성 추이, 카테고리별 시간 분배 · 완료율 · 요일 패턴 · 집중 시간대 |
| 카테고리 관리 | 사용자 정의 카테고리 — 24색 프리셋 + 시스템 이모지 패널 |
| 알림 카드 | 파트너가 공유 일정을 등록하면 내 알림 화면에 카드 노출 (Realtime · 푸시 · 앱 활성화 경로에서 중복 없이 하나) |
| Lottie 애니메이션 | 일정 저장 / 로그인 성공 시 Success / Congratulation 모션 |
| 클라우드 동기화 | Supabase 기반 멀티 디바이스 데이터 동기화 |
| 다중 로그인 | Apple · Google · Email |
| 이용 통계 · 진단 | Firebase Analytics(기능 사용 이벤트, IDFA 없음) · Crashlytics(크래시 · 비치명 오류 분류만). 설정 "사용 통계 전송"으로 끔 |
| 아이콘 | Iconsax 커스텀 SF 심볼셋(`DozyIcons.xcassets`) — `Image(symbol:)` 로 SF Symbol 과 같은 크기 규칙 |

### iOS 전용

| 기능 | 설명 |
|------|------|
| Live Activity | 오늘 시간제 일정이 있으면 잠금화면 · 다이나믹 아일랜드에 진행 중 일정의 남은 시간 + 다음 일정, 잠금화면에서 완료 체크 (`TodayAgendaPlanner` → `TodayAgendaActivityService`) |
| 홈 · 잠금화면 위젯 | Small / Medium / Large(월 달력 포함) + accessory 위젯. 체크박스로 완료 토글, `+` 로 일정 추가 딥링크 (`DozyWidgetsExtension`) |
| Siri 단축어 | 음성 메모 · 하루 요약 · 음성 일정 입력 (`DozyAppIntents`) |
| 공유 캘린더 푸시 | 파트너가 공유 캘린더에 일정을 추가하면 앱이 꺼져 있어도 APNs 푸시, 탭하면 알림 목록. 설정 "공유 캘린더 알림" 토글 (`PushRegistrationUseCase` · `SharedPushHandler` · Edge Function `send-push`) |

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
- **ActivityKit · WidgetKit · App Intents** — Live Activity, 홈·잠금화면 위젯, 위젯 인터랙션, Siri 단축어
- **Speech · AVFoundation** — 음성 일정·메모 입력
- **FoundationModels (iOS 26+)** — 온디바이스 일일 요약, 실패 시 **NaturalLanguage** 로컬 폴백
- **UserNotifications · BackgroundTasks** — 저녁 요약 알림, 공유 캘린더 원격 알림(APNs), BGAppRefreshTask 백그라운드 갱신
- **CoreLocation + Open-Meteo** — 위치 기반 날씨 카드
- **Lottie** — Success / Loading / Congratulation 애니메이션

### Backend
- **Supabase** — Auth, PostgreSQL, Realtime (공유 캘린더 INSERT/UPDATE 구독), Edge Functions(`send-push` — APNs HTTP/2), `pg_net` 트리거, Vault
- **Firebase** — Analytics(`FirebaseAnalyticsCore`, IDFA 없음) · Crashlytics
- **Google Sign-In SDK**
- **Naver Login SDK** (iOS, 캘린더 연동은 현재 비활성)

### 인프라 / 개발 도구
- **Fastlane** — iOS · macOS TestFlight·App Store 자동 배포
- **Swift Package Manager** — 의존성 관리
- **App Store Connect API** — 빌드 번호 자동 관리
- **Claude Code** — `CLAUDE.md` 작업 규칙 + `.claude/skills/` 슬래시 명령(`/issue-new`, `/issue-start`, `/verify`, `/pr`)

---

## 아키텍처

Clean Architecture + MVVM 패턴을 적용했습니다. iOS·macOS가 Domain·Data 레이어를 **공유**하고 Presentation 만 플랫폼별로 분기합니다. 위젯 extension 은 Domain 의 순수 계산(`TodayAgendaPlanner` 등)과 캐시 모델만 공유합니다. 앱이 떠 있지 않을 때 도는 코드(인텐트 · BGTask · 위젯)는 App Group store 를 직접 열거나 static 훅을 써서 `DependencyContainer` 없이 동작합니다.

```
Presentation  ──▶  Domain  ──▶  Data
(View / ViewModel)  (UseCase / Model / Protocol)  (Service / Repository / SwiftData)
```

```
Dozy AI/                      iOS 타겟 + 공통 Domain·Data 레이어
├── App/                       앱 진입점, AppDelegate (BGTask · Live Activity 독립 실행 훅)
├── Intents/                   Siri 단축어 (음성 메모 · 하루 요약 · 음성 일정)
├── Presentation/              iOS UI (View + ViewModel)
│   ├── Home/
│   ├── Calendar/
│   ├── DailySummary/
│   ├── Insights/
│   ├── Search/
│   ├── Settings/
│   ├── Notifications/
│   ├── SharedCalendar/
│   ├── VoiceInput/
│   └── Components/            재사용 컴포넌트 (Lottie / Weather / 탭바 등)
├── Domain/                    비즈니스 로직 (양 타겟 공유)
│   ├── UseCases/              (32 UseCase)
│   ├── Models/                도메인 엔티티 + 순수 계산 (TodayAgendaPlanner, SummaryReminderSchedule, QueryRuleParser, SearchAggregator 등)
│   └── Protocols/             서비스 추상화
├── Data/                      데이터 접근 (양 타겟 공유)
│   ├── Services/              Calendar, AI(FoundationModels), Auth, Realtime, Reminder, Live Activity, Push, Firebase 등
│   ├── Repositories/          SwiftData CRUD + Supabase 동기화
│   └── DTO/                   Supabase 매핑
├── Resources/                 Assets, DozyIcons.xcassets(Iconsax 심볼셋), Localizable.xcstrings(ko/en), Lottie
└── Core/
    ├── DI/                    DependencyContainer
    ├── Extensions/
    └── Utilities/             Logger, Keychain, DozyIcon, DemoDataSeeder(DEBUG) 등

DozyWidgets/                  위젯 extension (iOS 17.6+)
├── TodayEvents/               홈 · 잠금화면 위젯 (Small / Medium / Large / accessory)
├── TodayAgenda/               Live Activity (잠금화면 · 다이나믹 아일랜드)
├── ToggleEventCompletionIntent.swift   위젯 · Live Activity 완료 토글 (LiveActivityIntent)
└── CreateQuickEventIntent.swift        위젯 + 버튼 → 일정 추가 딥링크

scripts/iconsax/              Iconsax SVG → SF Symbols 템플릿 심볼셋 생성 (mapping.py + build_icons.py)

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

**DependencyContainer**가 양 타겟의 모든 의존성을 조립하며, ViewModel은 UseCase만 주입받습니다. 프로젝트는 synchronized group 을 쓰지 않으므로 새 파일은 `project.pbxproj` 에 직접 등록합니다 (`CLAUDE.md` 참고).

---

## 시작하기

### 요구사항

- Xcode 16+
- iOS 17.6+ / macOS 15.0+
- [Supabase](https://supabase.com) 프로젝트 (Auth + DB 설정)
- Google OAuth 클라이언트 ID ([Google Cloud Console](https://console.cloud.google.com))

### 설치

```bash
git clone https://github.com/hyung6370/Dozy-AI.git
cd Dozy-AI
```

Xcode에서 `Dozy AI.xcodeproj`를 열면 Swift Package Manager가 의존성을 자동으로 설치합니다. 스킴은 두 개 — `Dozy AI` (iOS, 위젯 extension 포함) / `Dozy AI (macOS)`. 타깃은 7개(앱 2 · 테스트 4 · `DozyWidgetsExtension`).

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

> 프로덕션 환경은 `Dozy AI/Config/Production.xcconfig`에 별도로 관리합니다. `Secrets.xcconfig` 값은 빌드 설정 → Info.plist 로만 쓰입니다 — 리소스 복사(Copy Bundle Resources)에 넣지 않습니다.

#### Firebase (선택)

Firebase 콘솔(프로젝트 `dozy-7fa39`)에서 내려받은 `GoogleService-Info.plist` 를 `Dozy AI/` · `Dozy AI (macOS)/` 에 둡니다. 공개 저장소라 `.gitignore` 되어 있고, 없으면 Firebase 만 꺼진 채로 빌드됩니다. DEBUG 빌드는 `-FIRAnalyticsDebugEnabled` 인자로 실행할 때만 수집합니다.

#### 푸시 (공유 캘린더 알림)

APNs 인증 키(.p8, Team scoped)를 Supabase Edge Function 시크릿에, Function 주소 · 호출 비밀값을 DB Vault 에 넣습니다. 비밀값은 저장소에 커밋하지 않습니다.

```bash
SECRET=$(openssl rand -hex 32)
supabase secrets set --project-ref <ref> APNS_KEY_ID=<key-id> APNS_TEAM_ID=<team-id> \
  APNS_BUNDLE_ID=com.dozy-ai.Dozy-AI PUSH_WEBHOOK_SECRET="$SECRET" \
  APNS_PRIVATE_KEY="$(cat AuthKey_<key-id>.p8)"
supabase functions deploy send-push --project-ref <ref> --no-verify-jwt
```

```sql
-- SQL Editor (PUSH_WEBHOOK_SECRET 와 같은 값)
select vault.create_secret('<SECRET>', 'push_webhook_secret');
select vault.create_secret('https://<ref>.supabase.co/functions/v1/send-push', 'push_function_url');
```

Debug 빌드는 sandbox, TestFlight · App Store 빌드는 production APNs 토큰을 등록하고 `send-push` 가 호스트를 고릅니다.

> macOS 타겟의 위치 권한·샌드박스 위치 entitlement 는 이미 프로젝트에 포함되어 있어 별도 설정 불필요.

### 빌드 · 테스트

```bash
# iOS (시뮬레이터)
xcodebuild -project "Dozy AI.xcodeproj" -scheme "Dozy AI" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO build
# macOS
xcodebuild -project "Dozy AI.xcodeproj" -scheme "Dozy AI (macOS)" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build
# 단위 테스트 (iOS 519건 · macOS XCTest 281 + Swift Testing 123건)
xcodebuild ... -scheme "Dozy AI" ... test -only-testing:'Dozy AITests'
xcodebuild ... -scheme "Dozy AI (macOS)" ... test -only-testing:'Dozy AI (macOS)Tests'
```

> 시뮬레이터에 설치해 Live Activity · 위젯 · App Group 을 확인하려면 `CODE_SIGNING_ALLOWED=NO` 없이 서명을 켜고 빌드합니다 (entitlement 가 빠지면 App Group store 를 열지 못해 실행 직후 종료됩니다).

### DEBUG 실행 인자

| 인자 | 동작 |
|------|------|
| `-uiTesting` | 환경 선택 다이얼로그와 인트로를 건너뛰고 개발 환경으로 진입 |
| `-seedDemoData` | 로컬 SwiftData 를 비우고 지난 30일 + 다음 7일치 한국어 샘플 일정 · 완료 · 작업 기록 · 카테고리를 채움 (App Store 스크린샷용) |
| `-FIRAnalyticsDebugEnabled` | DEBUG 빌드에서 Firebase 이용 통계 · Crashlytics 수집 (DebugView) |
| `-DozyCrashlyticsTestCrash` | 실행 3초 뒤 테스트 크래시 — Debug executable 해제 필수, 크래시 후 인자 없이 재실행해야 전송 |

```bash
xcrun simctl launch <UDID> com.dozy-ai.Dozy-AI -uiTesting -seedDemoData
```

### 아이콘 추가

Iconsax 아이콘은 `scripts/iconsax/mapping.py` 에 SF 이름 → Iconsax 컴포넌트 한 줄을 추가하고 스크립트를 돌린 뒤, `DozyIcon.customNames` 에 이름을 넣습니다. 호출부는 `Image(symbol:)` · `Label(_:symbol:)` 만 씁니다 — 매핑이 없으면 SF Symbol 로 폴백.

```bash
python3 -I scripts/iconsax/build_icons.py chevron.right bell.fill
```

### Supabase 스키마

`supabase/migrations/` 아래의 `.sql` 파일을 시간순으로 Supabase SQL Editor에서 실행하거나, Supabase CLI로 push하여 테이블·RLS 정책·Realtime publication·푸시 트리거를 적용합니다. Edge Function 은 `supabase/functions/` (위 "푸시" 참고).

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

# 이미 올린 빌드의 dSYM 을 Crashlytics 에 업로드 (빌드 번호 생략 시 최근 아카이브)
fastlane ios upload_dsyms build:163
```

`ios beta` · `ios release` · `mac beta` 는 빌드 직후 dSYM 을 Crashlytics 에 자동 업로드합니다(`GoogleService-Info.plist` 가 있을 때). 로그의 "Successfully uploaded dSYM files to Crashlytics" 로 확인합니다.

`fastlane/api_key.p8` 파일은 App Store Connect API Key로, `.gitignore`에 포함되어 있습니다. iOS / macOS 둘 다 동일 키 + 팀으로 사용.

---

## 라이선스

이 프로젝트는 비공개 소프트웨어입니다. 무단 복제 및 배포를 금합니다.

© 2026 Dozy. All rights reserved.
