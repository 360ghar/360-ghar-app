import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_performance_platform_interface/firebase_performance_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import '../../helpers/log_capture.dart';

class _Metric extends HttpMetricPlatform {
  _Metric(this.failure);
  final String? failure;
  int stops = 0;
  int? status;
  @override
  set httpResponseCode(int? value) {
    if (failure == 'attributes') throw StateError('private-metric-attributes');
    status = value;
  }

  @override
  set responsePayloadSize(int? value) {}
  @override
  Future<void> start() async {
    if (failure == 'start') throw StateError('private-metric-start');
  }

  @override
  Future<void> stop() async {
    stops++;
    if (failure == 'stop') throw StateError('private-metric-stop');
  }
}

class _Performance extends FirebasePerformancePlatform {
  String? failure;
  final urls = <String>[];
  _Metric? metric;
  @override
  FirebasePerformancePlatform delegateFor({required FirebaseApp app}) => this;
  @override
  HttpMetricPlatform newHttpMetric(String url, HttpMethod method) {
    urls.add(url);
    if (failure == 'creation') throw StateError('private-metric-creation');
    return metric = _Metric(failure);
  }
}

class _NonJsonBody {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final performance = _Performance();
  late LogCapture logs;
  setUpAll(() async {
    setupFirebaseCoreMocks();
    FirebasePerformancePlatform.instance = performance;
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: '123',
        appId: '123',
        messagingSenderId: '123',
        projectId: '123',
      ),
    );
  });
  setUp(() {
    logs = LogCapture();
    performance.failure = null;
    performance.metric = null;
    performance.urls.clear();
  });
  tearDown(() => logs.close());
  ApiClient client({int status = 200, Object? body = const {'ok': true}, bool enabled = true}) =>
      ApiClient(
        baseUrl: 'http://localhost:9999',
        enablePerformanceMetrics: enabled,
        maxGetRetries: 0,
        requestDispatcher: (method, url, {body, required headers}) async =>
            ApiResponse(statusCode: status, body: {'ok': true}),
      );
  for (final failure in ['creation', 'start', 'attributes', 'stop']) {
    for (final succeeds in [false, true]) {
      test(
        '$failure monitoring failure preserves ${succeeds ? 'success' : 'HTTP failure'}',
        () async {
          performance.failure = failure;
          final api = client(status: succeeds ? 200 : 403);
          addTearDown(api.close);
          final request = api.get(
            '/properties/private-id',
            queryParams: {'token': 'private-token', 'lat': 'private-location'},
            useCache: false,
            requireAuth: false,
          );
          if (succeeds) {
            expect((await request).body, {'ok': true});
          } else {
            await expectLater(
              request,
              throwsA(isA<AppException>().having((e) => e.code, 'code', 'FORBIDDEN')),
            );
          }
          final url = Uri.parse(performance.urls.single);
          expect(url.path, '/api/v1/properties/:value');
          expect(url.query, isEmpty);
          expect(url.fragment, isEmpty);
          expect(url.userInfo, isEmpty);
          expect(logs.text, contains('StateError'));
          expect(logs.text, isNot(contains('private-')));
          if (failure != 'creation') expect(performance.metric!.stops, 1);
        },
      );
    }
  }
  for (final enabled in [false, true]) {
    test(
      'optional response-size encoding cannot reject a successful response (metrics=$enabled)',
      () async {
        final payload = _NonJsonBody();
        final api = ApiClient(
          baseUrl: 'http://localhost:9999',
          enablePerformanceMetrics: enabled,
          requestDispatcher: (_, _, {body, required headers}) async =>
              ApiResponse(statusCode: 200, body: payload),
        );
        addTearDown(api.close);
        expect((await api.get('/health', requireAuth: false, useCache: false)).body, same(payload));
        if (enabled) expect(performance.metric!.stops, 1);
      },
    );
  }
  test('monitoring does not alter actual request URL or optional auth behavior', () async {
    String? sent;
    final api = ApiClient(
      baseUrl: 'http://localhost:9999',
      enablePerformanceMetrics: true,
      requestDispatcher: (_, url, {body, required headers}) async {
        sent = url;
        return const ApiResponse(statusCode: 200, body: {});
      },
    );
    addTearDown(api.close);
    await api.get(
      '/agent/conversations/private-conversation/messages',
      queryParams: {'q': 'private-search'},
      requireAuth: false,
      useCache: false,
    );
    expect(Uri.parse(sent!).path, '/api/v1/agent/conversations/private-conversation/messages');
    expect(Uri.parse(sent!).queryParameters['q'], 'private-search');
    expect(Uri.parse(performance.urls.single).path, '/api/v1/agent/conversations/:value/messages');
    expect(logs.text, isNot(contains('private-')));
  });
}
