import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/student_notification.dart';

class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
  });

  final StudentNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isUnread = !notification.isRead;
    final String createdDate = notification.createdAt == null
        ? ''
        : DateFormat('MMM d, h:mm a').format(notification.createdAt!);

    return Card(
      color: isUnread ? AppColors.softBlue : AppColors.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: isUnread ? AppColors.primary : AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const SizedBox(width: 10, height: 10),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      notification.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight:
                                isUnread ? FontWeight.w900 : FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ),
                ],
              ),
              if (notification.body.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  notification.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                ),
              ],
              if (createdDate.isNotEmpty || notification.type != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    if (notification.type != null)
                      _MetaChip(label: notification.type!),
                    if (createdDate.isNotEmpty) _MetaChip(label: createdDate),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}
