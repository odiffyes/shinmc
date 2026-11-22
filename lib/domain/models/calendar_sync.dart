/// External calendar back-ends (spec §9.1).
enum SyncTarget {
  google('google'),
  deviceCalendar('device'); // EventKit on iOS, Calendar Provider on Android

  const SyncTarget(this.dbValue);
  final String dbValue;

  static SyncTarget fromDb(String v) =>
      SyncTarget.values.firstWhere((t) => t.dbValue == v);
}

enum SyncEventKind {
  actual('actual'),
  predicted('predicted');

  const SyncEventKind(this.dbValue);
  final String dbValue;

  static SyncEventKind fromDb(String v) =>
      SyncEventKind.values.firstWhere((k) => k.dbValue == v);
}

enum SyncStatus {
  pending('pending'),
  synced('synced'),
  failed('failed'),
  deleting('deleting');

  const SyncStatus(this.dbValue);
  final String dbValue;

  static SyncStatus fromDb(String v) =>
      SyncStatus.values.firstWhere((s) => s.dbValue == v);
}

/// One external event the app created and owns. Only events with a row
/// here are ever modified or deleted by the app (§9.5, §10).
class CalendarSyncEntry {
  const CalendarSyncEntry({
    required this.id,
    required this.target,
    required this.calendarId,
    required this.localRefId,
    required this.kind,
    this.externalEventId,
    this.contentHash,
    required this.status,
    this.lastError,
    this.lastSyncedAt,
  });

  final String id;
  final SyncTarget target;

  /// The concrete calendar on that back-end (Google calendar ID, EventKit
  /// calendar identifier, or Android CalendarContract calendar _ID).
  final String calendarId;

  /// PeriodRecord ID for actual events; Prediction sequence key
  /// (e.g. `pred:1`) for predicted events.
  final String localRefId;
  final SyncEventKind kind;

  /// Null until the remote create succeeded. Retries reuse this row, so a
  /// failed-then-retried create cannot produce a second event.
  final String? externalEventId;

  /// Hash of the event content last written, to skip unchanged events.
  final String? contentHash;
  final SyncStatus status;
  final String? lastError;
  final DateTime? lastSyncedAt;

  Map<String, Object?> toRow() => {
    'id': id,
    'target': target.dbValue,
    'calendar_id': calendarId,
    'local_ref_id': localRefId,
    'kind': kind.dbValue,
    'external_event_id': externalEventId,
    'content_hash': contentHash,
    'status': status.dbValue,
    'last_error': lastError,
    'last_synced_at': lastSyncedAt?.toUtc().toIso8601String(),
  };

  factory CalendarSyncEntry.fromRow(Map<String, Object?> r) =>
      CalendarSyncEntry(
        id: r['id']! as String,
        target: SyncTarget.fromDb(r['target']! as String),
        calendarId: r['calendar_id']! as String,
        localRefId: r['local_ref_id']! as String,
        kind: SyncEventKind.fromDb(r['kind']! as String),
        externalEventId: r['external_event_id'] as String?,
        contentHash: r['content_hash'] as String?,
        status: SyncStatus.fromDb(r['status']! as String),
        lastError: r['last_error'] as String?,
        lastSyncedAt: r['last_synced_at'] == null
            ? null
            : DateTime.parse(r['last_synced_at']! as String),
      );
}
