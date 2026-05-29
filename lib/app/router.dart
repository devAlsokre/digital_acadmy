import 'package:go_router/go_router.dart';

import '../features/account_activation/presentation/screens/activate_account_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/splash/presentation/screens/splash_screen.dart';
import '../features/student_dashboard/presentation/screens/student_announcements_screen.dart';
import '../features/student_dashboard/presentation/screens/student_assignment_details_screen.dart';
import '../features/student_dashboard/presentation/screens/student_assignments_screen.dart';
import '../features/student_dashboard/presentation/screens/student_courses_screen.dart';
import '../features/student_dashboard/presentation/screens/student_schedule_screen.dart';
import '../features/student_grades/presentation/screens/student_grades_screen.dart';
import '../features/student_home/presentation/screens/student_home_screen.dart';
import '../features/student_notifications/presentation/screens/student_notifications_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: <RouteBase>[
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) {
        final Object? extra = state.extra;
        return LoginScreen(message: extra is String ? extra : null);
      },
    ),
    GoRoute(
      path: AppRoutes.activateAccount,
      builder: (context, state) => const ActivateAccountScreen(),
    ),
    GoRoute(
      path: AppRoutes.studentHome,
      builder: (context, state) => const StudentHomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.studentCourses,
      builder: (context, state) => const StudentCoursesScreen(),
    ),
    GoRoute(
      path: AppRoutes.studentSchedule,
      builder: (context, state) => const StudentScheduleScreen(),
    ),
    GoRoute(
      path: AppRoutes.studentAssignments,
      builder: (context, state) => const StudentAssignmentsScreen(),
    ),
    GoRoute(
      path: '${AppRoutes.studentAssignments}/:assignmentId',
      builder: (context, state) {
        final String assignmentId = state.pathParameters['assignmentId'] ?? '';
        return StudentAssignmentDetailsScreen(assignmentId: assignmentId);
      },
    ),
    GoRoute(
      path: AppRoutes.studentAnnouncements,
      builder: (context, state) => const StudentAnnouncementsScreen(),
    ),
    GoRoute(
      path: AppRoutes.studentGrades,
      builder: (context, state) => const StudentGradesScreen(),
    ),
    GoRoute(
      path: AppRoutes.studentNotifications,
      builder: (context, state) => const StudentNotificationsScreen(),
    ),
  ],
);

class AppRoutes {
  const AppRoutes._();

  static const String splash = '/splash';
  static const String login = '/login';
  static const String activateAccount = '/activate-account';
  static const String studentHome = '/student-home';
  static const String studentCourses = '/student-courses';
  static const String studentSchedule = '/student-schedule';
  static const String studentAssignments = '/student-assignments';
  static const String studentAnnouncements = '/student-announcements';
  static const String studentGrades = '/student-grades';
  static const String studentNotifications = '/student-notifications';

  static String assignmentDetails(String assignmentId) {
    return '$studentAssignments/$assignmentId';
  }
}
