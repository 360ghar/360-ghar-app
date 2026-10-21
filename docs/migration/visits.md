# Visits and durable requests

## Accepted behavior

- [x] Manual Riverpod `NotifierProvider` owns immutable visit state. Repository and HTTP datasource use constructor injection and contain no GetX lookup, widget, navigation, or localization dependency.
- [x] Initial loading, empty content, refresh, stale cache, pagination, agent data, and mutations have separate state. Refresh failures retain appointments and cursor position. Pagination failures expose retry at the same cursor. Duplicate IDs and repeated cursors terminate safely.
- [x] A captured storage lease rejects old-account requests and writes. Provider disposal and account changes reject late list, agent, page, and mutation results. Account-owned pending lists remove previous-account content before awaiting the next read.
- [x] The first appointment page is cached in SQLite with account/environment ownership, schema version, creation/freshness/expiry metadata, a 5-minute fresh interval and 7-day retention. Cached appointments appear while the authoritative request refreshes them. Cache writes are optional; failed writes do not hide fresh server content.
- [x] Booking returns `VisitConfirmed`, `VisitUnresolved`, or `VisitFailed`. A durable operation is saved before sending the POST. A local-storage failure prevents the POST and never claims that the request was saved. Deterministic rejection marks the operation failed. Ambiguous response/network failures retain an unresolved operation.
- [x] Visit POST requests do not use transport retries. Neither startup nor connectivity events replay bookings. No queue record is removed for age or retry count. Queue capacity rejects new actions explicitly and keeps existing actions. Repeated same-property swipe intents supersede older intents without deleting history; consumers must use the latest intent.
- [x] Pending and failed visits expose GET-only reconciliation and explicit discard. Finding the same property and scheduled instant confirms the operation; finding no match does not authorize automatic resubmission. Discard explains that it does not cancel a server booking. Imported actions without an account have a separate review/discard path and are never replayed.
- [x] Forms own text controllers, preserve failed input, save account-owned drafts, block duplicate submissions, validate future local date/time and serialize UTC. Date pickers accept existing visits beyond the default window. Agent errors do not replace the appointment list. All owned widgets use Flutter dialogs, context localization/theme and 48-pixel actions.

## Backend idempotency evidence

Read-only inspection of `360ghar-backend/app/api/api_v1/endpoints/visits.py` (POST handler) and `app/services/visit.py` (booking service) found no operation/idempotency-key input or unique persisted operation constraint. The service checks for overlapping visits before inserting. That query is not a safe replay contract for an uncertain POST, nor a concurrency-safe operation key. No production requests or data changes were made. Automatic booking replay remains disabled until the backend supplies and tests a durable idempotency contract.

## Verification

- 212 tests passed in the combined Visits, queue, storage, booking dialog, and HTTP unauthorized-callback run (`/tmp/visits-final-tests.log`). The follow-up queue read-lifecycle tests check account switching before an asynchronous list completes.
- Existing datasource parsing, cursor forwarding, mutation body, relationship-manager, contact-card, form validation, form retention, and date-picker coverage was migrated to provider overrides and injected dependencies. Obsolete Get bindings, Rx-specific helpers, controller formatting, and unsafe replay/expiry expectations were replaced with ownership and durability tests.
- Real SQLite tests cover restart, capacity failure, old-account leases, recursive immutable action payloads, and explicit unowned discard. A discard operation for an unowned ID cannot delete an account-owned action.
- Widget tests cover loading, content, empty, stale, refresh failure, pagination retry, partial agent error, reconciliation/discard, narrow 320-pixel light/dark layouts at 1.8 text scale, keyboard insets, and tablet columns. Layout assertions are not swallowed. Narrow-layout tests found and fixed card/agent overflows.
- Native dialer, WhatsApp, real backend booking, and device screenshots still require the final app-level Android/iOS journey checks. Widget tests do not prove those integrations.

## Integration boundary

`VisitsView()` reads `visitsProvider`. `PropertyDetailsBottomBar(property: ...)` reads it directly. Open booking with `showBookVisitDialog(context, property)`. A details route receives a property or property ID through `context.push(AppRoutes.propertyDetails, extra: ...)`. Router/composition removes legacy Visits bindings and registrations. Root `ProviderScope` disables automatic provider retry; HTTP remains the only owner of safe query retries.
