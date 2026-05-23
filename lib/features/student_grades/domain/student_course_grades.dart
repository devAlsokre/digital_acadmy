import 'student_grade_item_score.dart';

class StudentCourseGrades {
  const StudentCourseGrades({
    required this.courseOfferingId,
    required this.courseCode,
    required this.courseNameAr,
    required this.courseNameEn,
    required this.teacherName,
    required this.semesterName,
    required this.items,
  });

  final String courseOfferingId;
  final String courseCode;
  final String courseNameAr;
  final String courseNameEn;
  final String? teacherName;
  final String? semesterName;
  final List<StudentGradeItemScore> items;

  num get totalScore {
    return items.fold<num>(
      0,
      (total, item) => item.score == null ? total : total + item.score!,
    );
  }

  num get totalMaxGrade {
    return items.fold<num>(
      0,
      (total, item) => item.maxGrade == null ? total : total + item.maxGrade!,
    );
  }

  String get displayCourseName {
    if (courseNameAr.trim().isNotEmpty) {
      return courseNameAr.trim();
    }

    if (courseNameEn.trim().isNotEmpty) {
      return courseNameEn.trim();
    }

    return courseCode.isEmpty ? 'Course' : courseCode;
  }

  factory StudentCourseGrades.fromItems(List<StudentGradeItemScore> items) {
    final StudentGradeItemScore firstItem = items.first;

    return StudentCourseGrades(
      courseOfferingId: firstItem.courseOfferingId,
      courseCode: firstItem.courseCode,
      courseNameAr: firstItem.courseNameAr,
      courseNameEn: firstItem.courseNameEn,
      teacherName: firstItem.teacherName,
      semesterName: firstItem.semesterName,
      items: items,
    );
  }
}
