import 'student_announcement.dart';
import 'student_assignment.dart';
import 'student_course.dart';
import 'student_schedule_item.dart';

class StudentDashboardData {
  const StudentDashboardData({
    required this.courses,
    required this.scheduleItems,
    required this.openAssignments,
    required this.announcements,
  });

  final List<StudentCourse> courses;
  final List<StudentScheduleItem> scheduleItems;
  final List<StudentAssignment> openAssignments;
  final List<StudentAnnouncement> announcements;

  List<StudentScheduleItem> get todaysSchedule {
    final int today = DateTime.now().weekday;

    return scheduleItems.where((item) => item.dayOfWeek == today).toList();
  }
}
