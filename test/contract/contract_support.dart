import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/auth_header_provider.dart';

export '../helpers/api_fixtures.dart';

/// A signed-in session with a fixed token. No Supabase, no refresh.
class ContractAuth extends AuthHeaderProvider {
  ContractAuth() : super();

  @override
  String get requestScope => 'user:contract';

  @override
  Future<Map<String, String>?> getAuthHeader({bool forceRefresh = false}) async => {
    'Authorization': 'Bearer contract-token',
  };

  @override
  Map<String, String>? get cachedAuthHeader => {'Authorization': 'Bearer contract-token'};
}

/// One request the app sent: method, path, query and JSON body.
class RecordedCall {
  RecordedCall(this.method, Uri uri, this.body) : path = uri.path, query = uri.queryParametersAll;

  final String method;
  final String path;
  final Map<String, List<String>> query;
  final Object? body;

  @override
  String toString() => '$method $path ${query.keys.toList()}';
}

/// An [ApiClient] that records every request and answers from [respond].
class RecordingApi {
  RecordingApi(this.respond) {
    client = ApiClient(
      baseUrl: 'https://api.example.test',
      authProvider: ContractAuth(),
      enablePerformanceMetrics: false,
      maxGetRetries: 0,
      requestDispatcher: (method, url, {body, required headers}) async {
        final call = RecordedCall(method, Uri.parse(url), body);
        calls.add(call);
        return respond(call);
      },
    );
  }

  final ApiResponse Function(RecordedCall call) respond;
  final calls = <RecordedCall>[];
  late final ApiClient client;
}

ApiResponse jsonResponse(Object? body, {int status = 200}) =>
    ApiResponse(statusCode: status, body: body, headers: const {});
