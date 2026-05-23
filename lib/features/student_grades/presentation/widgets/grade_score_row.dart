import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/student_grade_item_score.dart';

class GradeScoreRow extends StatelessWidget {
  const GradeScoreRow({
    super.key,
    required this.item,
  });

  final StudentGradeItemScore item;

  @override
  Widget build(BuildContext context) {
    final String gradedDate = item.gradedAt == null
        ? ''
        : DateFormat('MMM d, yyyy').format(item.gradedAt!);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.itemName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      if (item.itemType != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          item.itemType!,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_formatNumber(item.score)} / ${_formatNumber(item.maxGrade)}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
            if (item.weight != null || gradedDate.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: <Widget>[
                  if (item.weight != null)
                    _InfoChip(label: 'Weight ${_formatNumber(item.weight)}'),
                  if (gradedDate.isNotEmpty)
                    _InfoChip(label: 'Graded $gradedDate'),
                ],
              ),
            ],
            if (item.feedback != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                item.feedback!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
              ),
            ],
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.softBlue,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}
