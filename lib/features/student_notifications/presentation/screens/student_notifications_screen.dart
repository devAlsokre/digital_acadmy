import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../application/student_notifications_controller.dart';
import '../../domain/student_notification.dart';
import '../widgets/notification_card.dart';
import '../widgets/unread_badge.dart';

class StudentNotificationsScreen extends ConsumerStatefulWidget {
  const StudentNotificationsScreen({super.key});

  @override
  ConsumerState<StudentNotificationsScreen> createState() =>
      _StudentNotificationsScreenState();
}

class _StudentNotificationsScreenState
    extends ConsumerState<StudentNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool force = false}) async {
    await ref
        .read(studentNotificationsControllerProvider.notifier)
        .loadNotifications(force: force);
  }

  Future<void> _markAllAsRead() async {
    try {
      await ref
          .read(studentNotificationsControllerProvider.notifier)
          .markAllAsRead();

      if (!mounted) {
        return;
      }

      _showMessage('All notifications marked as read.');
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage('Could not mark notification as read.');
    }
  }

  Future<void> _openNotification(StudentNotification notification) async {
    if (!notification.isRead) {
      try {
        await ref
            .read(studentNotificationsControllerProvider.notifier)
            .markAsRead(notification.id);
      } on AppException catch (error) {
        if (mounted) {
          _showMessage(error.message);
        }
      } catch (_) {
        if (mounted) {
          _showMessage('Could not mark notification as read.');
        }
      }
    }

    if (!mounted) {
      return;
    }

    _showNotificationDetails(notification);
  }

  void _showNotificationDetails(StudentNotification notification) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return _NotificationDetailsSheet(notification: notification);
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<StudentNotification>> notificationsState =
        ref.watch(studentNotificationsControllerProvider);
    final int unreadCount = notificationsState.valueOrNull
            ?.where((notification) => !notification.isRead)
            .length ??
        0;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('Notifications'),
            if (unreadCount > 0) ...<Widget>[
              const SizedBox(width: 8),
              UnreadBadge(count: unreadCount),
            ],
          ],
        ),
        actions: <Widget>[
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Mark all as read'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(force: true),
        child: notificationsState.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(24),
            children: const <Widget>[
              SizedBox(height: 160),
              LoadingView(message: 'Loading notifications...'),
            ],
          ),
          error: (error, stackTrace) => _MessageList(
            title: error is AppException
                ? error.message
                : 'Could not load notifications. Please try again.',
            actionLabel: 'Retry',
            onAction: () => _load(force: true),
          ),
          data: (notifications) {
            if (notifications.isEmpty) {
              return const _MessageList(
                title: 'No notifications yet.',
                message: 'Important university updates will appear here.',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const _NetworkNote();
                }

                final StudentNotification notification =
                    notifications[index - 1];
                return NotificationCard(
                  notification: notification,
                  onTap: () => _openNotification(notification),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemCount: notifications.length + 1,
            );
          },
        ),
      ),
    );
  }
}

class _NetworkNote extends StatelessWidget {
  const _NetworkNote();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.softBlue,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(
              Icons.wifi_tethering_rounded,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Local alerts are enabled when your phone is connected to the university network.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.primaryDark,
                      height: 1.35,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationDetailsSheet extends StatelessWidget {
  const _NotificationDetailsSheet({required this.notification});

  final StudentNotification notification;

  @override
  Widget build(BuildContext context) {
    final String createdDate = notification.createdAt == null
        ? ''
        : DateFormat('EEEE, MMMM d, yyyy - h:mm a')
            .format(notification.createdAt!);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                notification.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              if (createdDate.isNotEmpty || notification.type != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    if (notification.type != null)
                      _DetailChip(label: notification.type!),
                    if (createdDate.isNotEmpty) _DetailChip(label: createdDate),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              Text(
                notification.body.isEmpty
                    ? 'No additional details.'
                    : notification.body,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.softBlue,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
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
