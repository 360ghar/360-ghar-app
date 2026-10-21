// Every non-2xx body is `{"error": {"code", "message", "details"}}`. A 422 carries
// `details.fields`, a list of `{field, msg, type}`. The fixtures are built by the backend's own
// error functions (`app.infrastructure.errors`).

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_error.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'contract_support.dart';

void main() {
  final errors = asObject(apiFixture('errors'));

  Future<Object> failure(
    Object? body,
    int status, {
    Map<String, String> headers = const {},
    RecordingApi? into,
  }) async {
    final api =
        into ?? RecordingApi((_) => ApiResponse(statusCode: status, body: body, headers: headers));
    try {
      await api.client.get('/properties', useCache: false, dedupe: false);
    } catch (error) {
      return error;
    }
    fail('the request did not fail');
  }

  group('ApiErrorBody', () {
    test('reads code, message and details', () {
      final body = ApiErrorBody.parse(errors['unauthorized'])!;

      expect(body.code, 'TOKEN_INVALID');
      expect(body.message, isNotEmpty);
      expect(body.details, isEmpty, reason: 'details is absent when empty');
    });

    test('reads 422 details.fields as a list of field, msg and type', () {
      final body = ApiErrorBody.parse(errors['validation'])!;

      expect(body.fields.map((f) => f.field), [
        'body.date_of_birth',
        'body.full_name',
        'query.limit',
      ]);
      expect(body.fields.first.type, 'AGE_RANGE');
      expect(body.fields.first.msg, 'Must be at least 18 years old');
      expect(body.fields.first.name, 'date_of_birth');
      expect(body.fieldErrors, {
        'date_of_birth': ['AGE_RANGE'],
        'full_name': ['missing'],
        'limit': ['less_than_equal'],
      });
    });

    test('a 422 that names no field has an empty list', () {
      final body = ApiErrorBody.parse(errors['validation_no_fields'])!;

      expect(body.code, 'INVALID_CURSOR');
      expect(body.fields, isEmpty);
      expect(body.fieldErrors, isNull);
    });

    test('does not read the retired shapes', () {
      expect(ApiErrorBody.parse({'detail': 'Not found'}), isNull);
      expect(
        ApiErrorBody.parse({
          'detail': [
            {
              'loc': ['body'],
              'msg': 'x',
              'type': 'y',
            },
          ],
        }),
        isNull,
      );
      expect(ApiErrorBody.parse({'success': false, 'message': 'x'}), isNull);
      expect(ApiErrorBody.parse('<html>'), isNull);
      expect(ApiErrorBody.parse({'error': 'text'}), isNull);
    });
  });

  group('ApiClient maps the envelope to typed failures', () {
    test('401 keeps the backend code and ends the session after one forced refresh', () async {
      final api = RecordingApi((_) => ApiResponse(statusCode: 401, body: errors['unauthorized']));
      UnauthorizedEvent? event;
      api.client.onUnauthorized = (e) async => event = e;

      final error = await failure(null, 401, into: api);

      expect(error, isA<AuthenticationException>());
      final auth = error as AuthenticationException;
      expect(auth.code, 'TOKEN_INVALID');
      expect(auth.statusCode, 401);
      expect(auth.endsSession, isTrue);
      expect(api.calls, hasLength(2), reason: 'one retry after a forced token refresh');
      expect(event?.error.code, 'TOKEN_INVALID');
    });

    test('403 USER_INACTIVE ends the session', () async {
      final api = RecordingApi((_) => ApiResponse(statusCode: 403, body: errors['inactive']));
      UnauthorizedEvent? event;
      api.client.onUnauthorized = (e) async => event = e;

      final error = await failure(null, 403, into: api) as AuthenticationException;

      expect(error.code, 'USER_INACTIVE');
      expect(error.endsSession, isTrue);
      expect(error.isPermissionDenied, isFalse);
      expect(event, isNotNull);
      expect(api.calls, hasLength(1), reason: 'a 403 is not refreshed');
    });

    test('403 for any other reason is a permission refusal and keeps the session', () async {
      final api = RecordingApi((_) => ApiResponse(statusCode: 403, body: errors['forbidden']));
      UnauthorizedEvent? event;
      api.client.onUnauthorized = (e) async => event = e;

      final error = await failure(null, 403, into: api) as AuthenticationException;

      expect(error.code, 'USER_ACCESS_DENIED');
      expect(error.endsSession, isFalse);
      expect(error.isPermissionDenied, isTrue);
      expect(event, isNull);
    });

    test('404 and 409 keep their domain codes', () async {
      final missing = await failure(errors['not_found'], 404) as ApiException;
      final conflict = await failure(errors['conflict'], 409) as ApiException;

      expect(missing.code, 'PAGE_NOT_FOUND');
      expect(missing.statusCode, 404);
      expect(conflict.code, 'VISIT_CONFLICT');
      expect(conflict.statusCode, 409);
    });

    test('422 carries the field error types, keyed by field without its source prefix', () async {
      final error = await failure(errors['validation'], 422) as ValidationException;

      expect(error.code, 'VALIDATION_ERROR');
      expect(error.fieldErrors?['date_of_birth'], ['AGE_RANGE']);
      expect(error.fieldErrors?['full_name'], ['missing']);
      expect(error.fieldErrors?['limit'], ['less_than_equal']);
    });

    test('422 with an empty field list is a validation failure with no field', () async {
      final error = await failure(errors['validation_no_fields'], 422) as ValidationException;

      expect(error.code, 'INVALID_CURSOR');
      expect(error.fieldErrors, isNull);
    });

    test('429 honours Retry-After and keeps the code', () async {
      final error =
          await failure(errors['rate_limited'], 429, headers: {'retry-after': '60'})
              as RateLimitException;

      expect(error.code, 'RATE_LIMIT_EXCEEDED');
      expect(error.retryAfter, const Duration(seconds: 60));
    });

    test('429 without the header waits the default', () async {
      final error = await failure(errors['rate_limited'], 429) as RateLimitException;

      expect(error.retryAfter, RateLimitException.defaultWait);
    });

    test('5xx is a server failure with a fixed message and the backend code', () async {
      final error = await failure(errors['server'], 500) as ServerException;

      expect(error.code, 'INTERNAL_ERROR');
      expect(error.statusCode, 500);
      expect(
        error.message,
        isNot(contains('unexpected')),
        reason: 'the UI never shows server text',
      );
    });

    test('503 honours Retry-After', () async {
      final error =
          await failure(errors['server'], 503, headers: {'retry-after': '5'}) as ServerException;

      expect(error.retryAfter, const Duration(seconds: 5));
    });

    test('a body that is not an envelope still gives a typed failure by status', () async {
      final unauthorized = await failure({'detail': 'x'}, 401) as AuthenticationException;
      final forbidden = await failure('<html>', 403) as AuthenticationException;
      final notFound = await failure(null, 404) as ApiException;

      expect(unauthorized.code, AppException.unauthorizedCode);
      expect(forbidden.code, 'FORBIDDEN');
      expect(notFound.code, isNull);
      expect(notFound.statusCode, 404);
    });
  });
}
