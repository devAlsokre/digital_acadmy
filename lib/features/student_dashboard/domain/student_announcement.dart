class StudentAnnouncement {
  const StudentAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    required this.priority,
    required this.publishAt,
    required this.expiresAt,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String? priority;
  final DateTime? publishAt;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  factory StudentAnnouncement.fromJson(Map<String, dynamic> json) {
    return StudentAnnouncement(
      id: _asString(json['id']),
      title: _asString(json['title']).isEmpty
          ? 'Announcement'
          : _asString(json['title']),
      body: _asString(json['body']),
      priority: _nullableString(json['priority']),
      publishAt: _asDateTime(json['publish_at']),
      expiresAt: _asDateTime(json['expires_at']),
      createdAt: _asDateTime(json['created_at']),
    );
  }

  bool get isActive {
    final DateTime now = DateTime.now();
    final bool published = publishAt == null || !now.isBefore(publishAt!);
    final bool notExpired = expiresAt == null || !now.isAfter(expiresAt!);

    return published && notExpired;
  }

  static String _asString(Object? value) => value?.toString().trim() ?? '';

  static String? _nullableString(Object? value) {
    final String stringValue = _asString(value);
    return stringValue.isEmpty ? null : stringValue;
  }

  static DateTime? _asDateTime(Object? value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString())?.toLocal();
  }
}
