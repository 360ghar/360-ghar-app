import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/data/models/user_model.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/profile/data/profile_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/getx_test_binding.dart';
import '../../../helpers/mocks.dart';

void main() {
  late MockApiClient mockApiClient;

  setUp(() {
    GetxTestBinding.init();
    mockApiClient = MockApiClient();
    GetxTestBinding.bind().register<ApiClient>(mockApiClient);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  ProfileRepository createRepository() {
    return ProfileRepository();
  }

  /// A realistic user payload wrapped in the `{ "data": { ... } }` envelope
  /// that ResponseParser.unwrapObject handles.
  Map<String, dynamic> wrappedUserJson({
    int id = 1,
    String fullName = 'Test User',
    String email = 'test@example.com',
    String? phone,
    String? dateOfBirth,
    String? profileImageUrl,
  }) {
    return {
      'data': {
        'id': id,
        'supabase_user_id': 'sb-123',
        'email': email,
        'full_name': fullName,
        'phone': phone ?? '+919876543210',
        'date_of_birth': ?dateOfBirth,
        'profile_image_url': ?profileImageUrl,
        'is_active': true,
        'is_verified': false,
        'created_at': '2024-01-15T10:30:00Z',
        'preferences': <String, dynamic>{},
      },
    };
  }

  ApiResponse successResponse(Map<String, dynamic> body) {
    return ApiResponse(statusCode: 200, body: body, headers: {});
  }

  group('ProfileRepository', () {
    group('getCurrentUserProfile', () {
      test('returns UserModel on successful GET', () async {
        when(
          () => mockApiClient.get(ApiPaths.usersProfile, useCache: false, dedupe: false),
        ).thenAnswer((_) async => successResponse(wrappedUserJson()));

        final repo = createRepository();
        final user = await repo.getCurrentUserProfile();

        expect(user.email, 'test@example.com');
        expect(user.fullName, 'Test User');
        verify(
          () => mockApiClient.get(ApiPaths.usersProfile, useCache: false, dedupe: false),
        ).called(1);
      });

      test('rethrows AppException from ApiClient', () async {
        when(
          () => mockApiClient.get(
            ApiPaths.usersProfile,
            useCache: any(named: 'useCache'),
            dedupe: any(named: 'dedupe'),
          ),
        ).thenThrow(NetworkException('No internet'));

        final repo = createRepository();

        expect(() => repo.getCurrentUserProfile(), throwsA(isA<NetworkException>()));
      });

      test('rethrows unexpected exceptions', () async {
        when(
          () => mockApiClient.get(
            ApiPaths.usersProfile,
            useCache: any(named: 'useCache'),
            dedupe: any(named: 'dedupe'),
          ),
        ).thenThrow(Exception('Something broke'));

        final repo = createRepository();

        expect(() => repo.getCurrentUserProfile(), throwsException);
      });
    });

    group('updateUserProfile', () {
      test('sends PUT with profile data and returns updated UserModel', () async {
        final profileData = {'full_name': 'Updated Name'};
        when(
          () => mockApiClient.put(ApiPaths.usersProfile, body: profileData),
        ).thenAnswer((_) async => successResponse(wrappedUserJson(fullName: 'Updated Name')));

        final repo = createRepository();
        final user = await repo.updateUserProfile(profileData);

        expect(user.fullName, 'Updated Name');
        verify(() => mockApiClient.put(ApiPaths.usersProfile, body: profileData)).called(1);
      });

      test('rethrows AppException from ApiClient', () async {
        when(
          () => mockApiClient.put(ApiPaths.usersProfile, body: any(named: 'body')),
        ).thenThrow(ServerException('Server error', statusCode: 500));

        final repo = createRepository();

        expect(
          () => repo.updateUserProfile({'full_name': 'Test'}),
          throwsA(isA<ServerException>()),
        );
      });
    });

    group('updateUserPreferences', () {
      test('PUTs preferences then fetches and returns updated profile', () async {
        final prefs = {'push_notifications': false, 'email_notifications': true};

        when(
          () => mockApiClient.put(ApiPaths.usersPreferences, body: prefs),
        ).thenAnswer((_) async => successResponse({'data': <String, dynamic>{}}));

        when(
          () => mockApiClient.get(ApiPaths.usersProfile, useCache: false, dedupe: false),
        ).thenAnswer((_) async => successResponse(wrappedUserJson()));

        final repo = createRepository();
        final user = await repo.updateUserPreferences(prefs);

        expect(user.email, 'test@example.com');
        verify(() => mockApiClient.put(ApiPaths.usersPreferences, body: prefs)).called(1);
        verify(
          () => mockApiClient.get(ApiPaths.usersProfile, useCache: false, dedupe: false),
        ).called(1);
      });

      test('rethrows when PUT fails', () async {
        when(
          () => mockApiClient.put(ApiPaths.usersPreferences, body: any(named: 'body')),
        ).thenThrow(NetworkException('Offline'));

        final repo = createRepository();

        expect(
          () => repo.updateUserPreferences({'push_notifications': true}),
          throwsA(isA<NetworkException>()),
        );
      });
    });

    group('isProfileComplete', () {
      test('returns true when user has fullName and dateOfBirth', () {
        final repo = createRepository();

        final json = wrappedUserJson(fullName: 'Complete User', dateOfBirth: '1990-05-20')['data']!;
        final user = UserModel.fromJson(json);
        expect(repo.isProfileComplete(user), isTrue);
      });

      test('returns false when user lacks dateOfBirth', () {
        final repo = createRepository();

        final user = UserModel.fromJson(wrappedUserJson()['data']!);
        expect(repo.isProfileComplete(user), isFalse);
      });
    });

    group('updateUserLocation', () {
      test('PUTs latitude and longitude to location endpoint', () async {
        when(
          () => mockApiClient.put(
            ApiPaths.usersLocation,
            body: {'latitude': 28.61, 'longitude': 77.20},
          ),
        ).thenAnswer((_) async => successResponse({'data': <String, dynamic>{}}));

        final repo = createRepository();
        await repo.updateUserLocation({'current_latitude': 28.61, 'current_longitude': 77.20});

        verify(
          () => mockApiClient.put(
            ApiPaths.usersLocation,
            body: {'latitude': 28.61, 'longitude': 77.20},
          ),
        ).called(1);
      });

      test('skips the API call when latitude is null', () async {
        final repo = createRepository();
        await repo.updateUserLocation({'current_latitude': null, 'current_longitude': 77.20});

        verifyNever(() => mockApiClient.put(ApiPaths.usersLocation, body: any(named: 'body')));
      });

      test('skips the API call when longitude is null', () async {
        final repo = createRepository();
        await repo.updateUserLocation({'current_latitude': 28.61, 'current_longitude': null});

        verifyNever(() => mockApiClient.put(ApiPaths.usersLocation, body: any(named: 'body')));
      });

      test('rethrows AppException from ApiClient', () async {
        when(
          () => mockApiClient.put(ApiPaths.usersLocation, body: any(named: 'body')),
        ).thenThrow(NetworkException('Offline'));

        final repo = createRepository();
        expect(
          () => repo.updateUserLocation({'current_latitude': 1.0, 'current_longitude': 2.0}),
          throwsA(isA<NetworkException>()),
        );
      });

      test('rethrows unexpected exceptions', () async {
        when(
          () => mockApiClient.put(ApiPaths.usersLocation, body: any(named: 'body')),
        ).thenThrow(Exception('Broke'));

        final repo = createRepository();
        expect(
          () => repo.updateUserLocation({'current_latitude': 1.0, 'current_longitude': 2.0}),
          throwsException,
        );
      });
    });

    group('updateProfileField', () {
      test('delegates to updateUserProfile with a single-field map', () async {
        when(
          () => mockApiClient.put(ApiPaths.usersProfile, body: {'full_name': 'New Name'}),
        ).thenAnswer((_) async => successResponse(wrappedUserJson(fullName: 'New Name')));

        final repo = createRepository();
        final user = await repo.updateProfileField('full_name', 'New Name');

        expect(user.fullName, 'New Name');
        verify(
          () => mockApiClient.put(ApiPaths.usersProfile, body: {'full_name': 'New Name'}),
        ).called(1);
      });
    });

    group('updateProfileImage', () {
      test('uploads file and returns parsed user', () async {
        when(
          () => mockApiClient.upload(
            ApiPaths.usersAvatar,
            field: 'file',
            filePath: '/tmp/avatar.png',
          ),
        ).thenAnswer(
          (_) async => successResponse(wrappedUserJson(profileImageUrl: 'https://img.com/a.png')),
        );

        final repo = createRepository();
        final user = await repo.updateProfileImage('/tmp/avatar.png');

        expect(user.email, 'test@example.com');
        verify(
          () => mockApiClient.upload(
            ApiPaths.usersAvatar,
            field: 'file',
            filePath: '/tmp/avatar.png',
          ),
        ).called(1);
      });

      test('rethrows AppException from ApiClient', () async {
        when(
          () => mockApiClient.upload(
            ApiPaths.usersAvatar,
            field: any(named: 'field'),
            filePath: any(named: 'filePath'),
          ),
        ).thenThrow(NetworkException('Offline'));

        final repo = createRepository();
        expect(() => repo.updateProfileImage('/tmp/avatar.png'), throwsA(isA<NetworkException>()));
      });

      test('rethrows unexpected exceptions', () async {
        when(
          () => mockApiClient.upload(
            ApiPaths.usersAvatar,
            field: any(named: 'field'),
            filePath: any(named: 'filePath'),
          ),
        ).thenThrow(Exception('Broke'));

        final repo = createRepository();
        expect(() => repo.updateProfileImage('/tmp/avatar.png'), throwsException);
      });
    });

    group('getCurrentUserProfile parsing', () {
      test('defaults phone to empty string when absent', () async {
        final json = wrappedUserJson();
        (json['data'] as Map<String, dynamic>).remove('phone');
        when(
          () => mockApiClient.get(
            ApiPaths.usersProfile,
            useCache: any(named: 'useCache'),
            dedupe: any(named: 'dedupe'),
          ),
        ).thenAnswer((_) async => successResponse(json));

        final repo = createRepository();
        final user = await repo.getCurrentUserProfile();

        expect(user.phone, '');
      });

      test('defaults preferences to empty map when not a Map', () async {
        final json = wrappedUserJson();
        (json['data'] as Map<String, dynamic>)['preferences'] = 'not-a-map';
        when(
          () => mockApiClient.get(
            ApiPaths.usersProfile,
            useCache: any(named: 'useCache'),
            dedupe: any(named: 'dedupe'),
          ),
        ).thenAnswer((_) async => successResponse(json));

        final repo = createRepository();
        final user = await repo.getCurrentUserProfile();

        expect(user.preferences, isEmpty);
      });

      test('throws FormatException on empty payload', () async {
        when(
          () => mockApiClient.get(
            ApiPaths.usersProfile,
            useCache: any(named: 'useCache'),
            dedupe: any(named: 'dedupe'),
          ),
        ).thenAnswer((_) async => successResponse({'data': <String, dynamic>{}}));

        final repo = createRepository();
        expect(() => repo.getCurrentUserProfile(), throwsA(isA<FormatException>()));
      });
    });

    group('updateUserProfile error handling', () {
      test('rethrows unexpected (non-App) exceptions', () async {
        when(
          () => mockApiClient.put(ApiPaths.usersProfile, body: any(named: 'body')),
        ).thenThrow(Exception('Unexpected'));

        final repo = createRepository();
        expect(() => repo.updateUserProfile({'full_name': 'x'}), throwsException);
      });
    });
  });
}
