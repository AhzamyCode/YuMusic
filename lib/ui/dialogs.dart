import 'package:flutter/material.dart';

/// Dialog satu kolom teks. Mengembalikan null bila dibatalkan atau kosong.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String label,
  required String confirm,
  required String cancel,
  String initial = '',
}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: Text(confirm),
        ),
      ],
    ),
  );
  final text = result?.trim() ?? '';
  return text.isEmpty ? null : text;
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String confirm,
  required String cancel,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return ok ?? false;
}
