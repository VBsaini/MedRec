import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets.dart';
import '../auth/auth_controller.dart';
import 'record_form_screen.dart';
import 'record_kind.dart';

/// Lists the entries of one record kind, with add and tap-to-edit.
class RecordListScreen extends ConsumerWidget {
  const RecordListScreen({super.key, required this.kind});

  final RecordKind kind;

  void _openForm(BuildContext context, [Map<String, dynamic>? item]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => RecordFormScreen(kind: kind, item: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(patientProvider).items(kind.jsonKey);

    return Scaffold(
      appBar: AppBar(title: Text(kind.title)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: Text('Add ${kind.singular}'),
      ),
      body: RefreshIndicator(
        onRefresh:
            () => ref
                .read(authControllerProvider.notifier)
                .refresh()
                .catchError((Object e) {
                  if (context.mounted) showMessage(context, '$e');
                }),
        child:
            items.isEmpty
                ? LayoutBuilder(
                  // Scrollable so pull-to-refresh works on an empty list.
                  builder:
                      (context, constraints) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: constraints.maxHeight,
                          child: EmptyState(
                            icon: kind.icon,
                            title: 'Nothing here yet',
                            message: kind.emptyHint,
                          ),
                        ),
                      ),
                )
                : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final subtitle = kind.subtitle(item);
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: Icon(kind.icon),
                        title: Text('${item[kind.titleKey] ?? ''}'),
                        subtitle: subtitle.isEmpty ? null : Text(subtitle),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openForm(context, item),
                      ),
                    );
                  },
                ),
      ),
    );
  }
}
