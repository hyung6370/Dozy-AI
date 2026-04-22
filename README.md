# Dozy — AI 일정 관리 앱

> 하루를 기록하고, 패턴을 발견하고, 더 나은 내일을 설계하는 iOS 생산성 앱

[![iOS](https://img.shields.io/badge/iOS-17.6+-black?style=flat&logo=apple)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.0-orange?style=flat&logo=swift)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-✓-blue?style=flat)](https://developer.apple.com/xcode/swiftui/)
[![Supabase](https://img.shields.io/badge/Supabase-✓-3FCF8E?style=flat&logo=supabase)](https://supabase.com)

---

## 소개

Dozy는 Apple Calendar, Google Calendar 등 기존 캘린더와 연동해 하루 일정을 한눈에 파악하고, AI 기반 일일 요약과 생산성 인사이트를 제공하는 iOS 앱입니다.

- 여러 캘린더 소스를 하나의 뷰에서 통합 관리
- 완료한 일정과 할 일을 기록하고 생산성 점수로 확인
- AI가 오늘 하루를 요약하고 다음 액션을 추천
- 주간/월간/분기별 패턴 분석으로 업무 흐름 파악

---

## 주요 기능

| 기능 | 설명 |
|------|------|
| 홈 대시보드 | 오늘 일정 타임라인, AI 요약, 빠른 메모, 생산성 통계 |
| 캘린더 | Apple·Google·Dozy 자체 캘린더 통합, 일정 생성·수정·삭제·반복 |
| 공유 캘린더 | 초대 코드로 두 사람 공유, 파트너와 일정·메모 실시간 동기화 |
| 외부 일정 공유 | Apple·Google 일정을 공유 캘린더로 미러링, 원본 변경 자동 반영 |
| 일정 완료 체크 | 완료 여부 기록, EventCompletion 기반 날짜별 상태 관리 |
| AI 일일 요약 | iOS 26+ Foundation Models / NaturalLanguage 로컬 폴백 |
| 인사이트 | 카테고리별 활동 분석, 완료율, 패턴 기반 추천 |
| 클라우드 동기화 | Supabase 기반 멀티 디바이스 데이터 동기화 |
| 다중 로그인 | Apple · Google · Naver 소셜 로그인 |

---

## 기술 스택

### Frontend
- **SwiftUI** — 선언형 UI
- **SwiftData** — 로컬 데이터 영속성
- **Combine** — 비동기 이벤트 스트림
- **EventKit** — 시스템 캘린더·리마인더 연동
- **NaturalLanguage** — 온디바이스 NLP 키워드 추출

### Backend
- **Supabase** — Auth, PostgreSQL, Realtime
- **Google Sign-In SDK**
- **Naver Login SDK**

### 인프라 / 개발 도구
- **Fastlane** — TestFlight·App Store 자동 배포
- **Swift Package Manager** — 의존성 관리
- **App Store Connect API** — 빌드 번호 자동 관리

---

## 아키텍처

Clean Architecture + MVVM 패턴을 적용했습니다.

```
Presentation  ──▶  Domain  ──▶  Data
(View / ViewModel)  (UseCase / Model / Protocol)  (Service / Repository / SwiftData)
```

```
Dozy AI/
├── App/                  앱 진입점
├── Presentation/         UI (View + ViewModel)
│   ├── Home/
│   ├── Calendar/
│   ├── Insights/
│   ├── Settings/
│   └── Components/       재사용 컴포넌트
├── Domain/               비즈니스 로직
│   ├── UseCases/         (20+ UseCase)
│   ├── Models/           도메인 엔티티
│   └── Protocols/        서비스 추상화
├── Data/                 데이터 접근
│   ├── Services/         Calendar, AI, Auth 등
│   ├── Repositories/     SwiftData CRUD
│   └── DTO/              Supabase 매핑
└── Core/
    ├── DI/               DependencyContainer
    ├── Extensions/
    └── Utilities/        Logger, Keychain 등
```

**DependencyContainer**가 모든 의존성을 조립하며, ViewModel은 UseCase만 주입받습니다.

---

## 시작하기

### 요구사항

- Xcode 16+
- iOS 17.6+
- [Supabase](https://supabase.com) 프로젝트 (Auth + DB 설정)
- Google OAuth 클라이언트 ID ([Google Cloud Console](https://console.cloud.google.com))

### 설치

```bash
git clone https://github.com/your-username/Dozy-AI.git
cd Dozy-AI
```

Xcode에서 `Dozy AI.xcodeproj`를 열면 Swift Package Manager가 의존성을 자동으로 설치합니다.

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

### Supabase 스키마

`supabase/migrations/` 아래의 `.sql` 파일을 시간순으로 Supabase SQL Editor에서 실행하거나, Supabase CLI로 push하여 테이블·RLS 정책·Realtime publication을 적용합니다.

```bash
supabase db push
```

---

## 배포

[Fastlane](https://fastlane.tools)으로 빌드 및 배포를 자동화합니다.

```bash
# TestFlight 베타 배포 (빌드 번호 자동 증가)
fastlane beta

# App Store 제출
fastlane release
```

`fastlane/api_key.p8` 파일은 App Store Connect API Key로, `.gitignore`에 포함되어 있습니다.

---

## 라이선스

이 프로젝트는 비공개 소프트웨어입니다. 무단 복제 및 배포를 금합니다.

© 2026 Dozy. All rights reserved.
