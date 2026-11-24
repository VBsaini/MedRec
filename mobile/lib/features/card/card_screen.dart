import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';

/// Who has opened this patient's record by scanning the card.
final _visitorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final data = await ref.watch(apiClientProvider).get('/me/visitors');
      return [
        for (final item in data as List) Map<String, dynamic>.from(item as Map),
      ];
    });

/// Link the RFID card that opens this record, and see who has scanned it.
class CardScreen extends ConsumerStatefulWidget {
  const CardScreen({super.key});

  @override
  ConsumerState<CardScreen> createState() => _CardScreenState();
}

class _CardScreenState extends ConsumerState<CardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardId = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _cardId.dispose();
    super.dispose();
  }

  Future<void> _setCard(String cardId) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(apiClientProvider)
          .put('/me/card', data: {'card_Id': cardId});
      await ref.read(authControllerProvider.notifier).refresh();
      _cardId.clear();
      if (mounted) {
        showMessage(context, cardId.isEmpty ? 'Card unlinked' : 'Card linked');
      }
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlink() async {
    final ok = await confirm(
      context,
      title: 'Unlink this card?',
      message: 'Scanning the card will no longer open your record.',
      action: 'Unlink',
    );
    if (ok) await _setCard('');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardId = ref.watch(patientProvider).cardId;
    final visitors = ref.watch(_visitorsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('RFID card')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (cardId != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.contactless_outlined),
                title: Text(cardId),
                subtitle: const Text('Linked to your record'),
                trailing: TextButton(
                  onPressed: _busy ? null : _unlink,
                  child: const Text('Unlink'),
                ),
              ),
            )
          else
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tap your card on the MedRec reader and type the card ID '
                    'it prints (for example 04A1B2C3).',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _cardId,
                    enabled: !_busy,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Card ID'),
                    validator:
                        (v) =>
                            RegExp(r'^[0-9A-Za-z]{4,32}$').hasMatch(
                                  (v ?? '').replaceAll(RegExp(r'[\s:-]'), ''),
                                )
                                ? null
                                : 'Enter the 4-32 letters and digits on the reader',
                  ),
                  const SizedBox(height: 16),
                  SubmitButton(
                    label: 'Link card',
                    busy: _busy,
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _setCard(_cardId.text.trim());
                      }
                    },
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Anyone who scans your card can see your profile, conditions, '
            'allergies, medications, history and emergency contacts without '
            'logging in. Your uploaded reports and photos are not shown.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Text('Access history', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          visitors.when(
            loading:
                () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
            error:
                (error, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('Could not load access history. $error'),
                ),
            data:
                (list) =>
                    list.isEmpty
                        ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No one has signed in as a visitor yet.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                        : Column(
                          children: [
                            for (final v in list)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.person_outline),
                                title: Text('${v['name'] ?? 'Unknown'}'),
                                subtitle: Text(
                                  [
                                    formatTimestamp(v['visitDate']),
                                    if (v['purpose'] is String) v['purpose'],
                                  ].join(' · '),
                                ),
                              ),
                          ],
                        ),
          ),
        ],
      ),
    );
  }
}
