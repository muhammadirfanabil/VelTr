import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Centralized notification styling constants and utilities
/// This file contains all styling-related constants for notification cards
/// to ensure consistency across the entire notification system.
class NotificationStyles {
  // Private constructor to prevent instantiation
  NotificationStyles._();

  // ============================================================================
  // CARD DIMENSIONS & LAYOUT
  // ============================================================================

  /// Notification card border radius
  static const double cardBorderRadius = 14.0;

  /// Card padding
  static const EdgeInsets cardPadding = EdgeInsets.all(17);

  /// Card margin
  static const EdgeInsets cardMargin = EdgeInsets.only(bottom: 5);

  /// Spacing between icon and content
  static const double iconContentSpacing = 14.0;

  // ============================================================================
  // ICON STYLING
  // ============================================================================

  /// Status icon container size
  static const double iconContainerSize = 46.0;

  /// Status icon size
  static const double iconSize = 22.0;

  /// Icon shadow blur radius
  static const double iconShadowBlur = 6.0;

  /// Icon shadow offset
  static const Offset iconShadowOffset = Offset(0, 2);

  /// Icon shadow opacity
  static const double iconShadowOpacity = 0.21;

  // ============================================================================
  // CARD SHADOW & BACKGROUND
  // ============================================================================

  /// Card shadow color opacity
  static const double cardShadowOpacity = 0.025;

  /// Card shadow blur radius
  static const double cardShadowBlur = 6.0;

  /// Card shadow offset
  static const Offset cardShadowOffset = Offset(0, 1);

  /// Unread card background opacity
  static const double unreadBackgroundOpacity = 0.96;

  // ============================================================================
  // TYPOGRAPHY
  // ============================================================================

  /// Title font sizes
  static const double titleFontSize = 15.0;
  static const FontWeight titleFontWeightRead = FontWeight.w600;
  static const FontWeight titleFontWeightUnread = FontWeight.w700;
  static const double titleLineHeight = 1.2;
  static const int titleMaxLines = 2;

  /// Message font styling
  static const double messageFontSize = 13.2;
  static const FontWeight messageFontWeightRead = FontWeight.w400;
  static const FontWeight messageFontWeightUnread = FontWeight.w500;
  static const int messageMaxLines = 3;

  /// Badge styling
  static const EdgeInsets badgePadding = EdgeInsets.symmetric(
    horizontal: 7,
    vertical: 3,
  );
  static const double badgeBorderRadius = 5.0;
  static const double badgeFontSize = 10.0;
  static const FontWeight badgeFontWeight = FontWeight.w700;
  static const double badgeLetterSpacing = 0.3;

  /// Location and timestamp styling
  static const double metadataFontSize = 12.3;
  static const FontWeight metadataFontWeight = FontWeight.w500;
  static const double metadataIconSize = 13.0;
  static const double metadataIconSpacing = 3.0;

  /// Time header styling
  static const double timeHeaderFontSize = 12.5;
  static const FontWeight timeHeaderFontWeight = FontWeight.w500;
  static const double timeHeaderOpacity = 0.64;
  static const EdgeInsets timeHeaderPadding = EdgeInsets.only(
    left: 6,
    bottom: 7,
  );

  // ============================================================================
  // ACTION INDICATOR
  // ============================================================================

  /// Action indicator styling
  static const EdgeInsets actionIndicatorPadding = EdgeInsets.all(7);
  static const double actionIndicatorBorderRadius = 7.0;
  static const double actionIndicatorIconSize = 18.0;

  // ============================================================================
  // DELETE BACKGROUND (DISMISSIBLE)
  // ============================================================================

  /// Delete background styling
  static const EdgeInsets deleteBackgroundPadding = EdgeInsets.only(right: 24);
  static const double deleteIconSize = 24.0;
  static const double deleteTextFontSize = 12.0;
  static const FontWeight deleteTextFontWeight = FontWeight.w600;
  static const double deleteIconTextSpacing = 6.0;

  // ============================================================================
  // CONTENT SPACING
  // ============================================================================

  /// Vertical spacing constants for content layout
  static const double badgeToTitleSpacing = 6.0;
  static const double titleToMessageSpacing = 3.0;
  static const double messageToLocationSpacing = 4.0;
  static const double locationToTimestampSpacing = 5.0;

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Get title text style based on read state
  static TextStyle getTitleTextStyle(bool isRead) {
    return TextStyle(
      fontSize: titleFontSize,
      fontWeight: isRead ? titleFontWeightRead : titleFontWeightUnread,
      color: AppColors.textPrimary,
      height: titleLineHeight,
    );
  }

  /// Get message text style based on read state
  static TextStyle getMessageTextStyle(bool isRead) {
    return TextStyle(
      fontSize: messageFontSize,
      color: AppColors.textSecondary,
      fontWeight: isRead ? messageFontWeightRead : messageFontWeightUnread,
    );
  }

  /// Get metadata text style (location, timestamp)
  static TextStyle getMetadataTextStyle() {
    return TextStyle(
      fontSize: metadataFontSize,
      color: Colors.grey[600],
      fontWeight: metadataFontWeight,
    );
  }

  /// Get time header text style
  static TextStyle getTimeHeaderTextStyle() {
    return TextStyle(
      fontSize: timeHeaderFontSize,
      color: AppColors.textSecondary.withValues(alpha: timeHeaderOpacity),
      fontWeight: timeHeaderFontWeight,
    );
  }

  /// Get badge text style
  static TextStyle getBadgeTextStyle(Color textColor) {
    return TextStyle(
      fontSize: badgeFontSize,
      fontWeight: badgeFontWeight,
      color: textColor,
      letterSpacing: badgeLetterSpacing,
    );
  }

  /// Get delete background decoration
  static BoxDecoration getDeleteBackgroundDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.red.shade400, Colors.red.shade700],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      borderRadius: BorderRadius.circular(cardBorderRadius),
    );
  }

  /// Get icon container decoration
  static BoxDecoration getIconContainerDecoration(Color color) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [color, color.withValues(alpha: 0.85)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: iconShadowOpacity),
          blurRadius: iconShadowBlur,
          offset: iconShadowOffset,
        ),
      ],
    );
  }

  /// Get card background color based on read state
  static Color getCardBackgroundColor(bool isRead) {
    return isRead
        ? AppColors.surface
        : AppColors.surface.withValues(alpha: unreadBackgroundOpacity);
  }

  /// Get card shadow
  static List<BoxShadow> getCardShadow() {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: cardShadowOpacity),
        blurRadius: cardShadowBlur,
        offset: cardShadowOffset,
      ),
    ];
  }
}
