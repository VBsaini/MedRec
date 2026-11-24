import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import 'auth_controller.dart';

/// Lets the user point the app at a different MedRec server, e.g. the LAN
/// address of the computer running the backend. Returns true if it changed.
Future<bool> showServerDialog(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController(
    text: ref.read(sessionProvider).baseUrl,
  );
  final formKey = GlobalKey<FormState>();

  final url = await showDialog<String>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: const Text('Server address'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Where the MedRec backend is running. On a real phone use '
                  "your computer's Wi-Fi address; on the Android emulator "
                  'use 10.0.2.2.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    hintText: 'http://192.168.1.20:5000',
                  ),
                  validator: (value) {
                    final uri = Uri.tryParse(normalizeBaseUrl(value ?? ''));
                    return uri == null || uri.host.isEmpty
                        ? 'Enter an address like http://192.168.1.20:5000'
                        : null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, defaultBaseUrl),
              child: const Text('Reset'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, controller.text);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
  );
  if (url == null) return false;
  await ref.read(authControllerProvider.notifier).setBaseUrl(url);
  return true;
}
