import 'package:flutter/material.dart';

void showKeepOnSnack(BuildContext context, String message) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 110),
      duration: const Duration(seconds: 4),
    ),
  );
}
