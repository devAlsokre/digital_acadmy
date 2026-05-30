import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/widgets/app_bar.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../student_dashboard/application/student_dashboard_controller.dart';
import '../../../student_dashboard/domain/student_announcement.dart';
import '../../../student_dashboard/domain/student_assignment.dart';
import '../../../student_dashboard/domain/student_dashboard_data.dart';
import '../../../student_dashboard/domain/student_schedule_item.dart';
import '../../../student_dashboard/presentation/widgets/announcement_card.dart';
import '../../../student_dashboard/presentation/widgets/assignment_card.dart';
import '../../../student_dashboard/presentation/widgets/dashboard_summary_card.dart';
import '../../../student_dashboard/presentation/widgets/schedule_card.dart';
import '../../../student_notifications/application/notification_background_sync_controller.dart';
import '../../../student_profile/application/student_profile_controller.dart';
import '../../../student_profile/domain/student_profile.dart';

class StudentHomeScreen extends ConsumerStatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  ConsumerState<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends ConsumerState<StudentHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHomeData();
    });
  }

  Future<void> _loadHomeData({bool force = false}) async {
    final StudentProfile? student =
        ref.read(studentProfileControllerProvider).valueOrNull ??
            await ref
                .read(studentProfileControllerProvider.notifier)
                .loadCurrentStudentProfile(force: force);

    if (student == null) {
      return;
    }

    final StudentDashboardData? dashboardData = await ref
        .read(studentDashboardControllerProvider.notifier)
        .loadDashboard(student, force: force);

    try {
      await ref
          .read(notificationBackgroundSyncControllerProvider)
          .syncForStudent(
            student,
            enrolledCourseOfferingIds: dashboardData?.courses
                    .map((course) => course.courseOfferingId)
                    .where((id) => id.isNotEmpty)
                    .toList() ??
                const <String>[],
          );
    } catch (_) {
      // Background notification setup should not block the dashboard.
    }
  }

  Future<void> _handleLogout() async {
    try {
      await ref.read(authControllerProvider.notifier).signOut();

      if (!mounted) {
        return;
      }

      context.go(AppRoutes.login);
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage('Unknown error. Please try again.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String formattedDate = DateFormat('EEEE, MMMM d').format(
      DateTime.now(),
    );
    final AsyncValue<StudentProfile?> studentState =
        ref.watch(studentProfileControllerProvider);
    final AsyncValue<StudentDashboardData?> dashboardState =
        ref.watch(studentDashboardControllerProvider);
    final bool isLoggingOut = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      appBar: WidgetAppBar(
        title: 'UDS',
        unreadNotificationsCount: 20,
        onNotificationTap: () {
          // افتح صفحة الإشعارات لاحقًا
        },
      ),
      drawer: Drawer(),
      body: RefreshIndicator(
        onRefresh: () => _loadHomeData(force: true),
        child: studentState.when(
          loading: () =>
              const LoadingView(message: 'Loading student profile...'),
          error: (error, stackTrace) => _ProfileErrorView(
            message: error is AppException
                ? error.message
                : 'Unable to load your student profile. Please try again.',
            onRetry: () => _loadHomeData(force: true),
          ),
          data: (student) {
            if (student == null) {
              return _ProfileErrorView(
                message:
                    'Your account exists, but no student profile was found. Please contact the university administration.',
                onRetry: () => _loadHomeData(force: true),
              );
            }

            return _StudentHomeContent(
              formattedDate: formattedDate,
              student: student,
              dashboardState: dashboardState,
              onRetry: () => _loadHomeData(force: true),
            );
          },
        ),
      ),
    );
  }
}

class _StudentHomeContent extends StatelessWidget {
  const _StudentHomeContent({
    required this.formattedDate,
    required this.student,
    required this.dashboardState,
    required this.onRetry,
  });

