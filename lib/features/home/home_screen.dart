import 'package:material_ui/material_ui.dart';

import '../../app_scope.dart';
import '../../core/theme.dart';
import '../../domain/models/period_record.dart';

/// Stage 1 placeholder. The monthly calendar (stage 2) replaces the body.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<List<PeriodRecord>>? _periods;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _periods ??= AppScope.of(context).periodService.periods();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('주기')),
      body: Center(
        child: FutureBuilder<List<PeriodRecord>>(
          future: _periods,
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox.shrink();
            return Text(
              '저장된 실제 기록 ${snap.data!.length}건',
              style: const TextStyle(color: AppColors.secondaryText),
            );
          },
        ),
      ),
    );
  }
}
