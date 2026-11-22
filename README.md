# 주기 (shinmc)

실제 생리 기록을 최소한의 터치로 남기고, 누적된 개인 데이터로 다음 예정일을 예측해 Google·iOS·Android 캘린더에 동기화하는 Flutter 앱.

- 요구사항: [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md)
- 아키텍처: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- 진행 현황: [docs/PROGRESS.md](docs/PROGRESS.md)
- 작업 지침(Codex/Claude): [AGENTS.md](AGENTS.md)

## 맥북에서 이어서 작업하기
```bash
git clone <repo> && cd shinmc
git checkout claude/menstrual-cycle-app-54xpji
flutter pub get
flutter test
open ios/Runner.xcworkspace   # iOS 서명·빌드 (pod install은 flutter run/build 시 자동)
flutter run                   # 연결된 기기/시뮬레이터
```
