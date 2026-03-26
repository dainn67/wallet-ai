import 'package:flutter/material.dart';

class ToastService {
  static final ToastService _instance = ToastService._internal();

  factory ToastService() => _instance;

  ToastService._internal();

  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  void showSuccess(String message) {
    _showSnackBar(
      message,
      backgroundColor: Colors.green,
      icon: Icons.check_circle_outline,
    );
  }

  void showError(String message) {
    _showSnackBar(
      message,
      backgroundColor: Colors.red,
      icon: Icons.error_outline,
    );
  }

  void showWarning(String message) {
    _showSnackBar(
      message,
      backgroundColor: Colors.orange,
      icon: Icons.warning_amber_outlined,
    );
  }

  void _showSnackBar(
    String message, {
    required Color backgroundColor,
    required IconData icon,
  }) {
    messengerKey.currentState?.hideCurrentSnackBar();
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
