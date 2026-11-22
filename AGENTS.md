# AGENTS.md — 작업 지침 (Codex / Claude Code 공용)

생리 주기 관리 앱 (Flutter, iOS·Android). 건강정보를 다루므로 개인정보 보호가 필수.

## 먼저 읽을 문서
1. `docs/REQUIREMENTS.md` — 요구사항 원문. 임의 삭제·축소 금지.
2. `docs/ARCHITECTURE.md` — 구조, 데이터 모델, 설계 결정.
3. `docs/PROGRESS.md` — 완료/미검증/다음 작업. **작업을 마치면 반드시 갱신.**

## 명령
```bash
./tool/setup_flutter.sh   # Flutter가 없는 클라우드 컨테이너에서 최초 1회
flutter pub get
flutter analyze          # 이슈 0 유지
flutter test             # 전체 통과 유지 (Linux/macOS에서 sqflite_common_ffi로 실행)
dart format lib test
```

## 규칙
- 기록 변경은 반드시 `PeriodService`를 통해서만 (주기 재연결·data_version·되돌리기가 여기서 보장됨).
- 날짜 계산은 `LocalDate`만 사용. `DateTime`으로 날짜 차이 계산 금지.
- 스키마 변경 시 `schema.dart`의 `schemaVersion` 증가 + `migrations`에 단계 추가. 배포된 마이그레이션 수정 금지.
- `period_records`에 `INSERT OR REPLACE` 금지 (CASCADE로 주기 설정 삭제됨).
- 예측값을 실제 기록·학습 데이터로 사용 금지.
- 건강정보를 외부 서버, 분석·광고 SDK로 전송 금지. 로그에 날짜/기록 출력 금지.
- 앱이 만든 외부 캘린더 일정만 수정·삭제 (`calendar_sync_entries`에 있는 것만).
- 기존 코드·설정을 무단으로 덮어쓰지 않는다. 작은 단위로 구현하고 테스트를 추가한다.
- 보고 시 "실제 검증됨"과 "미검증"을 구분한다.
- 커밋/코드/문서에 모델 이름을 넣지 않는다.
