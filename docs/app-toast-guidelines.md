# AppToast usage

Use `AppToast` for transient application notifications. Use field errors and inline retry controls when users must correct input or recover a failed screen request. A toast must not be the only recovery control.

## Ownership

`AppToastHost` renders notifications above the app's Navigator. `MaterialApp.router.builder` installs one host in `main.dart`. The host owns its dismissal timer and cancels it when disposed. Tests that show toasts must use a host, for example through `pumpProviderApp`.

The interface accepts already-localized text. Presentation code translates messages; repositories and transport return typed failures and do not show notifications.

```dart
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_toast.dart';

AppToast.success(
  context.l10n.text('success'),
  context.l10n.text('profile_updated_successfully'),
);

AppToast.warning(context.l10n.text('location_services_disabled'));
```

## Standard methods

`success`, `error`, `warning`, and `info` accept a required title and an optional message. Select the method that matches the result. Announce a visit as confirmed only after the server confirms it. A locally persisted unresolved request needs its own pending status.

For typed failures, map the failure to a localized message with `errorMessage`. Do not display exception strings or server response bodies.

```dart
import 'package:ghar360/core/utils/error_message.dart';

AppToast.error(context.l10n.text('error'), errorMessage(context, failure));
```

If an asynchronous action uses a widget context after `await`, first check `context.mounted`. Notifiers expose result or mutation state; the view handles the notification.

## Custom messages

Use `custom` only when standard methods cannot express the message. It takes a `ToastTone` (`success`, `error`, `warning`, `info`) and provides localized text.

```dart
AppToast.custom(
  title: context.l10n.text('success'),
  message: context.l10n.text('profile_updated_successfully'),
  tone: ToastTone.success,
  duration: const Duration(seconds: 4),
);
```

The optional `mainButton` accepts a `TextButton`. With accessible navigation enabled, an actionable toast stays visible until dismissed. Use `AppToast.dismiss()` to dismiss the current message explicitly.

## Presentation behavior

- Notifications appear at the top, inside the safe area, with a 12-pixel margin and a maximum width of 560 pixels.
- The host draws a cut-corner paper shape (`CutBorder`) with 14-pixel left, 16-pixel right and 12-pixel vertical padding.
- A standard notification expires after three seconds and supports horizontal swipe dismissal.
- A new message replaces the current message and resets its timer; messages do not queue.
- The host exposes a live-region announcement. The tone selects the colors.

Keep titles and messages short. Add both English and Hindi catalog entries. Verify narrow layouts, large text, both themes, dismissal, and the notification lifetime. Avoid repeated notifications from provider rebuilds.

## Troubleshooting

If a toast does not appear, check that `AppToastHost` is mounted. Calls before host initialization or after disposal have no visible effect. Do not add a global widget context or service locator to show a startup notification; use the startup error screen.

The host fixes the position at the top. `custom` has no position argument. Pick a `ToastTone` instead of hard-coded colors.

## References

- [Implementation](../lib/core/utils/app_toast.dart)
- [Localization](../lib/core/translations/app_localizations.dart)
- [Typed error messages](../lib/core/utils/error_message.dart)
- [Notification tests](../test/core/utils/app_toast_test.dart)