  final String formattedDate;
  final StudentProfile student;
  final AsyncValue<StudentDashboardData?> dashboardState;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final StudentDashboardData? data = dashboardState.valueOrNull;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        _WelcomeCard(
          formattedDate: formattedDate,
          student: student,
        ),
        const SizedBox(height: 22),
        if (dashboardState.isLoading && data == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: LoadingView(message: 'Loading dashboard...'),
          )
        else if (dashboardState.hasError && data == null)
          _InlineError(
            message: dashboardState.error is AppException
                ? (dashboardState.error! as AppException).message
                : 'Could not load dashboard data. Please try again.',
            onRetry: onRetry,
          )
        else ...<Widget>[
          _SummaryGrid(data: data),
          const SizedBox(height: 26),
          const _SectionHeader(
            title: "Today's Schedule",
            route: AppRoutes.studentSchedule,
          ),
          const SizedBox(height: 12),
          _TodaysSchedulePreview(data: data),
          const SizedBox(height: 26),
          const _SectionHeader(
            title: 'Open Assignments',
            route: AppRoutes.studentAssignments,
          ),
          const SizedBox(height: 12),
          _AssignmentsPreview(data: data),
          const SizedBox(height: 26),
          Text(
            'Quick Access',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 14),
          const _FeatureGrid(),
          const SizedBox(height: 26),
          const _SectionHeader(
            title: 'Latest Announcements',
            route: AppRoutes.studentAnnouncements,
          ),
          const SizedBox(height: 12),
          _AnnouncementsPreview(data: data),
        ],
      ],
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.formattedDate,
    required this.student,
  });

  final String formattedDate;
  final StudentProfile student;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.primary,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              formattedDate,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.78),
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              student.displayName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _StudentInfoChip(
                  label: 'ID',
                  value: student.universityNumber,
                ),
                _StudentInfoChip(
                  label: 'Major',
                  value: student.majorName ?? 'Not assigned',
                ),
                _StudentInfoChip(
                  label: 'Level',
                  value: student.levelNumber?.toString() ?? 'Not assigned',
                ),
                _StudentInfoChip(
                  label: 'Section',
                  value: student.sectionName ?? 'Not assigned',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentInfoChip extends StatelessWidget {
  const _StudentInfoChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          '$label: $value',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _ProfileErrorView extends StatelessWidget {
  const _ProfileErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.info_outline_rounded,
              color: AppColors.primary,
              size: 38,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: <Widget>[
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.data});

  final StudentDashboardData? data;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.25,
      children: <Widget>[
        DashboardSummaryCard(
          title: 'Courses',
          value: '${data?.courses.length ?? 0}',
          icon: Icons.menu_book_rounded,
          color: AppColors.primary,
          onTap: () => context.push(AppRoutes.studentCourses),
        ),
        DashboardSummaryCard(
          title: "Today's Classes",
          value: '${data?.todaysSchedule.length ?? 0}',
          icon: Icons.calendar_month_rounded,
          color: AppColors.accent,
          onTap: () => context.push(AppRoutes.studentSchedule),
        ),
        DashboardSummaryCard(
          title: 'Open Assignments',
          value: '${data?.openAssignments.length ?? 0}',
          icon: Icons.assignment_outlined,
          color: const Color(0xFFB45309),
          onTap: () => context.push(AppRoutes.studentAssignments),
        ),
        DashboardSummaryCard(
          title: 'Announcements',
          value: '${data?.announcements.length ?? 0}',
          icon: Icons.campaign_outlined,
          color: const Color(0xFFBE123C),
          onTap: () => context.push(AppRoutes.studentAnnouncements),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.route,
  });

  final String title;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        TextButton(
          onPressed: () => context.push(route),
          child: const Text('View all'),
        ),
      ],
    );
  }
}

class _TodaysSchedulePreview extends StatelessWidget {
  const _TodaysSchedulePreview({required this.data});

  final StudentDashboardData? data;

  @override
  Widget build(BuildContext context) {
    final List<StudentScheduleItem> items =
        (data?.todaysSchedule ?? const <StudentScheduleItem>[])
            .take(3)
            .toList();

    if (items.isEmpty) {
      return const _EmptyCard(message: 'No classes scheduled for today.');
    }

    return Column(
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ScheduleCard(item: item),
            ),
          )
          .toList(),
    );
  }
}

class _AssignmentsPreview extends StatelessWidget {
  const _AssignmentsPreview({required this.data});

  final StudentDashboardData? data;

  @override
  Widget build(BuildContext context) {
    final List<StudentAssignment> assignments =
        (data?.openAssignments ?? const <StudentAssignment>[]).take(3).toList();

    if (assignments.isEmpty) {
      return const _EmptyCard(message: 'No open assignments.');
    }

    return Column(
      children: assignments
          .map(
            (assignment) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AssignmentCard(
                assignment: assignment,
                onTap: () => context.push(
                  AppRoutes.assignmentDetails(assignment.id),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _AnnouncementsPreview extends StatelessWidget {
  const _AnnouncementsPreview({required this.data});

  final StudentDashboardData? data;

  @override
  Widget build(BuildContext context) {
    final List<StudentAnnouncement> announcements =
        (data?.announcements ?? const <StudentAnnouncement>[]).take(3).toList();

    if (announcements.isEmpty) {
      return const _EmptyCard(message: 'No announcements yet.');
    }

    return Column(
      children: announcements
          .map(
            (announcement) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AnnouncementCard(announcement: announcement),
            ),
          )
          .toList(),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  @override
  Widget build(BuildContext context) {
    const List<_FeatureItem> features = <_FeatureItem>[
      _FeatureItem(
        title: 'My Schedule',
        subtitle: 'Weekly classes',
        icon: Icons.calendar_month_rounded,
        color: AppColors.softBlue,
        iconColor: AppColors.primary,
        route: AppRoutes.studentSchedule,
      ),
      _FeatureItem(
        title: 'My Courses',
        subtitle: 'Current subjects',
        icon: Icons.menu_book_rounded,
        color: AppColors.softGreen,
        iconColor: AppColors.accent,
        route: AppRoutes.studentCourses,
      ),
      _FeatureItem(
        title: 'Assignments',
        subtitle: 'Tasks and due dates',
        icon: Icons.assignment_outlined,
        color: AppColors.softAmber,
        iconColor: Color(0xFFB45309),
        route: AppRoutes.studentAssignments,
      ),
      _FeatureItem(
        title: 'Grades',
        subtitle: 'Academic results',
        icon: Icons.bar_chart_rounded,
        color: AppColors.softRose,
        iconColor: Color(0xFFBE123C),
        route: AppRoutes.studentGrades,
      ),
      _FeatureItem(
        title: 'Notifications',
        subtitle: 'University updates',
        icon: Icons.notifications_outlined,
        color: AppColors.softBlue,
        iconColor: AppColors.primary,
        route: AppRoutes.studentNotifications,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 620;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: features.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWide ? 4 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isWide ? 1.12 : 1.08,
          ),
          itemBuilder: (context, index) {
            return _FeatureCard(item: features[index]);
          },
        );
      },
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.item});

  final _FeatureItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (item.route != null) {
            context.push(item.route!);
            return;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Coming soon.')),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: item.color,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(item.icon, color: item.iconColor),
                ),
              ),
              const Spacer(),
              Text(
                item.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                item.subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureItem {
  const _FeatureItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.iconColor,
    this.route,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final String? route;
}
