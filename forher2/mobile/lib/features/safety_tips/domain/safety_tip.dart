class SafetyTip {
  const SafetyTip({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.publishedAt,
    required this.updatedAt,
  });

  final int? id;
  final String title;
  final String body;
  final String category;
  final DateTime? publishedAt;
  final DateTime? updatedAt;

  factory SafetyTip.fromJson(Map<String, dynamic> json) {
    return SafetyTip(
      id: json['id'] is int ? json['id'] as int : null,
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      publishedAt: json['published_at'] is String
          ? DateTime.tryParse(json['published_at'] as String)
          : null,
      updatedAt: json['updated_at'] is String
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }
}
