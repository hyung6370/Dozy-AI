---
name: verify
description: "Dozy 의 iOS·macOS 빌드와 양쪽 단위 테스트 타깃을 돌리고 결과를 표로 요약한다. 사용자가 /verify 를 부르거나 '빌드 확인해줘', '테스트 돌려줘'라고 할 때, 그리고 구현을 마쳤을 때 사용. 인자로 테스트 클래스 이름을 주면 그 클래스만 먼저 돌린 뒤 전체를 돌린다."
---

## 목적

PR 올리기 전 상태를 한 번에 확인한다. 결과는 사용자가 터미널 출력을 보지 못한다는 전제로 요약한다.

## 절차

로그는 스크래치패드에 저장하고, 실패 줄만 추려서 보고한다. 긴 작업은 백그라운드로 돌리고 알림을 기다린다 (폴링 금지).

1. **iOS 빌드** (앱 + 위젯 extension 포함)
   ```bash
   xcodebuild -project "Dozy AI.xcodeproj" -scheme "Dozy AI" \
     -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
     -configuration Debug CODE_SIGNING_ALLOWED=NO build
   ```
   시뮬레이터 이름이 없으면 `xcrun simctl list devices available | grep iPhone` 으로 고른다.
2. **macOS 빌드** (iOS 빌드 성공 후, 백그라운드 가능)
   ```bash
   xcodebuild -project "Dozy AI.xcodeproj" -scheme "Dozy AI (macOS)" \
     -destination 'platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build
   ```
3. **테스트.** 인자로 클래스가 왔으면 `-only-testing:'Dozy AITests/<클래스>'` 를 먼저. 그 다음 전체:
   - iOS: `... test -only-testing:'Dozy AITests'`
   - macOS: `... -scheme "Dozy AI (macOS)" -destination 'platform=macOS' test -only-testing:'Dozy AI (macOS)Tests'` (시간이 길면 새 테스트 클래스만)
4. **집계.**
   ```bash
   grep -ciE "test case .* passed" <log>   # 'Test case' 는 소문자 c
   grep -ciE "test case .* failed" <log>
   grep -E "error:" <log> | sort -u        # 컴파일 에러
   grep -E "warning:" <log> | grep -E "<이번에 만든 파일명들>" | sort -u
   ```
   macOS 테스트 로그의 `com.apple.linkd.autoShortcut` XPC 에러는 시스템 노이즈다. 실패로 세지 않는다.

## 보고 형식

| 항목 | 결과 |
|---|---|
| iOS 빌드 (앱 + 위젯) | 통과 / 실패(에러 N) |
| macOS 빌드 | 통과 / 실패 |
| 신규 테스트 `<클래스>` N건 | iOS 통과 · macOS 통과 |
| 기존 iOS 단위 테스트 전체 | N건 통과, 실패 M |

- 실패가 있으면 에러 메시지 원문을 코드 블록으로, 원인 추정과 수정안을 한 줄씩.
- 새 코드에 컴파일 경고가 있으면 파일:줄 과 함께 적는다. 없으면 "새 코드 경고 없음".
- 시뮬레이터에서 못 보는 것(실기기 전용 동작, 오늘 일정 데이터 필요)은 "실기기 확인 필요"로 분리해 적는다 — 이게 PR "확인" 섹션의 미체크 항목이 된다.
