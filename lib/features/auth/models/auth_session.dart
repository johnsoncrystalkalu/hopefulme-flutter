class AuthSession {
  const AuthSession({
    required this.token,
    required this.userName,
    required this.userEmail,
  });

  final String token;
  final String? userName;
  final String? userEmail;
}
