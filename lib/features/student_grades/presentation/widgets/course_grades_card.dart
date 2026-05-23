import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/student_course_grades.dart';
import 'grade_score_row.dart';

class CourseGradesCard extends StatelessWidget {
  const CourseGradesCard({
    super.key,
    required this.courseGrades,
  });

  final StudentCourseGrades courseGrades;

  @override
  Widget build(BuildContext context) {
    final String totalText =
        '${_formatNumber(courseGrades.totalScore)} / ${_formatNumber(courseGrades.totalMaxGrade)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const CircleAvatar(
                  backgroundColor: AppColors.softBlue,
                  foregroundColor: AppColors.primary,
                  child: Icon(Icons.school_outlined),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        courseGrades.displayCourseName,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      if (courseGrades.courseCode.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          courseGrades.courseCode,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (courseGrades.teacherName != null ||
                courseGrades.semesterName != null) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  if (courseGrades.teacherName != null)
                    _MetaChip(
                      icon: Icons.person_outline,
                      label: courseGrades.teacherName!,
                    ),
                  if (courseGrades.semesterName != null)
                    _MetaChip(
                      icon: Icons.calendar_month_outlined,
                      label: courseGrades.semesterName!,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.softGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Displayed Total',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    Text(
                      totalText,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            ...courseGrades.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GradeScoreRow(item: item),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatNumber(num? value) {
    if (value == null) {
      return '-';
    }

    if (value % 1 == 0) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
