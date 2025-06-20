// Centralized snackbar management for notifications. Can be used as success or error messages

import 'package:flutter/material.dart';

class SnackbarUtils {
  static SnackBar showError(BuildContext context, String message) {
    if (!context.mounted)
      return SnackBar(
        content: Text(""),
      ); // Return an empty SnackBar if context is unmounted
    return SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
    );
  }

  static SnackBar showSuccess(BuildContext context, String message) {
    if (!context.mounted)
      return SnackBar(
        content: Text(""),
      ); // Return an empty SnackBar if context is unmounted
    return SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    );
  }

  static SnackBar showWarning(BuildContext context, String message) {
    if (!context.mounted)
      return SnackBar(
        content: Text(""),
      ); // Return an empty SnackBar if context is unmounted
    return SnackBar(
      content: Text(message),
      backgroundColor: Colors.yellowAccent.shade700,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    );
  }

  static SnackBar showInfo(BuildContext context, String message) {
    if (!context.mounted)
      return SnackBar(
        content: Text(""),
      ); // Return an empty SnackBar if context is unmounted
    return SnackBar(
      content: Text(message),
      backgroundColor: Colors.blue,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    );
  }
}
