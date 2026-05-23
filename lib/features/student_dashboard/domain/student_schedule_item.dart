class StudentScheduleItem {
  const StudentScheduleItem({
    required this.id,
    required this.courseOfferingId,
    required this.courseCode,
    required this.courseName,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.room,
    required this.location,
    required this.scheduleType,
  });

  final String id;
  final String courseOfferingId;
  final String courseCode;
  final String courseName;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final String? room;
  final String? location;
  final String? scheduleType;

  factory StudentScheduleItem.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? offering = _asMap(json['course_offerings']);
    final Map<String, dynamic>? course = _asMap(offering?['courses']);

    return StudentScheduleItem(
      id: _asString(json['id']),
      courseOfferingId: _asString(json['course_offering_id']),
      courseCode: _asString(course?['code']),
      courseName: _courseName(course, json['course_offering_id']),
      dayOfWeek: _asInt(json['day_of_week']) ?? 0,
      startTime: _asString(json['start_time']),
      endTime: _asString(json['end_time']),
      room: _nullableString(json['room']),
      location: _nullableString(json['location']),
      scheduleType: _nullableString(json['schedule_type']),
    );
  }

  factory StudentScheduleItem.fromParts({
    required Map<String, dynamic> schedule,
    required Map<String, dynamic>? course,
  }) {
    return StudentScheduleItem(
      id: _asString(schedule['id']),
      courseOfferingId: _asString(schedule['course_offering_id']),
      courseCode: _asString(course?['code']),
      courseName: _courseName(course, schedule['course_offering_id']),
      dayOfWeek: _asInt(schedule['day_of_week']) ?? 0,
      startTime: _asString(schedule['start_time']),
      endTime: _asString(schedule['end_time']),
      room: _nullableString(schedule['room']),
      location: _nullableString(schedule['location']),
      scheduleType: _nullableString(schedule['schedule_type']),
    );
  }

  static String _courseName(Map<String, dynamic>? course, Object? fallback) {
    final String nameAr = _asString(course?['name_ar']);
    final String nameEn = _asString(course?['name_en']);
    final String code = _asString(course?['code']);

    if (nameAr.isNotEmpty) {
      return nameAr;
    }

    if (nameEn.isNotEmpty) {
      return nameEn;
    }

    return code.isEmpty ? _asString(fallback) : code;
  }

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    if (value is List && value.isNotEmpty) {
      return _asMap(value.first);
    }

    return null;
  }

  static String _asString(Object? value) => value?.toString().trim() ?? '';

  static String? _nullableString(Object? value) {
    final String stringValue = _asString(value);
    return stringValue.isEmpty ? null : stringValue;
  }

  static int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }
}
