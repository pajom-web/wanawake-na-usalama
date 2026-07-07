class SafetyTip {
  const SafetyTip({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.isActive,
    required this.displayOrder,
    required this.publishedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String title;
  final String body;
  final String category;
  final bool isActive;
  final int displayOrder;
  final DateTime publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory SafetyTip.fromJson(Map<String, dynamic> json) {
    return SafetyTip(
      id: json['id'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
      category: json['category'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      displayOrder: json['display_order'] as int? ?? 0,
      publishedAt: DateTime.parse(json['published_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toWriteJson() {
    return {
      'title': title,
      'body': body,
      'category': category,
      'is_active': isActive,
      'display_order': displayOrder,
    };
  }
}
