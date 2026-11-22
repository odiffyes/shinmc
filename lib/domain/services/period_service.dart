import 'dart:async';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/local_date.dart';
import '../../data/repositories/cycle_repository.dart';
import '../../data/repositories/period_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../models/cycle_record.dart';
import '../models/period_record.dart';
import '../models/stress_level.dart';
import 'cycle_linker.dart';

enum ConflictReason {
  /// A period already starts on that date.
  duplicateStart,

  /// The change would make two periods overlap.
  overlapsExisting,

  /// End date would be before the start date (e.g. a drag crossed over).
  endBeforeStart,

  /// "End" was tapped on a date with no actual start on or before it.
  noStartBeforeDate,

  /// The cycle has no previous start, so it cannot be toggled (§6.2).
  noInterval,

  /// The record no longer exists.
  notFound,
}

/// Thrown when a requested edit violates the record invariants. Nothing is
/// written when this is thrown; the UI decides how to present it.
class PeriodConflict implements Exception {
  const PeriodConflict(this.reason, [this.detail]);
  final ConflictReason reason;
  final String? detail;
  @override
  String toString() =>
      'PeriodConflict(${reason.name}${detail == null ? '' : ': $detail'})';
}

/// Before-images of every row a mutation touched. Passing it to
/// [PeriodService.undo] restores exactly those rows (spec §4.4, §4.5).
class UndoToken {
  const UndoToken._(this.periodsBefore, this.cyclesBefore);

  /// id -> row before the change (null = row did not exist).
  final Map<String, PeriodRecord?> periodsBefore;
  final Map<String, CycleRecord?> cyclesBefore;

  bool get isEmpty => periodsBefore.isEmpty && cyclesBefore.isEmpty;
}

/// Emitted after every committed change.
class DataChange {
  const DataChange({
    required this.affectsPredictions,
    required this.dataVersion,
  });

  /// False for stress-only edits, which never change predictions (§6.4).
  final bool affectsPredictions;
  final int dataVersion;
}

/// The single entry point for changing period/cycle data.
///
/// Every mutation runs in one transaction that: validates invariants,
/// writes the change, re-links cycles by record ID, bumps the data version
/// and marks external calendars stale. It returns an [UndoToken].
///
/// Invariants on actual periods:
/// * start dates are unique;
/// * `end >= start` when an end exists;
/// * periods never overlap: each period's last day (end, or start if the end
///   is not recorded) is before the next period's start.
class PeriodService {
  PeriodService(
    this._db, {
    this._periods = const PeriodRepository(),
    this._cycles = const CycleRepository(),
    this._settings = const SettingsRepository(),
    String Function()? newId,
    DateTime Function()? now,
  }) : _newId = newId ?? const Uuid().v4,
       _now = now ?? DateTime.now;

  final Database _db;
  final PeriodRepository _periods;
  final CycleRepository _cycles;
  final SettingsRepository _settings;
  final String Function() _newId;
  final DateTime Function() _now;

  final _changes = StreamController<DataChange>.broadcast();

  /// Fires after each committed change (used by the sync scheduler, UI).
  Stream<DataChange> get changes => _changes.stream;

  // ---------------------------------------------------------------- reads

  Future<List<PeriodRecord>> periods() => _periods.all(_db);

  Future<List<CycleRecord>> cycles() => _cycles.all(_db);

  Future<CycleRecord?> cycleFor(String periodId) =>
      _cycles.byPeriodId(_db, periodId);

  // ------------------------------------------------------------ mutations

