import 'package:hopefulme_flutter/core/network/api_client.dart';
import 'package:hopefulme_flutter/features/auth/data/auth_repository.dart';
import 'package:hopefulme_flutter/features/profile/models/profile_dashboard.dart';

class ProfileRepository {
  ProfileRepository(this._authRepository);

  final AuthRepository _authRepository;

  Future<ProfileDashboard> fetchProfile(String username) async {
    final response = await _authRepository.get('profile/$username');
    return ProfileDashboard.fromJson(response);
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
    final response = await _authRepository.get(
      'profile/$username/followers',
      queryParameters: {'page': page},
    );
    return ProfileConnectionPage.fromJson(response);
  }

  Future<ProfileConnectionPage> fetchFollowing(
    String username, {
    int page = 1,
  }) async {
    final response = await _authRepository.get(
      'profile/$username/following',
      queryParameters: {'page': page},
    );
    return ProfileConnectionPage.fromJson(response);
  }

  Future<ProfileUpdatePage> fetchUserUpdates(
    String username, {
    int page = 1,
  }) async {
    final response = await _authRepository.get(
      'profile/$username/updates',
      queryParameters: {'page': page},
    );
    return ProfileUpdatePage.fromJson(response);
  }

  Future<ProfileUpdatePage> fetchUserBlogs(
    String username, {
    int page = 1,
  }) async {
    final response = await _authRepository.get(
      'profile/$username/blogs',
      queryParameters: {'page': page},
    );
    return ProfileUpdatePage.fromJson(response);
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
    required String location,
    required String city,
    required String state,
    required String phoneNumber,
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
        'location': location,
        'city': city,
        'state': state,
        'phone_number': phoneNumber,
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
}
