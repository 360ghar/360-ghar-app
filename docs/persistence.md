# Local persistence

`AppDatabase` uses one SQLite database (`ghar360.db`) through `sqflite`. Call and
await `AppDatabase.open()` before reading application preferences. The database
owns JSON preferences, server response caches, drafts, and pending operations.
Supabase continues to own authentication credentials, session persistence, and
refresh. No credentials belong in these tables. Image files remain under the
existing image cache manager.

On web, `sqflite` has no plugin, so `AppDatabase.open()` uses `databaseFactoryFfiWeb`
(`sqflite_common_ffi_web`): SQLite runs as wasm in a shared worker and stores the
database in IndexedDB. The worker and the wasm file are `web/sqflite_sw.js` and
`web/sqlite3.wasm`. After an upgrade of `sqflite_common_ffi_web`, regenerate both with
`dart run sqflite_common_ffi_web:setup --force`. Web has no GetStorage file, so the
legacy import reads nothing there, and the image cache keeps its index in memory.

## Integration status

Bootstrap opens the database before creating the application provider scope.
One `ProviderScope` owns and closes the successful bootstrap database. Startup
failures close it before returning the error screen; retry opens a new database.
Runtime code has no GetStorage reads or writes. The importer is the only legacy
storage boundary. The database itself performs no network requests or replay.

Theme and locale have one authoritative immutable state each. Their values
change only after a successful write, with an explicit failure and retry state.
Flutter handles system brightness. Notification preferences keep draft selections
and distinguish a local write failure from a successful local save whose backend
sync failed. The injected backend callback captures account scope before disk work.
Flutter localization and context-based palette values replace global Get bridges.

ETag responses, property data, session profile snapshots, checklists, filters,
masked authentication-method hints and offline operations use this database.
Session profile refresh and successful profile/avatar mutations replace the same
account-owned cached profile. A matching cached profile is available for up to
24 hours and is marked stale until the server refresh succeeds. A transient
missing token or offline refresh does not by itself sign the user out.

Riverpod owns the signed-in user. Profile presentation reads that state directly.
Form text and focus stay local to widgets; account-keyed routes remount drafts
when the account changes. Mutation providers reject late account responses and
disposed-page completions. Profile completion Skip saves the required purpose
first and only defers remaining completion for the current account session. The
mandatory password gate cannot be skipped.

## Preferences and migration

Read preferences synchronously with `readPreference<T>` after opening the
database. `writePreference` and `writePreferences` resolve after the SQLite
transaction commits. Related values, such as language and country, should use
one `writePreferences` call. A failed write does not change the in-memory
snapshot. Invalid types return null; callers supply a documented default.

The first open reads the former application-documents `GetStorage.gs` as JSON.
If that file cannot be read, the importer tries `GetStorage.bak`. Neither source
file is modified. The importer preserves valid theme, language, onboarding,
notification and consent preferences, global filters, semantic page filter and
location snapshots, known checklist booleans, skipped app version, and masked
authentication-method hints. It removes server property lists, pagination,
loading state, server cache entries, and credentials from the import. Discover
cards are never restored from a legacy snapshot.

All imported rows and the `get_storage_import_v1` marker commit in the same
transaction. A failed import leaves no partial marker or preference update and
can be retried. Existing new-format values win over legacy values. A corrupt
primary file can recover from the backup. If neither file parses as JSON
(`LEGACY_STORAGE_CORRUPT`), nothing can be imported: opening continues with
defaults, writes the marker with the value `quarantined` (a successful import
writes `complete`), and logs a warning. Both files stay on disk untouched. A file
that cannot be read at all (permission or disk error, `LEGACY_STORAGE_UNREADABLE`)
returns a typed `StorageFailure` with no marker, so startup offers retry and a
later attempt can import. A new-format preference row that is not JSON reads as
unset (the documented default) and is logged. The row stays on disk until a write
replaces it. A corrupt row never blocks startup.