  /// "시작" on [date]: records a new actual period starting that day.
  Future<UndoToken> markStart(LocalDate date) => _mutate((list) {
    if (list.any((p) => p.startDate == date)) {
      throw const PeriodConflict(ConflictReason.duplicateStart);
    }
    final now = _now();
    return [
      ...list,
      PeriodRecord(
        id: _newId(),
        startDate: date,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  });

  /// "종료" on [date]: sets the end of the latest period starting on or
  /// before [date]. Replaces an existing end.
  Future<UndoToken> markEnd(LocalDate date) => _mutate((list) {
    final candidates = list.where((p) => !p.startDate.isAfter(date));
    if (candidates.isEmpty) {
      throw const PeriodConflict(ConflictReason.noStartBeforeDate);
    }
    final target = candidates.reduce(
      (a, b) => a.startDate.isAfter(b.startDate) ? a : b,
    );
    return _replace(list, target.copyWith(endDate: date, updatedAt: _now()));
  });

  /// Drag-drop of a start date. Data is written only on drop; the UI must
  /// not call this during the drag (§4.4).
  Future<UndoToken> moveStart(String periodId, LocalDate date) =>
      _mutate((list) {
        final p = _find(list, periodId);
        if (p.endDate != null && date.isAfter(p.endDate!)) {
          throw const PeriodConflict(ConflictReason.endBeforeStart);
        }
        if (list.any((o) => o.id != periodId && o.startDate == date)) {
          throw const PeriodConflict(ConflictReason.duplicateStart);
        }
        return _replace(list, p.copyWith(startDate: date, updatedAt: _now()));
      });

  /// Drag-drop of an end date.
  Future<UndoToken> moveEnd(String periodId, LocalDate date) => _mutate((list) {
    final p = _find(list, periodId);
    if (date.isBefore(p.startDate)) {
      throw const PeriodConflict(ConflictReason.endBeforeStart);
    }
    return _replace(list, p.copyWith(endDate: date, updatedAt: _now()));
  });

  /// × on an end date: the actual end becomes "not recorded".
  Future<UndoToken> clearEnd(String periodId) => _mutate((list) {
    final p = _find(list, periodId);
    return _replace(list, p.copyWith(clearEndDate: true, updatedAt: _now()));
  });

  /// × on a start date: deletes the whole actual period.
  Future<UndoToken> deletePeriod(String periodId) => _mutate((list) {
    _find(list, periodId);
    return list.where((p) => p.id != periodId).toList();
  });

  /// "예측에 반영" toggle for the cycle ending at [periodId]'s start.
  /// Never changes stress (§6.4).
  Future<UndoToken> setIncludeInPrediction(String periodId, bool include) =>
      _mutateCycle(periodId, affectsPredictions: true, (c) {
        if (!c.hasInterval) {
          throw const PeriodConflict(ConflictReason.noInterval);
        }
        return c.copyWith(includeInPrediction: include, needsReview: false);
      });

  /// Stress emoji for the cycle. Never changes the prediction toggle and
  /// never triggers re-prediction or calendar sync (§6.4).
  Future<UndoToken> setStress(String periodId, StressLevel stress) =>
      _mutateCycle(
        periodId,
        affectsPredictions: false,
        (c) => c.copyWith(stress: stress),
      );

  /// Restores the rows captured in [token]. Returns a token that redoes.
  Future<UndoToken> undo(UndoToken token) async {
    late UndoToken redo;
    late int version;
    await _db.transaction((txn) async {
      final before = await _snapshot(txn);

      for (final e in token.periodsBefore.entries) {
        if (e.value != null) await _periods.upsert(txn, e.value!);
      }
      for (final e in token.cyclesBefore.entries) {
        if (e.value != null) await _cycles.upsert(txn, e.value!);
      }
      for (final e in token.periodsBefore.entries) {
        if (e.value == null) await _periods.delete(txn, e.key);
      }
      for (final e in token.cyclesBefore.entries) {
        if (e.value == null) await _cycles.deleteById(txn, e.key);
      }
      await _relink(txn);
      version = await _settings.markDataChanged(txn, _now());
      redo = _diff(before, await _snapshot(txn));
    });
    _changes.add(DataChange(affectsPredictions: true, dataVersion: version));
    return redo;
  }

  Future<void> dispose() => _changes.close();

  // -------------------------------------------------------------- helpers

  Future<UndoToken> _mutate(
    List<PeriodRecord> Function(List<PeriodRecord> current) change,
  ) async {
    late UndoToken token;
    late int version;
    await _db.transaction((txn) async {
      final before = await _snapshot(txn);
      final current = before.periods.values.toList();
      final next = change(current);
      _validate(next);

      final nextIds = {for (final p in next) p.id};
      for (final p in current) {
        if (!nextIds.contains(p.id)) await _periods.delete(txn, p.id);
      }
      for (final p in next) {
        final old = before.periods[p.id];
        if (old == null) {
          await _periods.insert(txn, p);
        } else if (old != p) {
          await _periods.upsert(txn, p);
        }
      }
      await _relink(txn);
      version = await _settings.markDataChanged(txn, _now());
      token = _diff(before, await _snapshot(txn));
    });
    _changes.add(DataChange(affectsPredictions: true, dataVersion: version));
    return token;
  }

  Future<UndoToken> _mutateCycle(
    String periodId,
    CycleRecord Function(CycleRecord) change, {
    required bool affectsPredictions,
  }) async {
    late UndoToken token;
    late int version;
    await _db.transaction((txn) async {
      final c = await _cycles.byPeriodId(txn, periodId);
      if (c == null) throw const PeriodConflict(ConflictReason.notFound);
      final next = change(c).copyWith(updatedAt: _now());
      await _cycles.upsert(txn, next);
      version = affectsPredictions
          ? await _settings.markDataChanged(txn, _now())
          : await _settings.dataVersion(txn);
      token = UndoToken._(const {}, {c.id: c});
    });
    _changes.add(
      DataChange(affectsPredictions: affectsPredictions, dataVersion: version),
    );
    return token;
  }

  Future<void> _relink(DatabaseExecutor txn) async {
    final linker = CycleLinker(newId: _newId, now: _now);
    final result = linker.relink(
      await _periods.all(txn),
      await _cycles.allByPeriodId(txn),
    );
    for (final c in result.upserts) {
      await _cycles.upsert(txn, c);
    }
  }

  PeriodRecord _find(List<PeriodRecord> list, String id) => list.firstWhere(
    (p) => p.id == id,
    orElse: () => throw const PeriodConflict(ConflictReason.notFound),
  );

  List<PeriodRecord> _replace(List<PeriodRecord> list, PeriodRecord p) => [
    for (final o in list) o.id == p.id ? p : o,
  ];

  static void _validate(List<PeriodRecord> list) {
    final sorted = [...list]
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    for (var i = 0; i < sorted.length; i++) {
      final p = sorted[i];
      if (p.endDate != null && p.endDate!.isBefore(p.startDate)) {
        throw PeriodConflict(ConflictReason.endBeforeStart, p.id);
      }
      if (i == 0) continue;
      final prev = sorted[i - 1];
      if (prev.startDate == p.startDate) {
        throw PeriodConflict(ConflictReason.duplicateStart, p.id);
      }
      final prevLast = prev.endDate ?? prev.startDate;
      if (!prevLast.isBefore(p.startDate)) {
        throw PeriodConflict(
          ConflictReason.overlapsExisting,
          '${prev.id} overlaps ${p.id}',
        );
      }
    }
  }

  Future<_Snapshot> _snapshot(DatabaseExecutor txn) async => _Snapshot(
    {for (final p in await _periods.all(txn)) p.id: p},
    {for (final c in await _cycles.all(txn)) c.id: c},
  );

  static UndoToken _diff(_Snapshot before, _Snapshot after) {
    final periods = <String, PeriodRecord?>{};
    for (final id in {...before.periods.keys, ...after.periods.keys}) {
      if (before.periods[id] != after.periods[id]) {
        periods[id] = before.periods[id];
      }
    }
    final cycles = <String, CycleRecord?>{};
    for (final id in {...before.cycles.keys, ...after.cycles.keys}) {
      if (before.cycles[id] != after.cycles[id]) {
        cycles[id] = before.cycles[id];
      }
    }
    return UndoToken._(periods, cycles);
  }
}

class _Snapshot {
  _Snapshot(this.periods, this.cycles);
  final Map<String, PeriodRecord> periods;
  final Map<String, CycleRecord> cycles;
}
