/// SQLite schema. Bump [schemaVersion] and add a step to [migrations]
/// for every change; never edit a released migration.
const int schemaVersion = 1;

const String tPeriods = 'period_records';
const String tCycles = 'cycle_records';
const String tPredictions = 'predictions';
const String tSyncTargets = 'sync_targets';
const String tSyncEntries = 'calendar_sync_entries';
const String tSettings = 'app_settings';

const List<String> _v1 = [
  '''
  CREATE TABLE $tPeriods (
    id          TEXT PRIMARY KEY,
    start_date  TEXT NOT NULL UNIQUE,
    end_date    TEXT,
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL,
    CHECK (end_date IS NULL OR end_date >= start_date)
  )
  ''',
  '''
  CREATE TABLE $tCycles (
    id                     TEXT PRIMARY KEY,
    period_id              TEXT NOT NULL UNIQUE
                             REFERENCES $tPeriods(id) ON DELETE CASCADE,
    -- Deferred (no SET NULL): a delete may leave this stale mid-transaction,
    -- PeriodService re-links it before commit, and the commit fails if a
    -- stale link is ever left behind.
    previous_period_id     TEXT
                             REFERENCES $tPeriods(id)
                             DEFERRABLE INITIALLY DEFERRED,
    length_days            INTEGER,
    include_in_prediction  INTEGER NOT NULL DEFAULT 1
                             CHECK (include_in_prediction IN (0, 1)),
    stress                 TEXT NOT NULL DEFAULT 'unrecorded'
                             CHECK (stress IN ('unrecorded','calm','neutral','high')),
    needs_review           INTEGER NOT NULL DEFAULT 0
                             CHECK (needs_review IN (0, 1)),
    updated_at             TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE $tPredictions (
    id            TEXT PRIMARY KEY,
    sequence      INTEGER NOT NULL UNIQUE,
    start_date    TEXT NOT NULL,
    end_date      TEXT NOT NULL,
    data_version  INTEGER NOT NULL,
    generated_at  TEXT NOT NULL
  )
  ''',
  // One row per calendar back-end. `dedupe_key` identifies the real
  // underlying calendar (e.g. the Google account behind a device calendar)
  // so the same Google calendar is never written via both paths (§9.2).
  '''
  CREATE TABLE $tSyncTargets (
    target          TEXT PRIMARY KEY CHECK (target IN ('google','device')),
    enabled         INTEGER NOT NULL DEFAULT 0 CHECK (enabled IN (0, 1)),
    calendar_id     TEXT,
    dedupe_key      TEXT,
    state           TEXT NOT NULL DEFAULT 'idle',
    last_error      TEXT,
    last_synced_at  TEXT
  )
  ''',
  '''
  CREATE TABLE $tSyncEntries (
    id                 TEXT PRIMARY KEY,
    target             TEXT NOT NULL REFERENCES $tSyncTargets(target),
    calendar_id        TEXT NOT NULL,
    local_ref_id       TEXT NOT NULL,
    kind               TEXT NOT NULL CHECK (kind IN ('actual','predicted')),
    external_event_id  TEXT,
    content_hash       TEXT,
    status             TEXT NOT NULL
                         CHECK (status IN ('pending','synced','failed','deleting')),
    last_error         TEXT,
    last_synced_at     TEXT,
    UNIQUE (target, calendar_id, kind, local_ref_id)
  )
  ''',
  '''
  CREATE TABLE $tSettings (
    key    TEXT PRIMARY KEY,
    value  TEXT
  )
  ''',
  'CREATE INDEX idx_cycles_previous ON $tCycles(previous_period_id)',
  "INSERT INTO $tSyncTargets(target) VALUES ('google'), ('device')",
];

/// migrations[n] upgrades a database from version n to n + 1.
/// migrations[0] creates the initial schema.
const List<List<String>> migrations = [_v1];
