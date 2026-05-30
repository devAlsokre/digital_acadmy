import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'image_logo.dart';

class WidgetAppBar extends StatelessWidget implements PreferredSizeWidget {
  const WidgetAppBar({
    super.key,
    this.title = 'UDS',
    this.unreadNotificationsCount = 0,
    this.onNotificationTap,
    this.showLogo = true,
    this.showNotification = true,
  });

  final String title;
  final int unreadNotificationsCount;
  final VoidCallback? onNotificationTap;
  final bool showLogo;
  final bool showNotification;

  @override
  Widget build(BuildContext context) {
    final int notificationCount =
        unreadNotificationsCount < 0 ? 0 : unreadNotificationsCount;

    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      backgroundColor: AppColors.primary,
      surfaceTintColor: Colors.transparent,

      leading: Builder(
        builder: (BuildContext context) {
          return IconButton(
            tooltip: 'القائمة',
            icon: const Icon(
              Icons.menu_rounded,
              size: 30,
              color: Colors.white,
            ),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          );
        },
      ),

      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showLogo) ...<Widget>[
            const AcademyLogo(
              variant: AcademyLogoVariant.mark,
              showCard: false,
              logoWidth: 34,
              logoHeight: 34,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
        ],
      ),

      actions: <Widget>[
        if (showNotification)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 10),
            child: Badge(
              isLabelVisible: notificationCount > 0,
              label: Text(
                notificationCount > 99 ? '99+' : '$notificationCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              backgroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              largeSize: 18,
              child: IconButton(
                tooltip: 'الإشعارات',
                onPressed: onNotificationTap,
                icon: const Icon(
                  Icons.notifications_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}