import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/student_schedule_item.dart';

class ScheduleCard extends StatelessWidget {
  const ScheduleCard({super.key, required this.item});

  final StudentScheduleItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const CircleAvatar(
              backgroundColor: AppColors.softGreen,
              foregroundColor: AppColors.accent,
              child: Icon(Icons.schedule_rounded),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.courseName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_dayName(item.dayOfWeek)} • ${item.startTime} - ${item.endTime}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  if (item.room != null || item.location != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      <String>[
                        if (item.room != null) item.room!,
                        if (item.location != null) item.location!,
                      ].join(' • '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _dayName(int day) {
    return switch (day) {
      1 => 'Monday',
      2 => 'Tuesday',
      3 => 'Wednesday',
      4 => 'Thursday',
      5 => 'Friday',
      6 => 'Saturday',
      7 => 'Sunday',
      _ => 'Scheduled day',
    };
  }
}
