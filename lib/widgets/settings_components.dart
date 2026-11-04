import 'package:flutter/material.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 12), trailing!],
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class SettingsSaveBar extends StatelessWidget {
  const SettingsSaveBar({
    super.key,
    required this.dirty,
    required this.saving,
    required this.onSave,
    this.saveLabel = 'Save changes',
  });

  final bool dirty;
  final bool saving;
  final VoidCallback onSave;
  final String saveLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Icon(dirty ? Icons.edit_note : Icons.check_circle_outline, size: 20,
                  color: dirty ? scheme.primary : scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dirty ? 'Unsaved changes' : 'All changes saved',
                  style: TextStyle(
                    fontWeight: dirty ? FontWeight.w600 : FontWeight.w500,
                    color: dirty ? scheme.onSurface : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: dirty && !saving ? onSave : null,
                icon: saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: Text(saveLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> confirmDiscardChanges(BuildContext context) async {
  final leave = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Discard changes?'),
      content: const Text('You have unsaved changes on this screen.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep editing')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Discard')),
      ],
    ),
  );
  return leave ?? false;
}
