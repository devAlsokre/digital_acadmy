class StudentGradeItemScore {
  const StudentGradeItemScore({
    required this.id,
    required this.gradeItemId,
    required this.studentId,
    required this.courseOfferingId,
    required this.courseCode,
    required this.courseNameAr,
    required this.courseNameEn,
    required this.teacherName,
    required this.semesterName,
    required this.itemName,
    required this.itemType,
    required this.score,
    required this.maxGrade,
    required this.weight,
    required this.feedback,
    required this.isItemPublished,
    required this.isScorePublished,
    required this.gradedAt,
  });

  final String id;
  final String gradeItemId;
  final String studentId;
  final String courseOfferingId;
  final String courseCode;
  final String courseNameAr;
  final String courseNameEn;
  final String? teacherName;
  final String? semesterName;
  final String itemName;
  final String? itemType;
  final num? score;
  final num? maxGrade;
  final num? weight;
  final String? feedback;
  final bool isItemPublished;
  final bool isScorePublished;
  final DateTime? gradedAt;

  String get displayCourseName {
    if (courseNameAr.trim().isNotEmpty) {
      return courseNameAr.trim();
    }

    if (courseNameEn.trim().isNotEmpty) {
      return courseNameEn.trim();
    }

    return courseCode.isEmpty ? 'Course' : courseCode;
  }

  factory StudentGradeItemScore.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? item = _asMap(json['grade_items']);
    final Map<String, dynamic>? offering = _asMap(item?['course_offerings']);
    final Map<String, dynamic>? course = _asMap(offering?['courses']);
    final Map<String, dynamic>? teacher = _asMap(offering?['teachers']);
    final Map<String, dynamic>? semester = _asMap(offering?['semesters']);

    return StudentGradeItemScore(
      id: _asString(json['id']),
      gradeItemId: _asString(json['grade_item_id']),
      studentId: _asString(json['student_id']),
      courseOfferingId: _asString(item?['course_offering_id']),
      courseCode: _asString(course?['code']),
      courseNameAr: _asString(course?['name_ar']),
      courseNameEn: _asString(course?['name_en']),
      teacherName: _localizedPersonName(teacher),
      semesterName: _semesterName(semester),
      itemName: _asString(item?['name']).isEmpty
          ? 'Grade item'
          : _asString(item?['name']),
      itemType: _nullableString(item?['item_type']),
      score: _asNum(json['score']),
      maxGrade: _asNum(item?['max_grade']),
      weight: _asNum(item?['weight']),
      feedback: _nullableString(json['feedback']),
      isItemPublished: _asBool(item?['is_published']),
      isScorePublished: _asBool(json['is_published']),
      gradedAt: _asDateTime(json['graded_at']),
    );
  }

  factory StudentGradeItemScore.fromParts({
    required Map<String, dynamic> score,
    required Map<String, dynamic>? item,
    required Map<String, dynamic>? course,
    required Map<String, dynamic>? teacher,
    required Map<String, dynamic>? semester,
  }) {
    return StudentGradeItemScore(
      id: _asString(score['id']),
      gradeItemId: _asString(score['grade_item_id']),
      studentId: _asString(score['student_id']),
      courseOfferingId: _asString(item?['course_offering_id']),
      courseCode: _asString(course?['code']),
      courseNameAr: _asString(course?['name_ar']),
      courseNameEn: _asString(course?['name_en']),
      teacherName: _localizedPersonName(teacher),
      semesterName: _semesterName(semester),
      itemName: _asString(item?['name']).isEmpty
          ? 'Grade item'
          : _asString(item?['name']),
      itemType: _nullableString(item?['item_type']),
      score: _asNum(score['score']),
      maxGrade: _asNum(item?['max_grade']),
      weight: _asNum(item?['weight']),
      feedback: _nullableString(score['feedback']),
      isItemPublished: _asBool(item?['is_published']),
      isScorePublished: _asBool(score['is_published']),
      gradedAt: _asDateTime(score['graded_at']),
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

  static num? _asNum(Object? value) {
    if (value is num) {
      return value;
    }

    return num.tryParse(value?.toString() ?? '');
  }

  static bool _asBool(Object? value) {
    if (value is bool) {
      return value;
    }

    return value?.toString().toLowerCase() == 'true';
  }

  static DateTime? _asDateTime(Object? value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString())?.toLocal();
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
