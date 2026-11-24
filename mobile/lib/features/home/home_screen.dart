import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets.dart';
import '../../models/patient.dart';
import '../auth/auth_controller.dart';
import '../records/record_kind.dart';
import '../reports/reports_controller.dart';

/// Dashboard: who you are, and a way into every part of the record.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await confirm(
      context,
      title: 'Log out?',
      message: 'You will need your email and password to log back in.',
      action: 'Log out',
    );
    if (ok) await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patient = ref.watch(patientProvider);
    final reportCount = ref.watch(reportsProvider).valueOrNull?.length;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MedRec'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(reportsProvider);
          try {
            await ref.read(authControllerProvider.notifier).refresh();
          } catch (e) {
            if (context.mounted) showMessage(context, '$e');
          }
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _PatientHeader(patient: patient),
            const SizedBox(height: 24),
            Text('Your record', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _SectionTile(
              icon: Icons.person_outline,
              title: 'Profile and conditions',
              subtitle: _conditionSummary(patient),
              onTap: () => context.push('/profile'),
            ),
            for (final kind in recordKinds)
              _SectionTile(
                icon: kind.icon,
                title: kind.title,
                subtitle: _count(patient.items(kind.jsonKey).length),
                onTap: () => context.push('/records/${kind.slug}'),
              ),
            const SizedBox(height: 16),
            Text('Documents', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _SectionTile(
              icon: Icons.folder_copy_outlined,
              title: 'Reports and photos',
              subtitle:
                  reportCount == null
                      ? 'Lab reports, prescriptions, scans'
                      : _count(reportCount, noun: 'report'),
              onTap: () => context.push('/reports'),
            ),
            const SizedBox(height: 16),
            Text('Access', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _SectionTile(
              icon: Icons.contactless_outlined,
              title: 'RFID card',
              subtitle:
                  patient.cardId == null
                      ? 'No card linked'
                      : 'Linked: ${patient.cardId}',
              onTap: () => context.push('/card'),
            ),
          ],
        ),
      ),
    );
  }

  static String _count(int n, {String noun = 'entry'}) {
    if (n == 0) return 'None added';
    final plural =
        noun.endsWith('y')
            ? '${noun.substring(0, noun.length - 1)}ies'
            : '${noun}s';
    return '$n ${n == 1 ? noun : plural}';
  }

  static String _conditionSummary(Patient p) {
    final active = [
      if (p.diabetic.status) 'Diabetes',
      if (p.heart.status) 'Heart condition',
      if (p.mentalHealth.status) 'Mental health',
    ];
    return active.isEmpty ? 'Basic details and conditions' : active.join(' · ');
  }
}

class _PatientHeader extends StatelessWidget {
  const _PatientHeader({required this.patient});

  final Patient patient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final facts = [
      if (patient.bloodGroup != null) patient.bloodGroup!,
      if (patient.age != null) '${patient.age} yrs',
      if (patient.gender != null) patient.gender!,
    ];
    final initial =
        patient.name.isEmpty
            ? '?'
            : patient.name.characters.first.toUpperCase();

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              child: Text(initial, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    patient.email,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  if (facts.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final fact in facts)
                          Chip(
                            label: Text(fact),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}
