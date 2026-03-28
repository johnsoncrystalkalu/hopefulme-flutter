import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';

class User {
  const User({
    required this.id,
    required this.fullname,
    required this.username,
    required this.email,
    required this.gender,
    required this.photoUrl,
    required this.theme,
  });

  final int id;
  final String fullname;
  final String username;
  final String email;
  final String gender;
  final String photoUrl;
  final String theme;

  String get displayName => fullname.isNotEmpty ? fullname : username;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int? ?? 0,
      fullname: json['fullname']?.toString() ??
          json['name']?.toString() ??
          'Unknown User',
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
      photoUrl: ImageUrlResolver.resolve(json['photo_url']?.toString() ?? ''),
      theme: json['theme']?.toString() ?? '',
    );
  }
}
