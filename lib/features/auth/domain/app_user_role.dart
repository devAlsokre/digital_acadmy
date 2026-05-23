enum AppUserRole {
  admin,
  collegeAdmin,
  teacher,
  student,
  unknown;

  factory AppUserRole.fromValue(Object? value) {
    final String normalized = value?.toString().trim().toLowerCase() ?? '';

    return switch (normalized) {
      'admin' => AppUserRole.admin,
      'college_admin' => AppUserRole.collegeAdmin,
      'teacher' => AppUserRole.teacher,
      'student' => AppUserRole.student,
      _ => AppUserRole.unknown,
    };
  }
}
