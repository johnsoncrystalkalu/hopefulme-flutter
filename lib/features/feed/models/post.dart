class Post {
  const Post({required this.id, required this.title, required this.body});

  final int id;
  final String title;
  final String body;

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as int? ?? 0,
      title: json['title']?.toString() ??
          json['user']?['fullname']?.toString() ??
          json['type']?.toString() ??
          'Untitled',
      body: json['body']?.toString() ??
          json['content']?.toString() ??
          json['status']?.toString() ??
          '',
    );
  }
}
