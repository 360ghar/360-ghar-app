# Route and application lifecycle recovery

Public property destinations carry the listing ID in the URI. Valid public tours
carry their HTTP(S) URL and optional title in the URI. Legacy in-memory arguments
are normalized before authentication redirects, so password/profile gates cannot
lose the destination. The return policy rejects unsafe URLs, credentials in tour
URLs, malformed IDs, and unsupported destinations. Private route query strings do
not carry passwords, OTPs, or session tokens.

`DeepLinkService` subscribes to warm links before reading the initial link. A late
cold property link cannot replace a newer valid warm destination. An initial OAuth
callback still completes the session exchange. Invalid warm links do not cancel a
valid cold destination.

`AppEffects` observes the router delegate and reads the currently visible URI.
An imperative push above Discover/Explore deactivates that page's GPS owner; pop
reactivates it only when the feed is visible. App lifecycle state also controls
visibility, including when the effects host mounts while the app is already
inactive. Account scope changes reapply visibility to the new provider owner.

Account-keyed password, profile, feedback, and edit-profile routes discard the
previous account's form state. Password and delete-confirmation dialogs have their
own account keys because a dialog route can outlive its parent page. Logout also
disables delete confirmation when no account remains.

## Regression mapping

| Behavior | Test owner |
| --- | --- |
| Guest tour, cold URI reconstruction, password/profile gate return | `test/core/routes/app_router_lifecycle_test.dart` |
| Public cold property and warm notification destinations | `test/core/routes/app_router_lifecycle_test.dart`, `test/core/services/auth_navigation_service_test.dart` |
| Unsafe tour/return rejection and query normalization | `test/core/services/auth_navigation_service_test.dart` |
| Cold/warm ordering, OAuth handling, invalid links | `test/core/services/deep_link_service_test.dart` |
| Imperative push/pop, branch activation order, foreground/inactive state, account owner replacement | `test/core/bootstrap/app_effects_test.dart` |
| Account changes clear password, edit-profile, feedback, and privacy-dialog drafts | Router lifecycle and `test/features/profile/presentation/views/privacy_view_test.dart` |

These tests use injected platforms, repositories, and an actual GoRouter. They do
not establish native OAuth exchange, notification delivery, WebView rendering, or
device Back/gesture acceptance. Those checks remain separate in the migration
checklist.
