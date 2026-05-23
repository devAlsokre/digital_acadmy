class StudentAssignment {
  const StudentAssignment({
    required this.id,
    required this.courseOfferingId,
    required this.courseCode,
    required this.courseName,
    required this.lectureNumber,
    required this.lectureTitle,
    required this.title,
    required this.description,
    required this.instructions,
    required this.attachmentUrl,
    required this.startAt,
    required this.dueAt,
    required this.allowLateSubmission,
    required this.maxGrade,
    required this.status,
    required this.submissionId,
    required this.submissionFilePath,
    required this.answerText,
    required this.submissionStatus,
    required this.submittedAt,
    required this.grade,
    required this.feedback,
  });

  final String id;
  final String courseOfferingId;
  final String courseCode;
  final String courseName;
  final int? lectureNumber;
  final String? lectureTitle;
  final String title;
  final String? description;
  final String? instructions;
  final String? attachmentUrl;
  final DateTime? startAt;
  final DateTime? dueAt;
  final bool allowLateSubmission;
  final num? maxGrade;
  final String status;
  final String? submissionId;
  final String? submissionFilePath;
  final String? answerText;
  final String? submissionStatus;
  final DateTime? submittedAt;
  final num? grade;
  final String? feedback;

  bool get isSubmitted => submittedAt != null || submissionStatus != null;

  bool get isExpired {
    final DateTime? deadline = dueAt;
    return deadline != null && DateTime.now().isAfter(deadline);
  }

  bool get isNotStarted {
    final DateTime? start = startAt;
    return start != null && DateTime.now().isBefore(start);
  }

  bool get isClosedForSubmission {
    return status.toLowerCase() != 'published' ||
        isNotStarted ||
        (isExpired && !allowLateSubmission);
  }

  bool get isOpen {
    final DateTime now = DateTime.now();
    final bool startsOk = startAt == null || !now.isBefore(startAt!);
    final bool dueOk =
        allowLateSubmission || dueAt == null || !now.isAfter(dueAt!);

    return status.toLowerCase() == 'published' && startsOk && dueOk;
  }

  String get displayState {
    if (isSubmitted) {
      return 'Submitted';
    }

    if (isNotStarted) {
      return 'Not Started';
    }

    return isOpen ? 'Open' : 'Closed';
  }

  factory StudentAssignment.fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic>? submission,
  }) {
    final Map<String, dynamic>? lecture = _asMap(json['lectures']);
    final Map<String, dynamic>? offering = _asMap(json['course_offerings']);
    final Map<String, dynamic>? course = _asMap(offering?['courses']);

    return StudentAssignment(
      id: _asString(json['id']),
      courseOfferingId: _asString(json['course_offering_id']),
      courseCode: _asString(course?['code']),
      courseName: _courseName(course, json['course_offering_id']),
      lectureNumber: _asInt(lecture?['lecture_number']),
      lectureTitle: _nullableString(lecture?['title']),
      title: _asString(json['title']).isEmpty
          ? 'Untitled assignment'
          : _asString(json['title']),
      description: _nullableString(json['description']),
      instructions: _nullableString(json['instructions']),
      attachmentUrl: _nullableString(json['attachment_url']),
      startAt: _asDateTime(json['start_at']),
      dueAt: _asDateTime(json['due_at']),
      allowLateSubmission: _asBool(json['allow_late_submission']),
      maxGrade: _asNum(json['max_grade']),
      status: _asString(json['status']).isEmpty
          ? 'published'
          : _asString(json['status']),
      submissionId: _nullableString(submission?['id']),
      submissionFilePath: _nullableString(submission?['file_path']),
      answerText: _nullableString(submission?['answer_text']),
      submissionStatus: _nullableString(submission?['status']),
      submittedAt: _asDateTime(submission?['submitted_at']),
      grade: _asNum(submission?['grade']),
      feedback: _nullableString(submission?['feedback']),
    );
  }

  factory StudentAssignment.fromParts({
    required Map<String, dynamic> assignment,
    required Map<String, dynamic>? course,
    required Map<String, dynamic>? lecture,
    required Map<String, dynamic>? submission,
  }) {
    return StudentAssignment(
      id: _asString(assignment['id']),
      courseOfferingId: _asString(assignment['course_offering_id']),
      courseCode: _asString(course?['code']),
      courseName: _courseName(course, assignment['course_offering_id']),
      lectureNumber: _asInt(lecture?['lecture_number']),
      lectureTitle: _nullableString(lecture?['title']),
      title: _asString(assignment['title']).isEmpty
          ? 'Untitled assignment'
          : _asString(assignment['title']),
      description: _nullableString(assignment['description']),
      instructions: _nullableString(assignment['instructions']),
      attachmentUrl: _nullableString(assignment['attachment_url']),
      startAt: _asDateTime(assignment['start_at']),
      dueAt: _asDateTime(assignment['due_at']),
      allowLateSubmission: _asBool(assignment['allow_late_submission']),
      maxGrade: _asNum(assignment['max_grade']),
      status: _asString(assignment['status']).isEmpty
          ? 'published'
          : _asString(assignment['status']),
      submissionId: _nullableString(submission?['id']),
      submissionFilePath: _nullableString(submission?['file_path']),
      answerText: _nullableString(submission?['answer_text']),
      submissionStatus: _nullableString(submission?['status']),
      submittedAt: _asDateTime(submission?['submitted_at']),
      grade: _asNum(submission?['grade']),
      feedback: _nullableString(submission?['feedback']),
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
}
