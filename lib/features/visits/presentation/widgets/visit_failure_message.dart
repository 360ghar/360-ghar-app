import 'package:flutter/widgets.dart';

import 'package:ghar360/core/storage/storage_failure.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';

String visitFailureMessage(BuildContext context, Object? error) {
  final key = switch (error) {
    StorageFailure() => 'visits_storage_error',
    AuthenticationException(isPermissionDenied: true) => 'visits_permission_error',
    AuthenticationException() => 'login_to_book_visit',
    NetworkException() => 'network_error',
    ValidationException(code: 'INVALID_VISIT_DATE') => 'select_future_datetime',
    ValidationException() => 'visits_generic_error',
    NotFoundException() => 'property_not_found',
    ApiException(statusCode: 403) => 'visits_permission_error',
    ApiException(statusCode: 409) => 'visits_conflict_error',
    ApiException(statusCode: 429) => 'visits_rate_error',
    _ => 'visits_generic_error',
  };
  return context.l10n.text(key);
}
