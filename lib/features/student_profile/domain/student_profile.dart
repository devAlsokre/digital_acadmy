class StudentProfile {
  const StudentProfile({
    required this.id,
    required this.universityNumber,
    required this.email,
    required this.fullNameAr,
    required this.fullNameEn,
    required this.phone,
    required this.gender,
    required this.status,
    required this.collegeName,
    required this.departmentName,
    required this.majorName,
    required this.batchName,
    required this.sectionName,
    required this.levelNumber,
    required this.collegeId,
    required this.departmentId,
    required this.majorId,
    required this.batchId,
    required this.sectionId,
    required this.levelId,
  });

  final String id;
  final String universityNumber;
  final String email;
  final String fullNameAr;
  final String? fullNameEn;
  final String? phone;
  final String? gender;
  final String status;
  final String? collegeName;
  final String? departmentName;
  final String? majorName;
  final String? batchName;
  final String? sectionName;
  final int? levelNumber;
  final String? collegeId;
  final String? departmentId;
  final String? majorId;
  final String? batchId;
  final String? sectionId;
  final String? levelId;

  String get displayName {
    if (fullNameEn != null && fullNameEn!.trim().isNotEmpty) {
      return fullNameEn!.trim();
    }

    if (fullNameAr.trim().isNotEmpty) {
      return fullNameAr.trim();
    }

    return email;
  }

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? college = _asMap(json['colleges']);
    final Map<String, dynamic>? department = _asMap(json['departments']);
    final Map<String, dynamic>? major = _asMap(json['majors']);
    final Map<String, dynamic>? batch = _asMap(json['batches']);
    final Map<String, dynamic>? section = _asMap(json['sections']);
    final Map<String, dynamic>? level = _asMap(json['academic_levels']);

    final String email = _asString(json['email']);
    final String fullNameEn = _asString(json['full_name_en']);
    final String fullNameAr = _asString(json['full_name_ar']);

    return StudentProfile(
      id: _asString(json['id']),
      universityNumber: _asString(json['university_number']),
      email: email,
      fullNameAr: fullNameAr.isNotEmpty ? fullNameAr : fullNameEn,
      fullNameEn: fullNameEn.isEmpty ? null : fullNameEn,
      phone: _nullableString(json['phone']),
      gender: _nullableString(json['gender']),
      status: _asString(json['status']).isEmpty
          ? 'unknown'
          : _asString(json['status']),
      collegeName: _localizedName(college),
      departmentName: _localizedName(department),
      majorName: _localizedName(major),
      batchName: _nullableString(batch?['name']),
      sectionName: _sectionName(section),
      levelNumber: _asInt(level?['level_number']),
      collegeId: _nullableString(json['college_id']),
      departmentId: _nullableString(json['department_id']),
      majorId: _nullableString(json['major_id']),
      batchId: _nullableString(json['batch_id']),
      sectionId: _nullableString(json['section_id']),
      levelId: _nullableString(json['level_id']),
    );
  }

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value == null) {
      return null;
    }

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

  static String _asString(Object? value) {
    return value?.toString().trim() ?? '';
  }

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

  static String? _localizedName(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }

    return _nullableString(json['name_en']) ??
        _nullableString(json['name_ar']) ??
        _nullableString(json['name']);
  }

  static String? _sectionName(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }

    final String? name = _nullableString(json['name']);
    final String? code = _nullableString(json['code']);

    if (name == null) {
      return code;
    }

    if (code == null || name.contains(code)) {
      return name;
    }

    return '$name ($code)';
  }
}
