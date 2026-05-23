import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../assignment_submission/domain/selected_submission_file.dart';

class SelectedFileCard extends StatelessWidget {
  const SelectedFileCard({super.key, required this.file});

  final SelectedSubmissionFile file;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const CircleAvatar(
          backgroundColor: AppColors.softBlue,
          foregroundColor: AppColors.primary,
          child: Icon(Icons.attach_file_rounded),
        ),
        title: Text(
          file.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        subtitle: Text(file.displaySize),
      ),
    );
  }
}
