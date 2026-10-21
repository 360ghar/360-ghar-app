import 'package:flutter/foundation.dart';

/// The one error body the backend sends for every non-2xx JSON response:
///
///     {"error": {"code": "TOKEN_INVALID", "message": "...", "details": {...}}}
///
/// `details` is absent when empty. A 422 carries `details.fields`, a list of
/// `{field, msg, type}` with `field` like `body.price` or `query.limit`. OAuth routes can send an
/// RFC 6749 body instead; this app calls none of them.
@immutable
class ApiErrorBody {
  const ApiErrorBody({required this.code, this.message, this.details = const {}});

  /// A stable machine code such as `USER_INACTIVE`. Branch on this, never on [message].
  final String code;
  final String? message;
  final Map<String, dynamic> details;

  /// `details.fields` of a 422, empty for any other error.
  List<ApiFieldError> get fields {
    final raw = details['fields'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map && item['field'] is String)
          ApiFieldError(
            field: item['field'] as String,
            msg: item['msg'] as String? ?? '',
            type: item['type'] as String? ?? 'invalid',
          ),
    ];
  }

  /// The error types by request field, for example `{'date_of_birth': ['AGE_RANGE']}`.
  /// Null when the body names no field.
  Map<String, List<String>>? get fieldErrors {
    final errors = <String, List<String>>{};
    for (final error in fields) {
      (errors[error.name] ??= []).add(error.type);
    }
    return errors.isEmpty ? null : errors;
  }

  /// Reads the envelope from a decoded body. Null when [body] is not an error envelope.
  static ApiErrorBody? parse(Object? body) {
    if (body is! Map) return null;
    final error = body['error'];
    if (error is! Map) return null;
    final code = error['code'];
    if (code is! String || code.isEmpty) return null;
    final details = error['details'];
    return ApiErrorBody(
      code: code,
      message: error['message'] as String?,
      details: details is Map ? Map<String, dynamic>.from(details) : const {},
    );
  }
}

/// One entry of `details.fields`.
@immutable
class ApiFieldError {
  const ApiFieldError({required this.field, required this.msg, required this.type});

  /// Source and path, for example `body.date_of_birth` or `query.limit`.
  final String field;
  final String msg;

  /// A pydantic type such as `missing` or `string_too_long`, or a stable rule code such as
  /// `AGE_RANGE`, `NAME_LENGTH`, `PHONE_REQUIRED` or `PHONE_INVALID`.
  final String type;

  /// [field] without its source prefix: `date_of_birth`, `limit`, `preferences.location`.
  String get name => field.replaceFirst(RegExp(r'^(body|query|path|header|cookie)\.'), '');
}
