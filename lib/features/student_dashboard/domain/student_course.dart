class StudentCourse {
  const StudentCourse({
    required this.id,
    required this.courseOfferingId,
    required this.courseCode,
    required this.courseNameAr,
    required this.courseNameEn,
    required this.teacherName,
    required this.semesterName,
    required this.status,
  });

  final String id;
  final String courseOfferingId;
  final String courseCode;
  final String courseNameAr;
  final String courseNameEn;
  final String? teacherName;
  final String? semesterName;
  final String status;

  String get displayName {
    if (courseNameAr.trim().isNotEmpty) {
      return courseNameAr.trim();
    }

    if (courseNameEn.trim().isNotEmpty) {
      return courseNameEn.trim();
    }

    return courseCode;
  }

  factory StudentCourse.fromEnrollmentJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? offering = _asMap(json['course_offerings']);
    final Map<String, dynamic>? course = _asMap(offering?['courses']);
    final Map<String, dynamic>? teacher = _asMap(offering?['teachers']);
    final Map<String, dynamic>? semester = _asMap(offering?['semesters']);

    return StudentCourse(
      id: _asString(json['id']).isEmpty
          ? '${_asString(json['course_offering_id'])}-${_asString(json['student_id'])}'
          : _asString(json['id']),
      courseOfferingId: _asString(json['course_offering_id']).isNotEmpty
          ? _asString(json['course_offering_id'])
          : _asString(offering?['id']),
      courseCode: _asString(course?['code']),
      courseNameAr: _asString(course?['name_ar']),
      courseNameEn: _asString(course?['name_en']),
      teacherName: _localizedPersonName(teacher),
      semesterName: _semesterName(semester),
      status: _asString(json['status']).isEmpty
          ? 'enrolled'
          : _asString(json['status']),
    );
  }

  factory StudentCourse.fromParts({
    required Map<String, dynamic> enrollment,
    required Map<String, dynamic>? offering,
    required Map<String, dynamic>? course,
    required Map<String, dynamic>? teacher,
    required Map<String, dynamic>? semester,
  }) {
    return StudentCourse(
      id: _asString(enrollment['id']).isEmpty
          ? '${_asString(enrollment['course_offering_id'])}-${_asString(enrollment['student_id'])}'
          : _asString(enrollment['id']),
      courseOfferingId: _asString(enrollment['course_offering_id']),
      courseCode: _asString(course?['code']),
      courseNameAr: _asString(course?['name_ar']),
      courseNameEn: _asString(course?['name_en']),
      teacherName: _localizedPersonName(teacher),
      semesterName: _semesterName(semester),
      status: _asString(enrollment['status']).isEmpty
          ? 'enrolled'
          : _asString(enrollment['status']),
    );
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

  static String? _localizedPersonName(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }

    return _nullableString(json['full_name_ar']) ??
        _nullableString(json['full_name_en']) ??
        _nullableString(json['name_ar']) ??
        _nullableString(json['name_en']);
  }

  static String? _semesterName(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }

    final String? name = _nullableString(json['name_ar']) ??
        _nullableString(json['name_en']) ??
        _nullableString(json['name']);
    final String? year = _nullableString(json['academic_year']);

    if (name == null) {
      return year;
    }

    if (year == null || name.contains(year)) {
      return name;
    }

    return '$name - $year';
  }
}
