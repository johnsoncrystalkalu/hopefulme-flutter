class FeedItem {
  const FeedItem({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
  });

  final String id;
  final String title;
  final String body;
  final String category;

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    return FeedItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled post',
      body: json['body']?.toString() ?? json['content']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Update',
    );
  }
}
