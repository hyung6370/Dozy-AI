---
name: release
description: "Dozy iOS 새 버전을 TestFlight 에 올리고 심사 제출 후 main 머지 · 태그 · 마일스톤 정리까지 한다. 사용자가 /release 를 부르거나 '운영 배포하자', 'TestFlight 올려줘', '심사 제출했어'라고 할 때 사용."
---

## 절차

1. **버전 번호**는 사용자에게 확인한다(마일스톤 계획이 바뀔 수 있다). `chore/ios-v<버전>` 브랜치에서 iOS 앱 · 위젯 `MARKETING_VERSION` 만 올린다(macOS 는 그대로).
2. **Firebase 설정 파일** `Dozy AI/GoogleService-Info.plist` 가 있는지 먼저 본다. 없으면 업로드하지 않는다 — 운영에서 Analytics · Crashlytics 가 꺼진다. 사용자에게 받아 `PlistBuddy -c 'Print :BUNDLE_ID'` 로 번들 ID(`com.dozy-ai.Dozy-AI`, macOS `com.dozy-ai.DozyAI.macOS`)를 확인.
3. `fastlane ios beta` — 빌드 번호 +1, Release 아카이브, dSYM Crashlytics 업로드, TestFlight 업로드.
   - App Store Connect 가 **500 오류**를 내면 "UPLOAD SUCCEEDED" 가 찍혀도 빌드가 안 생길 수 있다. Spaceship(`Spaceship::ConnectAPI::Build.all(app_id:, version: "<버전>")`)으로 확인하고, 없으면 같은 ipa 를 다시 올린다:
     `fastlane run upload_to_testflight api_key_path:<임시 JSON> ipa:"Dozy AI.ipa" skip_waiting_for_build_processing:true`
     (JSON 은 `fastlane/api_key.p8` 내용으로 스크래치패드에 만들고 바로 지운다. 키 내용을 출력하지 않는다.)
   - 처리 완료(VALID)까지 1분 간격으로 확인.
4. 버전 커밋(`Chore: iOS v<버전> (<빌드>) TestFlight 빌드 (#이슈...)`) → PR → dev 머지. 남은 이슈는 다음 마일스톤으로.
5. 사용자가 "이 버전의 새로운 기능"(한국어 + 구분선 + 영어, 기호 없이) · 프로모션 텍스트(170자) · 심사 메모를 요청하면 직전 버전 문안(Spaceship `get_app_store_version_localizations`)을 읽고 같은 형식으로.
6. **심사 제출은 사용자가 App Store Connect 에서 직접.** 제출 후: CLAUDE.md 로드맵 갱신 PR → dev, `dev` → `main` PR(`Release: iOS v<버전> (<빌드>)`) 머지, `main` 머지 커밋에 주석 태그 `v<버전>`("iOS v<버전> (<빌드>)") 푸시, 마일스톤 닫기.
7. 출시 후 Crashlytics 로 고친 오류가 사라졌는지 확인. 강제 업데이트는 Prod `app_config.min_ios_version`.
