import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/student_assignment.dart';

class AssignmentStatusChip extends StatelessWidget {
  const AssignmentStatusChip({super.key, required this.assignment});

  final StudentAssignment assignment;

  @override
  Widget build(BuildContext context) {
    final Color color = assignment.isSubmitted
        ? AppColors.accent
        : assignment.isOpen
            ? AppColors.primary
            : assignment.isNotStarted
                ? const Color(0xFFB45309)
                : AppColors.textSecondary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          assignment.displayState,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}
