import 'package:flutter/material.dart';

/// Centralized color definitions for the GPS app
/// All colors used throughout the app should be defined here for consistency
class AppColors {
  // Private constructor to prevent instantiation
  AppColors._();

  // ============================================================================
  // BRAND COLORS (Primary & Secondary)
  // ============================================================================

  /// Primary brand blue color
  static const Color primaryBlue = Color(0xFF11468F);

  /// Accent red color for alerts and errors
  static const Color accentRed = Color(0xFFDA1212);

  // ============================================================================
  // SEMANTIC COLORS (Status & State)
  // ============================================================================

  /// Success/positive states (green variants)
  static const Color success = Color(0xFF10B981);
  static const Color successDark = Color(0xFF059669);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color successText = Color(0xFF065F46);

  /// Error/danger states (red variants)
  static const Color error = Color(0xFFEF4444);
  static const Color errorDark = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color errorText = Color(0xFF991B1B);

  /// Warning states (orange variants)
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningDark = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color warningText = Color(0xFF92400E);

  /// Info/informational states (blue variants)
  static const Color info = Color(0xFF3B82F6);
  static const Color infoDark = Color(0xFF1D4ED8);
  static const Color infoLight = Color(0xFFDEEBFF);
  static const Color infoText = Color(0xFF1565C0);

  // ============================================================================
  // NEUTRAL COLORS (Grays & Text)
  // ============================================================================

  /// Text colors
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color textDisabled = Color(0xFF475569);

  /// Background colors
  static const Color backgroundPrimary = Color(0xFFFFFFFF);
  static const Color backgroundSecondary = Color(0xFFF8FAFC);
  static const Color backgroundTertiary = Color(0xFFF1F5F9);
  static const Color backgroundDisabled = Color(0xFFE2E8F0);

  /// Surface colors
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFAFAFA);

  /// Border colors
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);
  static const Color borderDark = Color(0xFFCBD5E1);

  // ============================================================================
  // DARK THEME COLORS
  // ============================================================================

  /// Dark theme background colors
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkSurfaceElevated = Color(0xFF334155);

  /// Dark theme text colors
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkTextTertiary = Color(0xFF94A3B8);

  /// Dark theme border colors
  static const Color darkBorder = Color(0xFF475569);
  static const Color darkBorderLight = Color(0xFF334155);

  // ============================================================================
  // NOTIFICATION SPECIFIC COLORS
  // ============================================================================

  /// Notification category colors based on current usage patterns
  static const Color notificationAlert = Color(0xFFFEF2F2);
  static const Color notificationInfo = Color(0xFFF1F5F9);
  static const Color notificationSuccess = Color(0xFFD1FAE5);
  static const Color notificationWarning = Color(0xFFFEF3C7);
  // ============================================================================
  // NOTIFICATION BORDER STYLING
  // ============================================================================

  /// Standard notification border styling constants for ALL notification types
  static const double notificationBorderWidthUnread = 1.5;
  static const double notificationBorderWidthRead = 1.0;

  static const double notificationBorderOpacityUnread = 0.8;
  static const double notificationBorderOpacityRead = 0.5;

  /// Get notification border style based on notification state
  static Map<String, dynamic> getNotificationBorderStyle({
    required bool isRead,
    Color? borderColor,
    Color? fallbackColor,
  }) {
    Color effectiveBorderColor;
    double borderWidth;
    double opacity;

    if (borderColor != null) {
      // Custom border color (e.g., vehicle status notifications)
      effectiveBorderColor = borderColor;
    } else {
      // Default border color (e.g., geofence notifications)
      effectiveBorderColor = fallbackColor ?? border;
    }

    // Use CONSISTENT border styling for ALL notification types
    borderWidth =
        isRead ? notificationBorderWidthRead : notificationBorderWidthUnread;
    opacity =
        isRead
            ? notificationBorderOpacityRead
            : notificationBorderOpacityUnread;

    return {
      'color': effectiveBorderColor.withValues(alpha: opacity),
      'width': borderWidth,
    };
  }

  // ============================================================================
  // MAP & GEOFENCE COLORS
  // ============================================================================

  /// Map marker and overlay colors
  static const Color mapPrimary = Color(0xFF2196F3);
  static const Color mapSecondary = Color(0xFF4CAF50);
  static const Color mapWarning = Color(0xFFFF9800);
  static const Color mapError = Color(0xFFF44336);

  /// Geofence specific colors
  static const Color geofenceActive = Color(0xFF10B981);
  static const Color geofenceInactive = Color(0xFF94A3B8);
  static const Color geofenceViolation = Color(0xFFEF4444);

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Get color with opacity
  static Color withOpacity(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }

  /// Get appropriate text color for background
  static Color getTextColorForBackground(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? textPrimary : darkTextPrimary;
  }

  /// Get color scheme for theme mode
  static ColorScheme getColorScheme(bool isDark) {
    if (isDark) {
      return ColorScheme.dark(
        primary: primaryBlue,
        secondary: accentRed,
        surface: darkSurface,
        error: error,
        onPrimary: darkTextPrimary,
        onSecondary: darkTextPrimary,
        onSurface: darkTextPrimary,
        onError: darkTextPrimary,
      );
    } else {
      return ColorScheme.light(
        primary: primaryBlue,
        secondary: accentRed,
        surface: surface,
        error: error,
        onPrimary: backgroundPrimary,
        onSecondary: backgroundPrimary,
        onSurface: textPrimary,
        onError: backgroundPrimary,
      );
    }
  }
}