Legacy queued actions lack trustworthy ownership. All entries, including
malformed entries, are kept with no scope, status `needsReconciliation`, and
failure code `LEGACY_OWNER_UNKNOWN`. They are available only through the
separate `readUnownedLegacyActions` review API. Account queues never include
them. They must not be assigned to whichever account happens to sign in next.

## Account scope and cached data

Call `activateScope(environment: apiBaseUrl, accountId: supabaseUserId)` on each
account transition. A null account creates a guest scope. Call this immediately,
before awaiting cleanup. Capture its `StorageScope` before starting requests.
Reads and writes reject a lease from a previous account or environment, including
an A → B → A transition. Sensitive async state owners must also reject old
network results and stop active streams. A cache clear alone is not a substitute
for invalidating an active request in the transport.

Cache keys must include the complete response-shaping request: endpoint, filter,
search, location, sort, page cursor, and request format. Environment and account
are stored separately in the scope. Each row has a schema version, creation
time, freshness deadline, expiry deadline, byte count, and optional ETag.
`readCache` can return stale content until expiry; it never returns expired or
wrong-schema rows. Callers show stale state, refresh it, and keep their Discover
swipe exclusions. A cached summary may seed details but is not authoritative.

Two version numbers apply. `AppDatabase.schemaVersion` (2) is the SQLite table
layout. Upgrade to 2 empties the `cache` table. `AppDatabase.cacheSchemaVersion`
(2) is the shape of the JSON in a cache row. Bump it with any change to a cached
response model. A row written under another version reads as a miss, so a 304
never replays a body in the old shape.

The server marks authenticated property responses `Cache-Control: private,
no-store` and still sends an ETag. The client honors `no-store`: such a response
is not written, and a stored row for the same key is deleted. A property snapshot
on disk has no owner, agent or company phone number
(`PropertyModel.toStorableJson`).

When an account leaves (sign-out or a switch), `purgeScope` deletes that
account's cache rows and drafts. Pending actions stay with their account.

Use five minutes of freshness and at most 24 hours of expiry for property
responses unless a feature specifies a shorter period. Do not cache tokens or
responses that contain credentials. Cache limits are 500 rows and 20 MiB of JSON
across accounts. Writes evict expired rows then the oldest rows above either
limit. `clearCache` deletes actual entries. Corrupt cache JSON is evicted and
reported as `StorageFailure(code: 'CACHE_CORRUPT')`, allowing a remote retry.

## Drafts and operations

Drafts are scoped, timestamped JSON. They persist until the feature explicitly
removes them, until the account leaves, or until they are 30 days old (a read
deletes an older draft). Queue operations have a durable random 128-bit operation ID,
account/environment scope, payload, creation time, status, attempt count,
next-attempt time, and a non-sensitive failure code. Await `createAction` before
displaying any “saved” message. Storage exceptions include disk-full and failed
transaction errors and must be surfaced separately from network errors.

The queue retains failed and unresolved actions. It rejects new actions after
100 non-confirmed operations for an account rather than deleting earlier work.
Expiry and retry exhaustion must become visible failures, not deletions. User
retry and discard controls call the owning feature; `discardAction` removes only
the specified account's operation. Reconnection is a hint, not proof of a usable
backend. A queue runner must use one active loop and bounded backoff.

Visit creation has no verified idempotency contract. The backend only checks
overlapping visits before insertion; it has no operation-key uniqueness or
concurrency constraint. Disable automatic mutation retry and visit replay.
A failed or interrupted submission becomes `needsReconciliation`. Refresh the
authoritative visits list and require review before resubmission. A matching
existing visit is confirmed only from the server response. An operation ID in
this local table does not create server-side idempotency.

## Verification

`test/core/storage/app_database_test.dart` uses real SQLite through
`sqflite_common_ffi`. It covers restart durability, isolated writes, atomic
rollback, disk-full failure, interrupted migration, backup recovery, corruption,
ownership quarantine, account changes, stale cache, expiry, eviction, drafts,
queue limits, and duplicate operation IDs. Native device checks still need to
verify the platform database path and application upgrade from an installed
GetStorage release. Provider ownership must close the database at app teardown.
