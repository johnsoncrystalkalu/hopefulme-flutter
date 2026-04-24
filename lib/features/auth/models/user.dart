import 'package:hopefulme_flutter/core/network/image_url_resolver.dart';
import 'package:hopefulme_flutter/core/utils/json_parsing.dart';

class User {
  const User({
    required this.id,
    required this.fullname,
    required this.username,
    required this.email,
    required this.gender,
    this.rank = '',
    required this.role1,
    required this.photoUrl,
    required this.theme,
    required this.isVerified,
    required this.isAdmin,
    this.card = '',
  });

  final int id;
  final String fullname;
  final String username;
  final String email;
  final String gender;
  final String rank;
  final String role1;
  final String photoUrl;
  final String theme;
  final bool isVerified;
  final bool isAdmin;
  final String card;

  bool get hasCardEnabled => card.trim().toUpperCase() == 'YES';

  String get displayName => fullname.isNotEmpty ? fullname : username;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int? ?? 0,
      fullname:
          json['fullname']?.toString() ??
          json['name']?.toString() ??
          'Unknown User',
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
      rank: json['rank']?.toString() ?? '',
      role1: json['role1']?.toString() ?? '',
      photoUrl: ImageUrlResolver.resolve(json['photo_url']?.toString() ?? ''),
      theme: json['theme']?.toString() ?? '',
      isVerified: parseBool(json['verified']),
      isAdmin:
          json['is_admin'] == true ||
          json['isAdmin'] == true ||
          json['user_type']?.toString().toLowerCase() == 'admin' ||
          json['role']?.toString().toLowerCase() == 'admin' ||
          json['role1']?.toString().toLowerCase() == 'admin',
      card: json['card']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'fullname': fullname,
      'username': username,
      'email': email,
      'gender': gender,
      'rank': rank,
      'role1': role1,
      'photo_url': photoUrl,
      'theme': theme,
      'verified': isVerified,
      'is_admin': isAdmin,
      'card': card,
    };
  }
}
