import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/student_course.dart';

class CourseCard extends StatelessWidget {
  const CourseCard({super.key, required this.course});

  final StudentCourse course;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: const CircleAvatar(
          backgroundColor: AppColors.softBlue,
          foregroundColor: AppColors.primary,
          child: Icon(Icons.menu_book_rounded),
        ),
        title: Text(
          course.displayName,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            <String>[
              if (course.courseCode.isNotEmpty) course.courseCode,
              if (course.teacherName != null) course.teacherName!,
              if (course.semesterName != null) course.semesterName!,
            ].join(' • '),
          ),
        ),
        trailing: Text(
          course.status,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}
