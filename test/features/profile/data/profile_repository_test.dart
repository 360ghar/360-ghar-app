import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/data/models/user_model.dart';
import 'package:ghar360/core/data/models/wire_enums.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/profile/data/profile_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/api_fixtures.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient mockApiClient;

  setUp(() {
    mockApiClient = MockApiClient();
  });

  ProfileRepository createRepository() => ProfileRepository(apiClient: mockApiClient);

  /// A `SelfUser` body from the backend's own response model.
  Map<String, dynamic> selfUser({Map<String, dynamic> overrides = const {}}) => {
    ...asObject(apiFixture('users')['profile']),
    ...overrides,
  };

  ApiResponse ok(Object? body) => ApiResponse(statusCode: 200, body: body, headers: const {});

  group('ProfileRepository', () {
    group('getCurrentUserProfile', () {
      test('returns the SelfUser on a successful GET', () async {
        when(
          () => mockApiClient.get(ApiPaths.usersProfile, useCache: false, dedupe: false),
        ).thenAnswer((_) async => ok(selfUser()));

        final user = await createRepository().getCurrentUserProfile();

        expect(user.email, 'asha@example.com');
        expect(user.fullName, 'Asha Verma');
        expect(user.preferences.purpose, PropertyPurpose.rent);
        verify(
          () => mockApiClient.get(ApiPaths.usersProfile, useCache: false, dedupe: false),
        ).called(1);
      });

      test('a body that is not a SelfUser is a malformed response', () async {
        when(
          () => mockApiClient.get(ApiPaths.usersProfile, useCache: false, dedupe: false),
        ).thenAnswer((_) async => ok({'data': selfUser()}));

        await expectLater(
          createRepository().getCurrentUserProfile(),
          throwsA(isA<ServerException>().having((e) => e.code, 'code', 'MALFORMED_RESPONSE')),
        );
      });

      test('rethrows AppException from ApiClient', () async {
        when(
          () => mockApiClient.get(
            ApiPaths.usersProfile,
            useCache: any(named: 'useCache'),
            dedupe: any(named: 'dedupe'),
          ),
        ).thenThrow(NetworkException('No internet'));

        expect(() => createRepository().getCurrentUserProfile(), throwsA(isA<NetworkException>()));
      });

      test('rethrows unexpected exceptions', () async {
        when(
          () => mockApiClient.get(
            ApiPaths.usersProfile,
            useCache: any(named: 'useCache'),
            dedupe: any(named: 'dedupe'),
          ),
        ).thenThrow(Exception('Something broke'));

        expect(() => createRepository().getCurrentUserProfile(), throwsException);
      });

      test('a user with no phone keeps a null phone, not an empty string', () async {
        when(
          () => mockApiClient.get(ApiPaths.usersProfile, useCache: false, dedupe: false),
        ).thenAnswer((_) async => ok(selfUser(overrides: {'phone': null})));

        expect((await createRepository().getCurrentUserProfile()).phone, isNull);
      });
    });

    group('updateUserProfile', () {
      test('sends PUT with the UserUpdate keys and returns the saved user', () async {
        final profileData = {'full_name': 'Updated Name', 'date_of_birth': '1994-02-11'};
        when(
          () => mockApiClient.put(ApiPaths.usersProfile, body: profileData),
        ).thenAnswer((_) async => ok(selfUser(overrides: {'full_name': 'Updated Name'})));

        final user = await createRepository().updateUserProfile(profileData);

        expect(user.fullName, 'Updated Name');
        verify(() => mockApiClient.put(ApiPaths.usersProfile, body: profileData)).called(1);
      });

      test('null clears a nullable key', () async {
        when(
          () => mockApiClient.put(ApiPaths.usersProfile, body: {'date_of_birth': null}),
        ).thenAnswer((_) async => ok(selfUser(overrides: {'date_of_birth': null})));

        final user = await createRepository().updateUserProfile({'date_of_birth': null});

        expect(user.dateOfBirth, isNull);
      });

      test('refuses a key the backend does not declare, before any request', () async {
        for (final key in [
          'email',
          'profile_image_url',
          'preferences',
          'first_name',
          'last_name',
          'bio',
        ]) {
          expect(
            () => createRepository().updateUserProfile({key: 'x'}),
            throwsArgumentError,
            reason: key,
          );
        }
        verifyNever(() => mockApiClient.put(any(), body: any(named: 'body')));
      });

      test('rethrows AppException from ApiClient', () async {
        when(
          () => mockApiClient.put(ApiPaths.usersProfile, body: any(named: 'body')),
        ).thenThrow(ServerException('Server error', statusCode: 500));

        expect(
          () => createRepository().updateUserProfile({'full_name': 'Test'}),
          throwsA(isA<ServerException>()),
        );
      });
    });

    group('updateUserPreferences', () {
      test('PUTs the patch and returns the preferences the backend holds', () async {
        final patch = {
          'purpose': 'buy',
          'location_preference': ['Gurugram'],
        };
        when(
          () => mockApiClient.put(ApiPaths.usersPreferences, body: patch),
        ).thenAnswer((_) async => ok(asObject(apiFixture('users')['preferences'])));

        final preferences = await createRepository().updateUserPreferences(patch);

        expect(preferences.purpose, PropertyPurpose.buy);
        expect(preferences.location, 'Gurugram');
        verify(() => mockApiClient.put(ApiPaths.usersPreferences, body: patch)).called(1);
        verifyNever(() => mockApiClient.get(ApiPaths.usersProfile, useCache: false, dedupe: false));
      });

      test('refuses keys that are not preferences', () async {
        expect(
          () => createRepository().updateUserPreferences({'push_notifications': false}),
          throwsArgumentError,
        );
        expect(
          () => createRepository().updateUserPreferences({'location': 'Gurugram'}),
          throwsArgumentError,
        );
      });

      test('rethrows when PUT fails', () async {
        when(
          () => mockApiClient.put(ApiPaths.usersPreferences, body: any(named: 'body')),
        ).thenThrow(NetworkException('Offline'));

        expect(
          () => createRepository().updateUserPreferences({'purpose': 'rent'}),
          throwsA(isA<NetworkException>()),
        );
      });
    });

    group('isProfileComplete', () {
      test('returns true when user has fullName and dateOfBirth', () {
        final user = UserModel.fromJson(selfUser());

        expect(createRepository().isProfileComplete(user), isTrue);
      });

      test('returns false when user lacks dateOfBirth', () {
        final user = UserModel.fromJson(selfUser(overrides: {'date_of_birth': null}));

        expect(createRepository().isProfileComplete(user), isFalse);
      });
    });

    group('updateUserLocation', () {
      test('PUTs latitude and longitude to the location endpoint', () async {
        when(
          () => mockApiClient.put(
            ApiPaths.usersLocation,
            body: {'latitude': 28.61, 'longitude': 77.20},
          ),
        ).thenAnswer((_) async => ok(apiFixture('users')['location']));

        await createRepository().updateUserLocation(latitude: 28.61, longitude: 77.20);

        verify(
          () => mockApiClient.put(
            ApiPaths.usersLocation,
            body: {'latitude': 28.61, 'longitude': 77.20},
          ),
        ).called(1);
      });

      test('skips a position outside the range the backend accepts', () async {
        final repo = createRepository();
        await repo.updateUserLocation(latitude: 91, longitude: 77.20);
        await repo.updateUserLocation(latitude: 28.61, longitude: -181);

        verifyNever(() => mockApiClient.put(ApiPaths.usersLocation, body: any(named: 'body')));
      });

      test('rethrows AppException from ApiClient', () async {
        when(
          () => mockApiClient.put(ApiPaths.usersLocation, body: any(named: 'body')),
        ).thenThrow(NetworkException('Offline'));

        expect(
          () => createRepository().updateUserLocation(latitude: 1.0, longitude: 2.0),
          throwsA(isA<NetworkException>()),
        );
      });

      test('rethrows unexpected exceptions', () async {
        when(
          () => mockApiClient.put(ApiPaths.usersLocation, body: any(named: 'body')),
        ).thenThrow(Exception('Broke'));

        expect(
          () => createRepository().updateUserLocation(latitude: 1.0, longitude: 2.0),
          throwsException,
        );
      });
    });

    group('updateProfileImage', () {
      test('uploads the file and returns the parsed user', () async {
        when(
          () => mockApiClient.upload(
            ApiPaths.usersAvatar,
            field: 'file',
            filePath: '/tmp/avatar.png',
          ),
        ).thenAnswer(
          (_) async => ok(selfUser(overrides: {'profile_image_url': 'https://img.com/a.png'})),
        );

        final user = await createRepository().updateProfileImage('/tmp/avatar.png');

        expect(user.profileImageUrl, 'https://img.com/a.png');
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

        expect(
          () => createRepository().updateProfileImage('/tmp/avatar.png'),
          throwsA(isA<NetworkException>()),
        );
      });

      test('rethrows unexpected exceptions', () async {
        when(
          () => mockApiClient.upload(
            ApiPaths.usersAvatar,
            field: any(named: 'field'),
            filePath: any(named: 'filePath'),
          ),
        ).thenThrow(Exception('Broke'));

        expect(() => createRepository().updateProfileImage('/tmp/avatar.png'), throwsException);
      });
    });
  });
}
