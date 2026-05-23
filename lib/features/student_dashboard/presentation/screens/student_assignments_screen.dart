import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../student_profile/application/student_profile_controller.dart';
import '../../application/student_dashboard_controller.dart';
import '../../domain/student_assignment.dart';
import '../../domain/student_dashboard_data.dart';
import '../widgets/assignment_card.dart';

class StudentAssignmentsScreen extends ConsumerStatefulWidget {
  const StudentAssignmentsScreen({super.key});

  @override
  ConsumerState<StudentAssignmentsScreen> createState() =>
      _StudentAssignmentsScreenState();
}

class _StudentAssignmentsScreenState
    extends ConsumerState<StudentAssignmentsScreen> {
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
      appBar: AppBar(title: const Text('Assignments')),
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
            final List<StudentAssignment> assignments =
                data?.openAssignments ?? const [];

            if (assignments.isEmpty) {
              return const _MessageList(message: 'No open assignments.');
            }

            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemBuilder: (context, index) => AssignmentCard(
                assignment: assignments[index],
                onTap: () => context.push(
                  AppRoutes.assignmentDetails(assignments[index].id),
                ),
              ),
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemCount: assignments.length,
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
