import 'package:flutter/material.dart';

import 'format.dart';

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Asks the user to confirm something destructive. Returns true on confirm.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String action = 'Delete',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder:
        (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
  );
  return result ?? false;
}

/// Centered icon + text for empty lists and load failures.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A form field that shows a date and opens a date picker when tapped.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.required = false,
    this.enabled = true,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool required;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return FormField<DateTime>(
      // Re-create the field state when the value changes from outside.
      key: ValueKey(value),
      initialValue: value,
      validator: (v) => required && v == null ? 'Required' : null,
      builder: (field) {
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap:
              !enabled
                  ? null
                  : () async {
                    final today = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: value ?? today,
                      firstDate: DateTime(1900),
                      lastDate: DateTime(today.year + 20),
                    );
                    if (picked != null) onChanged(picked);
                  },
          child: InputDecorator(
            isEmpty: value == null,
            decoration: InputDecoration(
              labelText: required ? '$label *' : label,
              errorText: field.errorText,
              enabled: enabled,
              suffixIcon:
                  value != null && !required && enabled
                      ? IconButton(
                        tooltip: 'Clear date',
                        icon: const Icon(Icons.clear),
                        onPressed: () => onChanged(null),
                      )
                      : const Icon(Icons.calendar_today_outlined),
            ),
            child: Text(formatDate(value)),
          ),
        );
      },
    );
  }
}

/// Full-width primary button that shows a spinner while [busy].
class SubmitButton extends StatelessWidget {
  const SubmitButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        child:
            busy
                ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
                : Text(label),
      ),
    );
  }
}
