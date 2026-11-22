import 'package:material_ui/material_ui.dart';

import '../../app_scope.dart';
import '../../core/local_date.dart';
import '../../core/theme.dart';
import '../../domain/services/period_service.dart';
import '../settings/calendar_settings_screen.dart';
import 'calendar_controller.dart';
import 'calendar_month.dart';
import 'date_action_popup.dart';
import 'month_grid.dart';

const _weekdayShort = ['월', '화', '수', '목', '금', '토', '일'];

/// Main screen: the monthly calendar is the first thing shown (§3.1).
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, this.today});

  /// Injectable clock for tests; defaults to the device date.
  final LocalDate Function()? today;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) {
      _controller = CalendarController(
        AppScope.of(context).periodService,
        today: widget.today,
      );
      _controller!.reload();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  CalendarController get c => _controller!;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: _MonthTitle(
            year: c.year,
            month: c.month,
            onPrevious: c.previousMonth,
            onNext: c.nextMonth,
            onToday: c.goToToday,
          ),
          actions: [
            IconButton(
              key: const ValueKey('calendar-settings'),
              tooltip: '캘린더 연동',
              icon: const Icon(Icons.event_available_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CalendarSettingsScreen(),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                const _WeekdayHeader(),
                MonthGrid(
                  cells: c.cells,
                  dragTarget: c.drag?.current,
                  onTapDay: _onTapDay,
                  onDeleteStart: (d) =>
                      _run(() => c.deletePeriod(d.periodId!), '기록을 삭제했어요'),
                  onClearEnd: (d) =>
                      _run(() => c.clearEnd(d.periodId!), '종료일을 지웠어요'),
                  onDragBegin: c.beginDrag,
                  onDragUpdate: c.updateDrag,
                  onDragEnd: _onDragEnd,
                  onDragCancel: c.cancelDrag,
                ),
                const SizedBox(height: 20),
                _NextPrediction(
                  date: c.loaded ? c.nextPredictedStart : null,
                  today: c.today,
                  loaded: c.loaded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onTapDay(DayCellData day, Rect rect) async {
    final action = await showDateActionPopup(context, rect);
    if (action == null) return;
    switch (action) {
      case DateAction.start:
        await _run(() => c.markStart(day.date), null);
      case DateAction.end:
        await _run(() => c.markEnd(day.date), null);
    }
  }

  Future<void> _onDragEnd() async {
    try {
      final token = await c.endDrag();
      if (token != null) _showUndo('날짜를 옮겼어요', token);
    } on PeriodConflict catch (e) {
      _showMessage(conflictMessage(e.reason));
    }
  }

  /// Runs a mutation; shows an undo snackbar if [undoMessage] is given,
  /// or a short explanation if the edit was rejected.
  Future<void> _run(
    Future<UndoToken> Function() action,
    String? undoMessage,
  ) async {
    try {
      final token = await action();
      if (undoMessage != null) _showUndo(undoMessage, token);
    } on PeriodConflict catch (e) {
      _showMessage(conflictMessage(e.reason));
    }
  }

  void _showUndo(String message, UndoToken token) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(label: '되돌리기', onPressed: () => c.undo(token)),
        ),
      );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

String conflictMessage(ConflictReason r) => switch (r) {
  ConflictReason.duplicateStart => '이미 시작일로 기록된 날짜예요.',
  ConflictReason.overlapsExisting => '다른 생리 기간과 겹쳐요.',
  ConflictReason.endBeforeStart => '종료일은 시작일보다 앞설 수 없어요.',
  ConflictReason.noStartBeforeDate => '이 날짜 이전에 시작일이 없어요.',
  ConflictReason.noInterval => '직전 시작일이 없어 주기를 계산할 수 없어요.',
  ConflictReason.notFound => '기록을 찾을 수 없어요.',
};

class _MonthTitle extends StatelessWidget {
  const _MonthTitle({
    required this.year,
    required this.month,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final int year;
  final int month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const ValueKey('prev-month'),
          tooltip: '이전 달',
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrevious,
        ),
        GestureDetector(
          onTap: onToday,
          child: Text(
            '$year년 $month월',
            key: const ValueKey('month-title'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          key: const ValueKey('next-month'),
          tooltip: '다음 달',
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    const labels = ['일', '월', '화', '수', '목', '금', '토'];
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Center(
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 13,
                    color: i == 0 ? AppColors.sunday : AppColors.secondaryText,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NextPrediction extends StatelessWidget {
  const _NextPrediction({
    required this.date,
    required this.today,
    required this.loaded,
  });

  final LocalDate? date;
  final LocalDate today;
  final bool loaded;

  @override
  Widget build(BuildContext context) {
    if (!loaded) return const SizedBox.shrink();
    final d = date;
    if (d == null) {
      return const Text(
        '시작일을 기록하면 예상일이 표시돼요',
        style: TextStyle(color: AppColors.secondaryText),
      );
    }
    final diff = today.daysUntil(d);
    final when = diff > 0 ? '$diff일 후' : (diff == 0 ? '오늘' : '${-diff}일 지남');
    return Column(
      children: [
        const Text(
          '다음 예상 시작일',
          style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
        ),
        const SizedBox(height: 4),
        Text(
          '${d.month}월 ${d.day}일 (${_weekdayShort[d.weekday - 1]})',
          key: const ValueKey('next-predicted'),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.predictedText,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$when · 예상일',
          style: const TextStyle(fontSize: 13, color: AppColors.secondaryText),
        ),
      ],
    );
  }
}
