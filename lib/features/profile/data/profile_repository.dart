import 'package:hopefulme_flutter/core/network/api_client.dart';
import 'package:hopefulme_flutter/features/auth/data/auth_repository.dart';
import 'package:hopefulme_flutter/core/storage/page_cache.dart';
import 'package:hopefulme_flutter/features/profile/models/profile_dashboard.dart';

class ProfileRepository {
  ProfileRepository(this._authRepository, {PageCache? cache})
    : _cache = cache ?? PageCache();

  final AuthRepository _authRepository;
  final PageCache _cache;

  Future<ProfileDashboard?> fetchCachedProfile(String username) async {
    final normalizedUsername = username.trim().replaceFirst('@', '');
    final key = 'profile:$normalizedUsername';
    final cached = await _cache.read(key);
    if (cached == null) {
      return null;
    }
    return ProfileDashboard.fromJson(cached);
  }

  Future<ProfileDashboard> fetchProfile(String username) async {
    final normalizedUsername = username.trim().replaceFirst('@', '');
    final key = 'profile:$normalizedUsername';
    try {
      final response = await _authRepository.get('profile/$normalizedUsername');
      await _cache.save(key, response);
      return ProfileDashboard.fromJson(response);
    } catch (error) {
      final cached = await _cache.read(key);
      if (cached != null) {
        return ProfileDashboard.fromJson(cached);
      }
      rethrow;
    }
  }

  Future<(bool isFollowing, int followersCount)> toggleFollow(
    String username,
  ) async {
    final response = await _authRepository.put('follow/$username');
    return (
      response['following'] as bool? ?? false,
      (response['followers_count'] as num?)?.toInt() ?? 0,
    );
  }

  Future<ProfileConnectionPage> fetchFollowers(
    String username, {
    int page = 1,
  }) async {
    final normalizedUsername = username.trim().replaceFirst('@', '');
    final key = 'profile:$normalizedUsername:followers:$page';
    try {
      final response = await _authRepository.get(
        'profile/$normalizedUsername/followers',
        queryParameters: {'page': page},
      );
      await _cache.save(key, response);
      return ProfileConnectionPage.fromJson(response);
    } catch (error) {
      final cached = await _cache.read(key);
      if (cached != null) {
        return ProfileConnectionPage.fromJson(cached);
      }
      rethrow;
    }
  }

  Future<ProfileConnectionPage> fetchFollowing(
    String username, {
    int page = 1,
  }) async {
    final normalizedUsername = username.trim().replaceFirst('@', '');
    final key = 'profile:$normalizedUsername:following:$page';
    try {
      final response = await _authRepository.get(
        'profile/$normalizedUsername/following',
        queryParameters: {'page': page},
      );
      await _cache.save(key, response);
      return ProfileConnectionPage.fromJson(response);
    } catch (error) {
      final cached = await _cache.read(key);
      if (cached != null) {
        return ProfileConnectionPage.fromJson(cached);
      }
      rethrow;
    }
  }

  Future<ProfileUpdatePage> fetchUserUpdates(
    String username, {
    int page = 1,
  }) async {
    final normalizedUsername = username.trim().replaceFirst('@', '');
    final key = 'profile:$normalizedUsername:updates:$page';
    try {
      final response = await _authRepository.get(
        'profile/$normalizedUsername/updates',
        queryParameters: {'page': page},
      );
      await _cache.save(key, response);
      return ProfileUpdatePage.fromJson(response);
    } catch (error) {
      final cached = await _cache.read(key);
      if (cached != null) {
        return ProfileUpdatePage.fromJson(cached);
      }
      rethrow;
    }
  }

  Future<ProfileUpdatePage> fetchUserBlogs(
    String username, {
    int page = 1,
  }) async {
    final normalizedUsername = username.trim().replaceFirst('@', '');
    final key = 'profile:$normalizedUsername:blogs:$page';
    try {
      final response = await _authRepository.get(
        'profile/$normalizedUsername/blogs',
        queryParameters: {'page': page},
      );
      await _cache.save(key, response);
      return ProfileUpdatePage.fromJson(response);
    } catch (error) {
      final cached = await _cache.read(key);
      if (cached != null) {
        return ProfileUpdatePage.fromJson(cached);
      }
      rethrow;
    }
  }

