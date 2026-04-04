import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
import 'package:hopefulme_flutter/core/utils/json_parsing.dart';

class ProfileDashboard {
  const ProfileDashboard({
    required this.profile,
    required this.posts,
    required this.updates,
    required this.blogs,
    required this.isFollowing,
    required this.totalPosts,
    required this.updatesCount,
    required this.photosCount,
    required this.mutualFollowers,
  });

  final ProfileSummary profile;
  final List<ProfileContentItem> posts;
  final List<ProfileContentItem> updates;
  final List<ProfileContentItem> blogs;
  final bool isFollowing;
  final int totalPosts;
  final int updatesCount;
  final int photosCount;
  final List<ProfileMutualFollower> mutualFollowers;

  factory ProfileDashboard.fromJson(Map<String, dynamic> json) {
    final profile = ProfileSummary.fromJson(
      json['profile'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );

    return ProfileDashboard(
      profile: profile,
      posts: _mapItems(json['posts']),
      updates: _mapItems(json['updates']),
      blogs: _mapItems(json['blogs']),
      isFollowing: json['is_following'] as bool? ?? false,
      totalPosts: parseInt(json['total_posts']),
      updatesCount: parseInt(json['updates_count']),
      photosCount: parseInt(json['photos_count']),
      mutualFollowers: (json['mutual_followers'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(ProfileMutualFollower.fromJson)
          .toList(),
    );
  }

  static List<ProfileContentItem> _mapItems(dynamic value) {
    final items = value as List<dynamic>? ?? <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map((item) => ProfileContentItem.fromJson(item))
        .toList();
  }
}

class ProfileConnectionPage {
  const ProfileConnectionPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<ProfileConnectionUser> items;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;

  factory ProfileConnectionPage.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as List<dynamic>? ?? <dynamic>[];
    final meta = json['meta'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return ProfileConnectionPage(
      items: data
          .whereType<Map<String, dynamic>>()
          .map(ProfileConnectionUser.fromJson)
          .toList(),
      currentPage: parseInt(meta['current_page'], fallback: 1),
      lastPage: parseInt(meta['last_page'], fallback: 1),
      total: parseInt(meta['total']),
    );
  }
}

class ProfileConnectionUser {
  const ProfileConnectionUser({
    required this.id,
    required this.username,
    required this.fullname,
    required this.photoUrl,
    required this.lastSeen,
    required this.isOnline,
    required this.isVerified,
  });

  final int id;
  final String username;
  final String fullname;
  final String photoUrl;
  final String lastSeen;
  final bool isOnline;
  final bool isVerified;

  String get displayName => fullname.isNotEmpty ? fullname : username;

  factory ProfileConnectionUser.fromJson(Map<String, dynamic> json) {
    return ProfileConnectionUser(
      id: parseInt(json['id']),
      username: json['username']?.toString() ?? '',
      fullname: json['fullname']?.toString() ?? '',
      photoUrl: ImageUrlResolver.resolve(json['photo_url']?.toString() ?? ''),
      lastSeen: json['last_seen']?.toString() ?? '',
      isOnline: parseBool(json['is_online']),
      isVerified: parseBool(json['verified']),
    );
  }
}

class ProfileSummary {
  const ProfileSummary({
    required this.id,
    required this.username,
    required this.fullname,
    required this.email,
    required this.gender,
    required this.quote,
    required this.hobby,
    required this.role1,
    required this.role2,
    required this.location,
    required this.city,
    required this.state,
    required this.birthday,
    required this.phoneNumber,
    required this.theme,
    required this.device,
    required this.verified,
    required this.photoUrl,
    required this.coverUrl,
    required this.followersCount,
    required this.followingCount,
    required this.views,
    required this.lastSeen,
    required this.isOnline,
    required this.activityLevel,
  });

  final int id;
  final String username;
  final String fullname;
  final String email;
  final String gender;
  final String quote;
  final String hobby;
  final String role1;
  final String role2;
  final String location;
  final String city;
  final String state;
  final String birthday;
  final String phoneNumber;
  final String theme;
  final String device;
  final String verified;
  final String photoUrl;
  final String coverUrl;
  final int followersCount;
  final int followingCount;
  final int views;
  final String lastSeen;
  final bool isOnline;
  final ProfileActivityLevel activityLevel;

  String get displayName => fullname.isNotEmpty ? fullname : username;

  String get locationLabel {
    final parts = <String>[
      location,
      state,
    ].where((part) => part.trim().isNotEmpty).toList();
    return parts.join(', ');
  }

  bool get isVerified => verified.toLowerCase() == 'yes';

  factory ProfileSummary.fromJson(Map<String, dynamic> json) {
    return ProfileSummary(
      id: parseInt(json['id']),
      username: json['username']?.toString() ?? '',
      fullname: json['fullname']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
      quote: _plainText(json['quote']?.toString() ?? ''),
      hobby: json['hobby']?.toString() ?? '',
      role1: json['role1']?.toString() ?? '',
      role2: json['role2']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      birthday: json['bdae']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString() ?? '',
      theme: json['theme']?.toString() ?? '',
      device: json['device']?.toString() ?? '',
      verified: json['verified']?.toString() ?? '',
      photoUrl: ImageUrlResolver.resolve(json['photo_url']?.toString() ?? ''),
      coverUrl: ImageUrlResolver.resolve(json['cover_url']?.toString() ?? ''),
      followersCount: parseInt(json['followers_count']),
      followingCount: parseInt(json['following_count']),
      views: parseInt(json['views']),
      lastSeen: json['last_seen']?.toString() ?? '',
      isOnline: parseBool(json['is_online']),
      activityLevel: ProfileActivityLevel.fromJson(
        json['activity_level'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
    );
  }
}

class ProfileActivityLevel {
  const ProfileActivityLevel({
    required this.name,
    required this.color,
    required this.icon,
    required this.percent,
    required this.points,
  });

  final String name;
  final String color;
  final String icon;
  final double percent;
  final int points;

  factory ProfileActivityLevel.fromJson(Map<String, dynamic> json) {
    return ProfileActivityLevel(
      name: json['name']?.toString() ?? '',
      color: json['color']?.toString() ?? '#94a3b8',
      icon: json['icon']?.toString() ?? '⭐',
      percent: (json['percent'] as num?)?.toDouble() ?? 0,
      points: parseInt(json['points']),
    );
  }
}

class ProfileMutualFollower {
  const ProfileMutualFollower({
    required this.id,
    required this.username,
    required this.fullname,
    required this.photoUrl,
    required this.isVerified,
  });

  final int id;
  final String username;
  final String fullname;
  final String photoUrl;
  final bool isVerified;

  String get displayName => fullname.isNotEmpty ? fullname : username;

  factory ProfileMutualFollower.fromJson(Map<String, dynamic> json) {
    return ProfileMutualFollower(
      id: parseInt(json['id']),
      username: json['username']?.toString() ?? '',
      fullname: json['fullname']?.toString() ?? '',
      photoUrl: ImageUrlResolver.resolve(json['photo_url']?.toString() ?? ''),
      isVerified: parseBool(json['verified']),
    );
  }
}

class ProfileEditOptions {
  const ProfileEditOptions({required this.roles, required this.countries});

  final List<String> roles;
  final List<String> countries;

  factory ProfileEditOptions.fromJson(Map<String, dynamic> json) {
    return ProfileEditOptions(
      roles: (json['roles'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
      countries: (json['countries'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString())
          .where((item) => item.trim().isNotEmpty)
          .toList(),
    );
  }
}

class ProfileContentItem {
  const ProfileContentItem({
    required this.id,
    required this.type,
    required this.updateType,
    required this.title,
    required this.body,
    required this.photoUrl,
    required this.device,
    required this.likesCount,
    required this.commentsCount,
    required this.views,
    required this.createdAt,
  });

  final int id;
  final String type;
  final String updateType;
  final String title;
  final String body;
  final String photoUrl;
  final String device;
  final int likesCount;
  final int commentsCount;
  final int views;
  final String createdAt;

  factory ProfileContentItem.fromJson(Map<String, dynamic> json) {
    return ProfileContentItem(
      id: parseInt(json['id']),
      type: json['type']?.toString() ?? 'update',
      updateType: json['update_type']?.toString() ?? '',
      title: _plainText(json['title']?.toString() ?? ''),
      body: _plainText(
        json['content']?.toString() ?? json['status']?.toString() ?? '',
      ),
      photoUrl: ImageUrlResolver.resolve(json['photo_url']?.toString() ?? ''),
      device: json['device']?.toString() ?? '',
      likesCount: parseInt(json['likes_count']),
      commentsCount: parseInt(json['comments_count']),
      views: parseInt(json['views']),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class ProfileUpdatePage {
  const ProfileUpdatePage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<ProfileContentItem> items;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;

  factory ProfileUpdatePage.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as List<dynamic>? ?? <dynamic>[];
    final meta = json['meta'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return ProfileUpdatePage(
      items: data
          .whereType<Map<String, dynamic>>()
          .map((item) => ProfileContentItem.fromJson(item))
          .toList(),
      currentPage: parseInt(meta['current_page'], fallback: 1),
      lastPage: parseInt(meta['last_page'], fallback: 1),
      total: parseInt(meta['total']),
    );
  }
}

String _plainText(String input) {
  return input
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
