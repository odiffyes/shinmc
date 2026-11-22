# 진행 현황

## 1단계: 프로젝트 기반 — 완료 (2026-11-22)

### 구현 및 검증됨 (Linux 컨테이너, `flutter test` 27개 통과, `flutter analyze` 이슈 0)
- Flutter 3.50.1 / Dart 3.14 프로젝트 (iOS, Android), 번들 ID `com.shinmc.shinmc`
- 폴더 구조 (`docs/ARCHITECTURE.md`)
- SQLite 스키마 v1 + 마이그레이션 프레임워크, 외래키 활성화
- 도메인 모델: PeriodRecord, CycleRecord, Prediction, CalendarSyncEntry, StressLevel
- `LocalDate`: 시간대/서머타임 영향 없는 날짜 계산
- `CycleLinker`: 기록 ID 기반 주기 연결 및 재연결 규칙
- `PeriodService`: 시작/종료 입력, 시작/종료 이동, 종료 삭제, 기록 삭제, 예측 반영 토글, 스트레스, 되돌리기/다시 실행, 충돌 검출
- 동기화 기반: 대상별 상태 테이블, 외부 일정 고유 ID 테이블, 중복 캘린더 감지 쿼리, `sync_pending_since`
- 전체 데이터 삭제, Android 백업 비활성화
- 앱 셸: DB를 열고 저장된 기록 수를 보여주는 임시 홈 화면

### 테스트로 커버된 §13 항목
1, 2, 3, 4, 5, 6, 7, 8, 9, 10 (도메인/DB 수준). 14는 DB 고유 제약 수준만.

### 미검증
- Android/iOS 실제 빌드 및 실행 (컨테이너에 Android SDK·Xcode 없음). 테스트는 sqflite_common_ffi로 데스크톱 SQLite에서 실행.
- 위젯 테스트는 임시 홈 화면 부팅만 확인.

## 다음: 2단계 달력 UI
- 월간 달력 (연·월 표시, 이전/다음 달, 균일한 날짜 칸)
- 실제 기간(분홍) / 시작일 강조 / 예상 기간(연분홍) 표시
- 날짜 탭 → 시작/종료 팝업 → `PeriodService.markStart/markEnd`
- × 버튼 → `deletePeriod` / `clearEnd` + 되돌리기 스낵바
- 길게 누르기 → 드래그 미리보기 → 놓을 때 `moveStart/moveEnd` (드래그 중 저장·동기화 없음)
- `PeriodConflict` 사용자 안내
- 다음 예상 시작일 표시 (4단계 엔진 전까지는 기본 주기 기반 임시 계산 여부 결정 필요)
