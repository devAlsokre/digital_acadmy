import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../assignment_submission/application/assignment_submission_controller.dart';
import '../../application/student_dashboard_controller.dart';
import '../../../student_profile/application/student_profile_controller.dart';
import '../../../student_profile/domain/student_profile.dart';
import '../../domain/student_assignment.dart';
import '../widgets/assignment_status_chip.dart';
import '../widgets/selected_file_card.dart';

class StudentAssignmentDetailsScreen extends ConsumerStatefulWidget {
  const StudentAssignmentDetailsScreen({
    super.key,
    required this.assignmentId,
  });

  final String assignmentId;

  @override
  ConsumerState<StudentAssignmentDetailsScreen> createState() =>
      _StudentAssignmentDetailsScreenState();
}

class _StudentAssignmentDetailsScreenState
    extends ConsumerState<StudentAssignmentDetailsScreen> {
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final StudentProfile? student =
        ref.read(studentProfileControllerProvider).valueOrNull ??
            await ref
                .read(studentProfileControllerProvider.notifier)
                .loadCurrentStudentProfile();

    if (student == null) {
      return;
    }

    await ref
        .read(assignmentSubmissionControllerProvider.notifier)
        .loadAssignment(
          assignmentId: widget.assignmentId,
          studentId: student.id,
        );
  }

  Future<void> _submit(StudentAssignment assignment) async {
    final StudentProfile? student =
        ref.read(studentProfileControllerProvider).valueOrNull;

    if (student == null) {
      _showMessage(
        'Your account exists, but no student profile was found. Please contact the university administration.',
      );
      return;
    }

    await ref.read(assignmentSubmissionControllerProvider.notifier).submit(
          assignmentId: assignment.id,
          studentId: student.id,
          answerText: _notesController.text,
        );

    await ref
        .read(studentProfileControllerProvider.notifier)
        .loadCurrentStudentProfile();
    await ref
        .read(studentDashboardControllerProvider.notifier)
        .loadDashboard(student, force: true);

    _notesController.clear();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AssignmentSubmissionState>(
      assignmentSubmissionControllerProvider,
      (previous, next) {
        final String? message = next.message;

        if (message != null && message != previous?.message) {
          _showMessage(message);
          ref
              .read(assignmentSubmissionControllerProvider.notifier)
              .clearMessage();
        }
      },
    );

    final AssignmentSubmissionState submissionState =
        ref.watch(assignmentSubmissionControllerProvider);
    final StudentAssignment? assignment = submissionState.assignment;

    return Scaffold(
      appBar: AppBar(title: const Text('Assignment Details')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: assignment == null
            ? _DetailsMessage(
                message: submissionState.status ==
                        AssignmentSubmissionStatus.error
                    ? submissionState.message ??
                        'Could not load assignment details. Please try again.'
                    : 'Loading assignment details...',
                debugMessage: submissionState.debugMessage,
                onRetry: _load,
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: <Widget>[
                  _HeaderCard(assignment: assignment),
                  const SizedBox(height: 16),
                  _InfoSection(assignment: assignment),
                  const SizedBox(height: 16),
                  _ExistingSubmissionSection(assignment: assignment),
                  const SizedBox(height: 16),
                  _UploadSection(
                    assignment: assignment,
                    state: submissionState,
                    notesController: _notesController,
                    onPickFile: () => ref
                        .read(assignmentSubmissionControllerProvider.notifier)
                        .pickFile(),
                    onSubmit: () => _submit(assignment),
                  ),
                ],
              ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.assignment});

  final StudentAssignment assignment;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              <String>[
                if (assignment.courseCode.isNotEmpty) assignment.courseCode,
                assignment.courseName,
              ].join(' - '),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.82),
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              assignment.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            if (assignment.lectureTitle != null ||
                assignment.lectureNumber != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                <String>[
                  if (assignment.lectureNumber != null)
                    'Lecture ${assignment.lectureNumber}',
                  if (assignment.lectureTitle != null) assignment.lectureTitle!,
                ].join(' - '),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.86),
                    ),
              ),
            ],
            const SizedBox(height: 14),
            AssignmentStatusChip(assignment: assignment),
          ],
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.assignment});

  final StudentAssignment assignment;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Assignment Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 14),
            _InfoRow(
              label: 'Description',
              value: assignment.description ?? 'No description provided.',
            ),
            _InfoRow(
              label: 'Instructions',
              value: assignment.instructions ?? 'No instructions provided.',
            ),
            _InfoRow(
              label: 'Max grade',
              value: assignment.maxGrade?.toString() ?? 'Not specified',
            ),
            _InfoRow(
              label: 'Start',
              value: _formatDateTime(assignment.startAt),
            ),
            _InfoRow(
              label: 'Due',
              value: _formatDateTime(assignment.dueAt),
            ),
            _InfoRow(
              label: 'Remaining time',
              value: _remainingTime(assignment),
            ),
            if (assignment.attachmentUrl != null) ...<Widget>[
              const SizedBox(height: 10),
              Card(
                color: AppColors.softBlue,
                child: ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: const Text('Download assignment file'),
                  subtitle: Text(
                    assignment.attachmentUrl!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // TODO: Open this URL/path with url_launcher if the backend
                  // stores public or signed URLs.
                ),
              ),
            ] else ...<Widget>[
              const SizedBox(height: 10),
              Text(
                'No assignment file attached.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExistingSubmissionSection extends StatelessWidget {
  const _ExistingSubmissionSection({required this.assignment});

  final StudentAssignment assignment;

  @override
  Widget build(BuildContext context) {
    if (!assignment.isSubmitted) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text('No submission uploaded yet.'),
        ),
      );
    }

    final String fileName = assignment.submissionFilePath == null
        ? 'Submitted file'
        : assignment.submissionFilePath!.split('/').last;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Existing Submission',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            Text('Status: ${assignment.submissionStatus ?? 'submitted'}'),
            if (assignment.submittedAt != null)
              Text('Submitted: ${_formatDateTime(assignment.submittedAt)}'),
            Text('File: $fileName'),
            if (assignment.grade != null) Text('Grade: ${assignment.grade}'),
            if (assignment.feedback != null)
              Text('Feedback: ${assignment.feedback}'),
            const SizedBox(height: 10),
            Text(
              assignment.isOpen
                  ? 'You can re-upload before the deadline.'
                  : 'Submission is closed.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadSection extends StatelessWidget {
  const _UploadSection({
    required this.assignment,
    required this.state,
    required this.notesController,
    required this.onPickFile,
    required this.onSubmit,
  });

  final StudentAssignment assignment;
  final AssignmentSubmissionState state;
  final TextEditingController notesController;
  final VoidCallback onPickFile;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final bool canSubmit =
        assignment.isOpen && state.selectedFile != null && !state.isBusy;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Upload Submission',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),
            if (!assignment.isOpen)
              Text(
                assignment.isNotStarted
                    ? 'This assignment is not open yet.'
                    : 'This assignment is closed.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: state.isBusy ? null : onPickFile,
              icon: const Icon(Icons.attach_file_rounded),
              label: Text(
                state.status == AssignmentSubmissionStatus.pickingFile
                    ? 'Selecting file...'
                    : 'Select File',
              ),
            ),
            if (state.selectedFile != null) ...<Widget>[
              const SizedBox(height: 12),
              SelectedFileCard(file: state.selectedFile!),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Notes to teacher',
                hintText: 'Optional notes about your submission',
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: state.status == AssignmentSubmissionStatus.uploading
                  ? 'Uploading...'
                  : 'Submit Assignment',
              icon: Icons.cloud_upload_rounded,
              isLoading: state.status == AssignmentSubmissionStatus.uploading,
              onPressed: canSubmit ? onSubmit : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 3),
          Text(value),
        ],
      ),
    );
  }
}

class _DetailsMessage extends StatelessWidget {
  const _DetailsMessage({
    required this.message,
    required this.onRetry,
    this.debugMessage,
  });

  final String message;
  final VoidCallback onRetry;
  final String? debugMessage;

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
        const SizedBox(height: 16),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ),
        if (kDebugMode && debugMessage != null) ...<Widget>[
          const SizedBox(height: 18),
          Text(
            debugMessage!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ],
    );
  }
}

String _formatDateTime(DateTime? value) {
  if (value == null) {
    return 'Not specified';
  }

  return DateFormat('MMM d, yyyy - h:mm a').format(value);
}

String _remainingTime(StudentAssignment assignment) {
  if (assignment.isNotStarted) {
    return 'Not started yet';
  }

  if (!assignment.isOpen) {
    return 'Closed';
  }

  final DateTime? dueAt = assignment.dueAt;

  if (dueAt == null) {
    return 'No deadline specified';
  }

  final Duration remaining = dueAt.difference(DateTime.now());

  if (remaining.inDays > 1) {
    return 'Due in ${remaining.inDays} days';
  }

  if (remaining.inDays == 1) {
    return 'Due tomorrow';
  }

  return 'Due today';
}
