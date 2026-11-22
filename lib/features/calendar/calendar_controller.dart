import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/local_date.dart';
import '../../domain/models/period_record.dart';
import '../../domain/services/interim_predictor.dart';
import '../../domain/services/period_service.dart';
import 'calendar_month.dart';

enum DragEdge { start, end }

/// An in-progress long-press drag of a start or end date. Nothing is
/// saved (and no sync is scheduled) until the finger is lifted (§4.4).
class DragState {
  const DragState({
    required this.periodId,
    required this.edge,
    required this.original,
    required this.current,
  });

  final String periodId;
  final DragEdge edge;
  final LocalDate original;
  final LocalDate current;

  DragState moveTo(LocalDate d) =>
      DragState(periodId: periodId, edge: edge, original: original, current: d);
}

/// State for the monthly calendar screen.
class CalendarController extends ChangeNotifier {
  CalendarController(this._service, {LocalDate Function()? today})
    : _today = today ?? LocalDate.today {
    final t = _today();
    _year = t.year;
    _month = t.month;
    _sub = _service.changes.listen((_) => reload());
  }

  final PeriodService _service;
  final LocalDate Function() _today;
  final InterimPredictor _predictor = const InterimPredictor();
  late final StreamSubscription<DataChange> _sub;

  late int _year;
  late int _month;
  List<PeriodRecord> _periods = const [];
  int _cycleLength = 28;
  int _periodLength = 5;
  DragState? _drag;
  bool _loaded = false;

  int get year => _year;
  int get month => _month;
  bool get loaded => _loaded;
  DragState? get drag => _drag;
  LocalDate get today => _today();

  /// Periods as displayed: saved records with the drag preview applied.
  List<PeriodRecord> get displayPeriods {
    final d = _drag;
    if (d == null) return _periods;
    return [
      for (final p in _periods)
        if (p.id != d.periodId)
          p
        else if (d.edge == DragEdge.start)
          p.copyWith(startDate: d.current)
        else
          p.copyWith(endDate: d.current),
    ];
  }

  InterimPrediction get prediction => _predictor.predict(
    periods: displayPeriods,
    cycleLength: _cycleLength,
    periodLength: _periodLength,
    today: _today(),
  );

  LocalDate? get nextPredictedStart {
    final up = prediction.upcoming;
    return up.isEmpty ? null : up.first.start;
  }

  List<DayCellData> get cells => buildMonthGrid(
    year: _year,
    month: _month,
    periods: displayPeriods,
    prediction: prediction,
    today: _today(),
  );

  Future<void> _reloadQueue = Future.value();
  bool _disposed = false;

  /// Re-reads saved data. Calls run one after another in order, so the
  /// last applied state is always the newest; awaiting a call means its
  /// data is on screen. Nothing happens after [dispose].
  /// A failed reload reports its error to its own caller but does not
  /// block later reloads.
  Future<void> reload() => _reloadQueue = _reloadQueue
      .catchError((Object _) {})
      .then((_) => _reloadNow());

  Future<void> _reloadNow() async {
    if (_disposed) return;
    final periods = await _service.periods();
    final cycle = await _service.defaultCycleLength();
    final period = await _service.defaultPeriodLength();
    if (_disposed) return;
    _periods = periods;
    _cycleLength = cycle;
    _periodLength = period;
    _loaded = true;
    notifyListeners();
  }

  // ------------------------------------------------------------ navigation

  void previousMonth() => _shiftMonth(-1);
  void nextMonth() => _shiftMonth(1);

  void goToToday() {
    final t = _today();
    _year = t.year;
    _month = t.month;
    notifyListeners();
  }

  void _shiftMonth(int delta) {
    final m = _month - 1 + delta;
    _year += (m / 12).floor();
    _month = m % 12 + 1;
    notifyListeners();
  }

  // --------------------------------------------------------------- actions
  // Each throws PeriodConflict on invalid input and returns an UndoToken.

  Future<UndoToken> markStart(LocalDate d) => _service.markStart(d);
  Future<UndoToken> markEnd(LocalDate d) => _service.markEnd(d);
  Future<UndoToken> deletePeriod(String id) => _service.deletePeriod(id);
  Future<UndoToken> clearEnd(String id) => _service.clearEnd(id);
  Future<UndoToken> undo(UndoToken t) => _service.undo(t);

  // ------------------------------------------------------------------ drag

  /// Starts dragging if [date] is an actual start or end. Returns whether
  /// drag mode was entered.
  bool beginDrag(LocalDate date) {
    for (final p in _periods) {
      if (p.startDate == date) {
        _drag = DragState(
          periodId: p.id,
          edge: DragEdge.start,
          original: date,
          current: date,
        );
        notifyListeners();
        return true;
      }
      if (p.endDate == date) {
        _drag = DragState(
          periodId: p.id,
          edge: DragEdge.end,
          original: date,
          current: date,
        );
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  void updateDrag(LocalDate date) {
    final d = _drag;
    if (d == null || d.current == date) return;
    _drag = d.moveTo(date);
    notifyListeners();
  }

  void cancelDrag() {
    if (_drag == null) return;
    _drag = null;
    notifyListeners();
  }

  /// Saves the drop. Returns null if the date did not change. On conflict
  /// the preview is reverted and the PeriodConflict is rethrown.
  Future<UndoToken?> endDrag() async {
    final d = _drag;
    if (d == null) return null;
    if (d.current == d.original) {
      cancelDrag();
      return null;
    }
    try {
      final token = d.edge == DragEdge.start
          ? await _service.moveStart(d.periodId, d.current)
          : await _service.moveEnd(d.periodId, d.current);
      _drag = null;
      await reload();
      return token;
    } catch (_) {
      cancelDrag();
      rethrow;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _sub.cancel();
    super.dispose();
  }
}
