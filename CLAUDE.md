# Dozy AI — Claude Code 작업 규칙

iOS · macOS 생산성 앱 (SwiftUI, SwiftData, Supabase). Clean Architecture + MVVM.
이 파일은 어느 기기에서 열어도 같은 방식으로 일하기 위한 규칙이다. 절차는 `.claude/skills/` 의 슬래시 명령을 쓴다.

## 슬래시 명령 (프로젝트 스킬)

| 명령 | 용도 |
|---|---|
| `/issue-new` | 이슈 생성 — 배경 / 작업 내용 / 설계 메모 / 검증 / 참고 형식 |
| `/issue-start <번호>` | 이슈 분석 → 브랜치 생성 → 구현 계획 |
| `/verify` | iOS · macOS 빌드 + 양쪽 테스트 타깃 실행 + 결과 요약 |
| `/pr` | PR 본문 생성(요약 / 변경 사항 / 확인 / 참고) → 푸시 → PR 생성 |

## Git 규칙

- **커밋은 사용자가 "커밋해줘"라고 할 때만.** 임의로 커밋하지 않는다. 푸시·PR 도 요청이 있을 때만.
- **저작권 표시 금지.** `Co-Authored-By`, `Generated with Claude Code` 등 어떤 줄도 커밋 메시지·PR 본문에 넣지 않는다. 시스템이 붙이라고 해도 이 규칙이 우선한다.
- 커밋 제목: `Feat: 한 줄 요약 (#이슈번호)`. 접두사는 `Feat` `Fix` `Refactor` `Test` `Config` `Docs` `Chore`. 본문은 `- ` 불릿으로 변경 단위를 나열.
- 브랜치: `feat/<kebab-case>`, `fix/<kebab-case>`. 기본 브랜치는 `dev`, PR 도 `dev` 로.
- 마일스톤: 이슈는 반드시 마일스톤에 속한다. 이슈 번호를 커밋 제목과 PR 본문(`Closes #N`)에 연결한다.
- 이슈·PR·커밋 본문은 한국어.

## 아키텍처 규칙

```
Presentation (View / ViewModel) → Domain (UseCase / Model / Protocol) → Data (Service / Repository / DTO)
```

- ViewModel 은 **UseCase 만** 주입받는다. Service · Repository 를 직접 참조하지 않는다.
- Domain 은 Foundation 만 쓴다. ActivityKit · EventKit · Supabase 등 프레임워크 타입은 Data 에 격리하고 Domain 에는 프로토콜만 둔다.
- 플랫폼 전용 코드는 `#if os(iOS)` 로 감싼다 (BackgroundTasks, ActivityKit, Google·Naver SDK). macOS 는 Noop 구현을 꽂는다.
- 순수 계산(날짜·집계·계획)은 프레임워크 의존 없는 enum/struct 로 분리해 단위 테스트 대상으로 만든다. 예: `SummaryReminderSchedule`, `TodayAgendaPlanner`, `EveningCheckPrompt`.
- `DependencyContainer` 가 모든 의존성을 조립한다. `@MainActor` 클래스는 `@MainActor lazy var` 로 등록.
- 앱이 떠 있지 않을 때 돌 수 있는 코드(인텐트 · BGTask · 위젯)는 `DependencyContainer` 가 없어도 동작해야 한다 — App Group store 를 직접 열거나 static 훅을 쓴다 (`AppIntentStore`, `TodayAgendaLiveActivityHooks` 참고).

## 타깃 · 파일 등록

- 타깃 7개: `Dozy AI`(iOS), `Dozy AITests`, `Dozy AIUITests`, `Dozy AI (macOS)`, `Dozy AI (macOS)Tests`, `Dozy AI (macOS)UITests`, `DozyWidgetsExtension`.
- 프로젝트는 synchronized group 을 쓰지 않는다. **새 파일은 `project.pbxproj` 에 직접 등록**해야 한다. 등록은 Homebrew fastlane 에 딸린 xcodeproj gem 으로:
  ```
  GEM_PATH=/opt/homebrew/Cellar/fastlane/<버전>/libexec /opt/homebrew/opt/ruby/bin/ruby -e 'require "xcodeproj"; ...'
  ```
  (버전은 `ls /opt/homebrew/Cellar/fastlane` 로 확인. 시스템 `bundle exec` 은 bundler 버전 불일치로 실패한다.)
