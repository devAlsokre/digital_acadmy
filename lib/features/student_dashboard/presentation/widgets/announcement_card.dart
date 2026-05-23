import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/student_announcement.dart';

class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({super.key, required this.announcement});

  final StudentAnnouncement announcement;

  @override
  Widget build(BuildContext context) {
    final DateTime? date = announcement.publishAt ?? announcement.createdAt;

    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: const CircleAvatar(
          backgroundColor: AppColors.softBlue,
          foregroundColor: AppColors.primary,
          child: Icon(Icons.campaign_outlined),
        ),
        title: Text(
          announcement.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            <String>[
              announcement.body,
              if (date != null) DateFormat('MMM d, yyyy').format(date),
            ].join('\n'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
