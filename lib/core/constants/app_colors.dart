import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  // ============================================================
  // Brand Colors - Digital Academy Logo
  // ============================================================

  /// Main royal blue from the shield/logo.
  static const Color primary = Color(0xFF0757A8);

  /// Darker blue for strong headers, gradients, and app bars.
  static const Color primaryDark = Color(0xFF033E7C);

  /// Light blue background tint.
  static const Color primaryLight = Color(0xFFEAF4FF);

  /// Teal color from the logo.
  static const Color secondary = Color(0xFF009E9A);

  /// Dark teal for pressed/active states.
  static const Color secondaryDark = Color(0xFF007A77);

  /// Light teal background tint.
  static const Color secondaryLight = Color(0xFFE6FAF8);

  /// Accent color used for highlights and active elements.
  /// Kept with the old name to avoid breaking existing code.
  static const Color accent = secondary;

  // ============================================================
  // Backgrounds
  // ============================================================

  /// Main app background.
  static const Color background = Color(0xFFF4FAFD);

  /// Cards, dialogs, and main surfaces.
  static const Color surface = Color(0xFFFFFFFF);

  /// Soft surface with very light blue.
  static const Color surfaceSoft = Color(0xFFF8FCFF);

  /// Very light blue section background.
  static const Color surfaceBlue = Color(0xFFEAF4FF);

  // ============================================================
  // Existing Soft Colors - Keep for old screens
  // ============================================================

  static const Color softBlue = Color(0xFFEAF4FF);
  static const Color softGreen = Color(0xFFE6FAF8);
  static const Color softAmber = Color(0xFFFFF7E6);
  static const Color softRose = Color(0xFFFFF1F2);

  // ============================================================
  // Borders
  // ============================================================

  static const Color border = Color(0xFFD8E7F2);
  static const Color borderStrong = Color(0xFFB8D4E8);

  // ============================================================
  // Text Colors
  // ============================================================

  static const Color textPrimary = Color(0xFF10233F);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // ============================================================
  // Status Colors
  // ============================================================

  static const Color error = Color(0xFFD92D20);
  static const Color success = Color(0xFF159B69);
  static const Color warning = Color(0xFFF79009);
  static const Color info = Color(0xFF0BA5EC);

  // ============================================================
  // Gradients
  // ============================================================

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: <Color>[
      primary,
      secondary,
    ],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      Color(0xFFEAF9FF),
      Color(0xFFF8FCFF),
      Color(0xFFFFFFFF),
    ],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: <Color>[
      primary,
      secondary,
    ],
  );
}