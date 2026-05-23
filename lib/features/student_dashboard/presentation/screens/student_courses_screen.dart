import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../student_profile/application/student_profile_controller.dart';
import '../../application/student_dashboard_controller.dart';
import '../../domain/student_course.dart';
import '../../domain/student_dashboard_data.dart';
import '../widgets/course_card.dart';

class StudentCoursesScreen extends ConsumerStatefulWidget {
  const StudentCoursesScreen({super.key});

  @override
  ConsumerState<StudentCoursesScreen> createState() =>
      _StudentCoursesScreenState();
}

class _StudentCoursesScreenState extends ConsumerState<StudentCoursesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool force = false}) async {
    final student = ref.read(studentProfileControllerProvider).valueOrNull ??
        await ref
            .read(studentProfileControllerProvider.notifier)
            .loadCurrentStudentProfile();

    if (student == null) {
      return;
    }

    await ref
        .read(studentDashboardControllerProvider.notifier)
        .loadDashboard(student, force: force);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<StudentDashboardData?> dashboardState =
        ref.watch(studentDashboardControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Courses')),
      body: RefreshIndicator(
        onRefresh: () => _load(force: true),
        child: dashboardState.when(
          loading: () => const _LoadingList(),
          error: (error, stackTrace) => _MessageList(
            message: error is AppException
                ? error.message
                : 'Could not load dashboard data. Please try again.',
          ),
          data: (data) {
            final List<StudentCourse> courses = data?.courses ?? const [];

            if (courses.isEmpty) {
              return const _MessageList(message: 'No courses found.');
            }

            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemBuilder: (context, index) => CourseCard(
                course: courses[index],
              ),
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemCount: courses.length,
            );
          },
        ),
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: const <Widget>[
        SizedBox(height: 180),
        Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        const SizedBox(height: 180),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}
