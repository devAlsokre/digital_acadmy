import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../application/student_grades_controller.dart';
import '../../domain/student_course_grades.dart';
import '../widgets/course_grades_card.dart';

class StudentGradesScreen extends ConsumerStatefulWidget {
  const StudentGradesScreen({super.key});

  @override
  ConsumerState<StudentGradesScreen> createState() =>
      _StudentGradesScreenState();
}

class _StudentGradesScreenState extends ConsumerState<StudentGradesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool force = false}) async {
    await ref
        .read(studentGradesControllerProvider.notifier)
        .loadGrades(force: force);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<StudentCourseGrades>> gradesState =
        ref.watch(studentGradesControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Grades')),
      body: RefreshIndicator(
        onRefresh: () => _load(force: true),
        child: gradesState.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(24),
            children: const <Widget>[
              SizedBox(height: 160),
              LoadingView(message: 'Loading grades...'),
            ],
          ),
          error: (error, stackTrace) => _MessageList(
            title: error is AppException
                ? error.message
                : 'Could not load grades. Please try again.',
            actionLabel: 'Retry',
            onAction: () => _load(force: true),
          ),
          data: (grades) {
            if (grades.isEmpty) {
              return const _MessageList(
                title: 'No published grades yet.',
                message:
                    'Your grades will appear here after the university publishes them.',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemBuilder: (context, index) => CourseGradesCard(
                courseGrades: grades[index],
              ),
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemCount: grades.length,
            );
          },
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: <Widget>[
        const SizedBox(height: 160),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        if (message != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        if (actionLabel != null && onAction != null) ...<Widget>[
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel!),
            ),
          ),
        ],
      ],
    );
  }
}
