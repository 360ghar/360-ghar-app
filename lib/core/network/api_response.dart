/// Decoded transport response. This type has no UI or client-library dependency.
class ApiResponse {
  final int statusCode;
  final dynamic body;
  final Map<String, String> headers;

  const ApiResponse({required this.statusCode, this.body, this.headers = const {}});

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}
