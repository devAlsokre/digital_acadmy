class StudentNotification {
  const StudentNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.relatedTable,
    required this.relatedId,
    required this.createdAt,
    required this.readAt,
  });

  final String id;
  final String title;
  final String body;
  final String? type;
  final String? relatedTable;
  final String? relatedId;
  final DateTime? createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  StudentNotification copyWith({
    DateTime? readAt,
  }) {
    return StudentNotification(
      id: id,
      title: title,
      body: body,
      type: type,
      relatedTable: relatedTable,
      relatedId: relatedId,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
    );
  }

  factory StudentNotification.fromJson(
    Map<String, dynamic> json, {
    DateTime? readAt,
  }) {
    final String title = _asString(json['title']);
    final String body = _asString(json['body']);

    return StudentNotification(
      id: _asString(json['id']),
      title: title.isEmpty ? 'Notification' : title,
      body: body,
      type: _nullableString(json['type']),
      relatedTable: _nullableString(json['related_table']),
      relatedId: _nullableString(json['related_id']),
      createdAt: _asDateTime(json['created_at']),
      readAt: readAt,
    );
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