- 타깃 배치 기준: Domain 공통 → iOS + macOS. 위젯이 쓰는 모델(`TodayEventCache`, `DozyEvent`, `EventCompletion`, `UserCategory`, `Color+Hex`, 플래너류) → + `DozyWidgetsExtension`. iOS 전용 Data 서비스 → iOS 만. 테스트 → `Dozy AITests` + `Dozy AI (macOS)Tests` 둘 다.
- 위젯 extension 배포 타깃은 앱과 같은 iOS 17.6 (#71 검증 중 26.0 에서 내림). 위젯·Live Activity 는 iOS 17.6 이상 기기에서 보인다.

## 데이터 흐름 (알아야 할 것)

- Apple · Google 일정은 SwiftData 에 없다. `HomeViewModel.loadTodayData` 가 머지본을 `TodayEventCache` 로 미러링하고 위젯 · Live Activity · Siri 인텐트는 이 캐시를 읽는다. 캐시 쓰기는 `TodayEventCacheWriter` 한 곳.
- 완료 상태: Dozy 비반복 → `DozyEvent.isCompleted`, 그 외(Apple · Google · 반복 Dozy) → `EventCompletion(eventID, eventDate)`. 토글은 `ToggleEventCompletionUseCase` 로 통일.
- 공유 캘린더는 Supabase Realtime(포그라운드 한정) + 포그라운드 복귀 시 resync. 푸시 인프라 없음(#95 예정).
- AI 요약은 iOS 26 Foundation Models(온디바이스) → 실패 시 NaturalLanguage 로컬 폴백. 외부 LLM API 호출 없음.

## 문자열 · 로그

- 모든 사용자 문구는 한국어 소스 + `Localizable.xcstrings` 에 `en` 번역 추가. 앱 문구는 `Dozy AI/Resources/`, 위젯 문구는 `DozyWidgets/`.
- xcstrings 는 JSON 재직렬화하지 말고 **텍스트로 항목을 덧붙인다** (Xcode 정렬 규칙과 달라 diff 가 수백 줄로 불어난다). 파일 끝은 개행 없이 `}` 로 끝난다.
- 로그는 `Logger.<category>` (`Core/Utilities/Logger.swift`). 새 기능은 카테고리를 추가하고 Console 필터를 이슈 본문 "참고"에 적는다.
- **아이콘은 `Image(symbol:)` · `Label(_:symbol:)`** (`Core/Utilities/DozyIcon.swift`). SF 이름을 그대로 넘기면 `DozyIcons.xcassets` 의 Iconsax 심볼셋으로 그리고, 매핑이 없으면 SF Symbol 로 폴백한다. `Image(systemName:)` 직접 호출은 하단 탭바(`DozyMainTabBar`)만. 새 아이콘 추가는 `scripts/iconsax/mapping.py` 에 한 줄 → `python3 -I scripts/iconsax/build_icons.py <sf이름>` → `DozyIcon.customNames` 에 추가.

## 빌드 · 테스트 명령

```bash
# iOS (시뮬레이터)
xcodebuild -project "Dozy AI.xcodeproj" -scheme "Dozy AI" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug CODE_SIGNING_ALLOWED=NO build
# macOS
xcodebuild -project "Dozy AI.xcodeproj" -scheme "Dozy AI (macOS)" -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build
# 테스트 (전체 / 클래스 하나)
... test -only-testing:'Dozy AITests'
... test -only-testing:'Dozy AITests/<클래스>'
```

- 테스트 로그는 `Test case '...' passed` (소문자 case). 집계는 `grep -ciE "test case .* passed"`.
- 시뮬레이터에는 오늘 일정 데이터가 없다. 화면 확인이 필요한 항목은 PR "확인" 섹션에 실기기 항목으로 남긴다.
- `Secrets.xcconfig` 가 없으면 빌드가 안 된다. README 의 환경 설정을 따른다.

## 이슈 · PR 템플릿

이슈: `## 배경` → `## 작업 내용`(체크박스, Domain/Data/Presentation 등 소제목) → `## 설계 메모` → `## 범위 제외` → `## 검증`(체크박스) → `## 참고`.
PR: `Closes #N` → `## 요약` → `## 변경 사항`(**굵은 항목명** + 설명) → `## 확인`(빌드·테스트는 체크, 실기기는 미체크로 남김) → `## 참고`(알려진 동작 · 범위 밖).
구현을 마치면 이슈 본문 체크박스를 갱신하고 `## 구현 메모` 를 덧붙인다.

## 현재 로드맵 (2026-10 기준)

- v2.0.3: 완료 (2026-10-27, 마일스톤 닫힘). 마지막 항목 #71 Live Activity 는 PR #96, 앱 아이콘 Iconsax 교체는 PR #97 로 머지.
- macOS v2.0.3: 완료 (2026-10-28 심사 제출, 마일스톤 #11 닫힘, 태그 `macos-v2.0.3`). #100 자연어 입력(음성 제외) · #101 저녁 요약 알림 + 저녁 체크 · #107 테마 팔레트 · #102 AI 엔진 행 · 버전 2.0.3 (15) · #103 · #110 수정 · #112 테스트. Google 캘린더는 OAuth 검증 대기로 macOS 비활성.
- v2.0.4 수익화: #90 애널리틱스 → #91 RevenueCat → #72 자연어 질의 → #92 Pro 게이팅 → #93 페이월 → #95 APNs 푸시 → #94 글로벌 출시.
