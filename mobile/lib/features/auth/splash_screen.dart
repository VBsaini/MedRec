import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets.dart';
import 'auth_controller.dart';
import 'server_dialog.dart';

/// Shown while a saved login is being checked, and when the server cannot be
/// reached to check it.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    final auth = ref.read(authControllerProvider.notifier);

    if (state is! AuthUnavailable) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Cannot connect',
                message: state.message,
                actionLabel: 'Try again',
                onAction: auth.restore,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              // Wrap, not Row: with a large system font size the two
              // buttons do not fit side by side on a narrow phone.
              child: Wrap(
                alignment: WrapAlignment.center,
                children: [
                  TextButton(
                    onPressed: () async {
                      if (await showServerDialog(context, ref)) auth.restore();
                    },
                    child: const Text('Server address'),
                  ),
                  TextButton(
                    onPressed: auth.logout,
                    child: const Text('Log out'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