  Future<ProfileUpdatePage> fetchUserPhotos(
    String username, {
    int page = 1,
  }) async {
    final normalizedUsername = username.trim().replaceFirst('@', '');
    final key = 'profile:$normalizedUsername:photos:$page';
    try {
      final response = await _authRepository.get(
        'profile/$normalizedUsername/photos',
        queryParameters: {'page': page},
      );
      await _cache.save(key, response);
      return ProfileUpdatePage.fromJson(response);
    } catch (error) {
      final cached = await _cache.read(key);
      if (cached != null) {
        return ProfileUpdatePage.fromJson(cached);
      }
      rethrow;
    }
  }

  Future<void> sendInspiration({
    required String username,
    required String message,
    bool isAnonymous = false,
    bool isPublic = false,
    String? preset,
  }) async {
    await _authRepository.post(
      'inspire/send/$username',
      body: {
        'message': message,
        'is_anonymous': isAnonymous,
        'is_public': isPublic,
        if (preset != null && preset.isNotEmpty) 'preset': preset,
      },
    );
  }

  Future<List<String>> fetchInspirationPresets() async {
    final response = await _authRepository.get('inspire/presets/list');
    final items = response['data'] as List<dynamic>? ?? <dynamic>[];
    return items.map((item) => item.toString()).toList();
  }

  Future<ProfileSummary> updateProfilePhoto(ApiMultipartFile file) async {
    final response = await _authRepository.postMultipart(
      'profile/photo',
      files: [
        ApiMultipartFile(
          field: 'photo',
          filename: file.filename,
          bytes: file.bytes,
        ),
      ],
    );

    return ProfileSummary.fromJson(
      response['user'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  Future<ProfileSummary> updateCoverPhoto(ApiMultipartFile file) async {
    final response = await _authRepository.postMultipart(
      'profile/cover',
      files: [
        ApiMultipartFile(
          field: 'cover_photo',
          filename: file.filename,
          bytes: file.bytes,
        ),
      ],
    );

    return ProfileSummary.fromJson(
      response['user'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  Future<ProfileSummary> removeProfilePhoto() async {
    final response = await _authRepository.delete('profile/photo');
    return ProfileSummary.fromJson(
      response['user'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  Future<ProfileSummary> removeCoverPhoto() async {
    final response = await _authRepository.delete('profile/cover');
    return ProfileSummary.fromJson(
      response['user'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  Future<ProfileSummary> updateProfile({
    required String fullname,
    required String username,
    required String email,
    required String gender,
    required String quote,
    required String hobby,
    required String role1,
    required String role2,
    required String location,
    required String city,
    required String state,
    required String birthDay,
    required String birthMonth,
    required String phoneNumber,
    required bool emailNotifications,
    required String theme,
    String? password,
  }) async {
    final response = await _authRepository.put(
      'profile',
      body: {
        'fullname': fullname,
        'username': username,
        'email': email,
        'gender': gender,
        'quote': quote,
        'hobby': hobby,
        'role1': role1,
        'role2': role2,
        'location': location,
        'city': city,
        'state': state,
        'day': birthDay,
        'month': birthMonth,
        'phone_number': phoneNumber,
        'email_notifications': emailNotifications,
        'theme': theme,
        if (password != null && password.isNotEmpty) 'password': password,
        if (password != null && password.isNotEmpty)
          'password_confirmation': password,
      },
    );

    return ProfileSummary.fromJson(
      response['user'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  Future<ProfileEditOptions> fetchEditOptions() async {
    final response = await _authRepository.get('profile/edit/options');
    return ProfileEditOptions.fromJson(response);
  }

  Future<List<String>> fetchStatesForCountry(String country) async {
    if (country.trim().isEmpty) {
      return const <String>[];
    }

    final response = await _authRepository.get(
      'profile/edit/states',
      queryParameters: {'country': country},
    );

    return (response['states'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }

  Future<List<String>> getReportReasons() async {
    final response = await _authRepository.get('reports/reasons');
    List<dynamic> items = <dynamic>[];
    if (response['data'] != null) {
      items = response['data'] as List<dynamic>;
    } else if (response['reasons'] != null) {
      items = response['reasons'] as List<dynamic>;
    }
    return items.map((item) {
      if (item is Map<String, dynamic>) {
        return item['reason']?.toString() ?? item.toString();
      }
      return item.toString();
    }).toList();
  }

  Future<void> reportUser(String username, String reason) async {
    await _authRepository.post(
      'reports/user/$username',
      body: {'reason': reason},
    );
  }
}
