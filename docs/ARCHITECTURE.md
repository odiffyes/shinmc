# 아키텍처

## 계층 구조

```
lib/
  main.dart                 앱 진입점: DB 열기 → 서비스 생성 → AppScope 주입
  app.dart                  MaterialApp, 테마
  app_scope.dart            InheritedWidget 기반 의존성 주입 (외부 패키지 없음)
  core/
    local_date.dart         시간대 없는 날짜 타입 (모든 날짜 계산의 기준)
    theme.dart              색상 토큰 (실제=분홍, 예상=연분홍)
  domain/                   순수 Dart 비즈니스 로직 (Flutter UI 의존 없음)
    models/                 PeriodRecord, CycleRecord, Prediction, CalendarSyncEntry, StressLevel
    services/
      cycle_linker.dart     실제 기록 → 주기 연결 재계산 (순수 함수)
      period_service.dart   모든 데이터 변경의 단일 진입점 (검증·트랜잭션·되돌리기)
  data/
    db/schema.dart          SQLite 스키마 + 마이그레이션 목록
    db/app_database.dart    DB 열기, 전체 삭제
    repositories/           테이블별 DAO (DatabaseExecutor 기반 → 트랜잭션 안에서 사용 가능)
  features/                 화면 단위 UI (2단계부터 확장)
    home/
```

의존 방향: `features → domain/services → data/repositories → data/db`. 도메인 모델은 모든 계층에서 공유.

예측 엔진(4단계)은 `domain/services/prediction_engine.dart`, 캘린더 연동(5단계)은
`data/calendar/`(플랫폼별 어댑터) + `domain/services/sync_service.dart`에 추가할 예정.

## 데이터 모델 (SQLite)

| 테이블 | 역할 | 핵심 제약 |
|---|---|---|
| `period_records` | 실제 생리 기록 | `start_date UNIQUE`, `end_date >= start_date` |
| `cycle_records` | 주기 = 이 기록의 시작일에서 끝나는 간격. 기록당 1행 | `period_id UNIQUE`, `ON DELETE CASCADE`; `previous_period_id`는 DEFERRED FK |
| `predictions` | 미래 예상 기간 (학습 데이터로 사용 안 함) | `sequence UNIQUE` |
| `sync_targets` | 연동 대상별 상태 (`google`, `device`) | `dedupe_key`로 동일 실제 캘린더 중복 감지 |
| `calendar_sync_entries` | 앱이 만든 외부 일정 목록 | `UNIQUE(target, calendar_id, kind, local_ref_id)` |
| `app_settings` | 기본 주기/기간, `data_version`, `sync_pending_since` | |

날짜는 `YYYY-MM-DD` 텍스트, 시각은 UTC ISO-8601. 기록 간 연결은 모두 UUID 기반.

## 변경 처리 흐름 (PeriodService)

모든 기록 변경은 하나의 트랜잭션에서:

1. 변경 전 스냅샷
2. 불변 조건 검증 (시작일 중복 없음, 종료 ≥ 시작, 기간 겹침 없음) → 위반 시 `PeriodConflict`, 아무것도 저장하지 않음
3. 기록 반영
4. `CycleLinker`로 주기 재연결
5. `data_version` 증가, `sync_pending_since` 표시 (앱이 꺼져도 다음 실행 시 재동기화 근거)
6. 변경 후 스냅샷과 비교해 `UndoToken` 생성 (변경된 행의 이전 상태만 보관)

커밋 후 `changes` 스트림으로 `DataChange` 알림 → 예측 재계산·지연 동기화(3초)가 구독.

## 설계 결정 (요구사항 해석)

1. **주기 소유권**: 주기 설정은 그 주기가 *끝나는* 시작일 기록에 붙는다 (§5.2). 가장 오래된 기록의 주기는 간격이 없어 토글 비활성 (§6.2).
2. **재연결 시 설정 처리 (§7.4 "유효성 확인")**:
   - 날짜만 바뀌고 직전 기록이 같으면: 길이만 갱신, 설정 유지.
   - 직전 기록이 다른 기록으로 바뀌면 (중간 기록 삭제, 순서 역전 등): 다른 간격이므로 `예측에 반영`을 기본값 ON으로 되돌리고 `needs_review=1` 표시. 스트레스는 사용자 관찰값이므로 유지 (§6.4 자동 변경 금지).
   - 가장 오래된 기록 앞에 과거 기록이 추가되면: 이전에 선택할 수 없던 토글이므로 검토 표시 없이 ON.
3. **× 동작 (§4.5)**: 시작일의 × → 해당 생리 기록 전체 삭제. 종료일의 × → 종료일만 지우고 "종료 미확정" 상태로.
4. **종료 입력 대상 (§4.3)**: 선택 날짜 이전(당일 포함)에 시작한 가장 최근 기록의 종료일로 저장. 기존 종료일은 교체.
5. **겹침 판정**: 종료일이 없는 기록은 시작일 하루짜리로 간주해 겹침을 판정.
6. **스트레스 변경**은 `data_version`을 올리지 않고 동기화도 예약하지 않음 (예측에 영향 없음).
7. **되돌리기**: 변경된 행의 이전 상태를 그대로 복원 → 삭제 시 리셋됐던 이웃 주기 설정까지 복원. 되돌리기 결과도 토큰을 돌려주므로 다시 실행 가능.
8. **INSERT OR REPLACE 사용 금지** (`period_records`): SQLite는 REPLACE 시 행을 삭제 후 삽입하여 CASCADE로 주기 설정이 사라짐. update-then-insert 사용.

## 개인정보 (현재 반영분)

- 모든 데이터는 앱 전용 디렉터리의 로컬 SQLite에만 저장. 외부 서버·분석 SDK 없음.
- Android `allowBackup=false`: 클라우드 백업으로 건강정보 DB가 복사되지 않게 함.
- `AppDatabase.wipeAllData()`: 전체 기록 삭제 (외부 일정은 동기화 계층이 먼저 지워야 함).
- 미구현: DB 파일 암호화(SQLCipher 검토), iOS 파일 보호 등급, Google 토큰은 `flutter_secure_storage`(Keychain/Keystore)에 저장 예정 — 6단계.
