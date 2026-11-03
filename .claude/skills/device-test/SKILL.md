---
name: device-test
description: "Dozy 개발 빌드를 연결된 iPhone 에 설치하고, 로그인 상태 UI 테스트와 임시 UI 테스트로 실기기 동작(권한 · Apple/Google 일정 · 수정/삭제 토스트 · 크래시 로그)을 확인한다. 사용자가 /device-test 를 부르거나 '기기에 설치해', '실기기 테스트 해줘', '이것도 너가 테스트 해줘'라고 할 때 사용."
---

## 목적

시뮬레이터 단위 테스트로 안 잡히는 것(Swift 6 런타임 격리 크래시, EventKit 권한, 네트워크 캘린더, 토스트)을 실기기에서 확인한다. 사용자가 직접 누르지 않아도 되게 XCUITest 로 돌리고, 결과는 스크린샷과 크래시 로그로 판단한다.

## 준비

1. 기기 확인: `xcrun devicectl list devices` (CoreDevice ID) · `xcrun xctrace list devices` (xcodebuild 용 UDID). 잠금이 풀려 있어야 한다.
2. 앱 상태 — **Debug 빌드는 개발 Supabase(Dozy-AI-Dev)** 에 붙는다(`Secrets.xcconfig` `SUPABASE_HOST`). 테스트 계정은 Dev 에 있다(자격 증명은 사용자에게 받고 파일 · 메모리에 쓰지 않는다).
   - `RecurrenceInputUITests` 는 **로그인 상태 전제**다. 로그아웃이면 새 일정 화면이 안 열려 74줄에서 실패한다 → 사용자에게 로그인을 부탁한다.
   - Google 캘린더 경로는 설정 › 캘린더 연동에서 **Google 연결**이 돼 있어야 한다. OAuth 동의 화면이라 사용자가 직접 연결한다.

## 설치

```bash
DD=<스크래치패드>/dd-device
xcodebuild -project "Dozy AI.xcodeproj" -scheme "Dozy AI" -destination 'id=<UDID>' -configuration Debug -allowProvisioningUpdates -derivedDataPath $DD build
xcrun devicectl device install app --device <CoreDevice ID> "$DD/Build/Products/Debug-iphoneos/Dozy AI.app"
```

## 테스트

- 로그인 상태 회귀: `... -derivedDataPath $DD test -only-testing:'Dozy AIUITests/RecurrenceInputUITests'`
- 이슈별 확인은 **임시 UI 테스트** `Dozy AIUITests/AAATemp<이름>UITests.swift` 를 만들어 돌린다. **커밋하지 않는다.**
  - 등록: xcodeproj gem 으로 `Dozy AIUITests` 타깃 소스에 추가 (CLAUDE.md "타깃 · 파일 등록"). 끝나면 파일을 지우고 `git checkout -- "Dozy AI.xcodeproj/project.pbxproj"`.
  - 테스트 데이터는 러너 프로세스의 `EKEventStore` 로 만든다(오늘 늦은 시각, 제목에 고유 접두어 + 타임스탬프). 러너에 권한 문구가 필요하다 — 타깃 빌드 설정에 `INFOPLIST_KEY_NSCalendarsFullAccessUsageDescription` · `INFOPLIST_KEY_NSRemindersFullAccessUsageDescription` 임시 추가. 마지막 테스트(`test_9_cleanup`)에서 접두어로 지운다. 사용자의 실제 일정은 절대 수정 · 삭제하지 않는다.
  - 앱 권한 요청 경로: `app.resetAuthorizationStatus(for: .calendar / .reminders)` 후 실행 → `XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts` 의 "전체 접근 허용" / "허용" 을 누른다. **알림 권한은 초기화 API 가 없다** — 로그인 시 실행 + 크래시 로그 없음으로 갈음.
- Swift 6 테스트 타깃 주의: `XCUIApplication` · `EKEventStore` 저장 프로퍼티 기본값은 메인 액터 오류 → 계산 프로퍼티 / `lazy var`. `async let` 결과를 `XCTAssert` 안에서 바로 쓰지 않는다. EventKit 권한 요청은 `@Sendable` 콜백 + `expectation`.

## 화면 조작 메모 (iOS 26)

- 일정 삭제 확인은 알림창이 아니라 **버튼 위 팝오버**다 — "삭제" 버튼 중 원래 버튼보다 위(`frame.midY` 작음)에 있는 것을 누른다. 원래 버튼의 y 는 누르기 **전에** 저장한다(`firstMatch` 가 다시 잡힌다).
- 홈의 결과 토스트는 **일정 상세가 열려 있으면 미뤘다가** 닫힌 뒤 보인다 → 저장 후 못 찾으면 "닫기" 를 누르고 다시 찾는다.
- 설정 하위 화면에서는 탭바가 숨는다 — `tab_home` 을 찾기 전에 뒤로 가거나 앱을 다시 띄운다.
- 캘린더 탭 월 이동은 화면 위쪽(y 0.3) 가로 드래그. 월 보기에서는 목록이 접혀 "일정 목록 보기" 버튼만 보일 수 있다.
- 홈은 일정 · 리마인더를 Zip3 로 함께 받는다 — 리마인더 조회가 실패하면 일정도 안 뜬다(리마인더는 홈에 직접 안 보인다).

## 결과 판단

```bash
R=$(ls -td $DD/Logs/Test/*.xcresult | head -1)
xcrun xcresulttool export attachments --path "$R" --output-path <폴더>   # manifest.json + 스크린샷 · UI 계층 txt
xcrun devicectl device info files --device <CoreDevice ID> --domain-type systemCrashLogs | grep -i dozy | grep -v Retired
```

- 실패하면 스크린샷 · UI 계층부터 본다. 테스트 쪽 문제(요소 못 찾음)와 앱 문제(크래시 · 값 틀림)를 구분해 보고한다.
- 보고는 표(항목 / 결과 / 근거)로. 자동으로 못 본 항목은 "실기기 확인 필요"로 남겨 PR "확인" 섹션의 미체크 항목이 되게 한다.
