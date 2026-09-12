import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/permission.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/contract_template.dart';
import 'publish_template_version_screen.dart';
import 'template_providers.dart';

class TemplateDetailScreen extends ConsumerWidget {
  final ContractTemplate template;

  const TemplateDetailScreen({super.key, required this.template});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final canPublish = user?.hasPermission(Permission.templatePublish) ?? false;
    final versionsAsync = ref.watch(templateVersionsStreamProvider(template.id));

    return Scaffold(
      appBar: AppBar(title: Text(template.name)),
      body: versionsAsync.when(
        data: (versions) {
          if (versions.isEmpty) {
            return const Center(child: Text('No versions yet.'));
          }
          // watchVersions() orders newest-first, so the first entry is current.
          final currentVersion = versions.first;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Code: ${template.code}', style: Theme.of(context).textTheme.bodyMedium),
              Text('Current version: ${template.currentVersion}', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              if (canPublish)
                ElevatedButton.icon(
                  key: const Key('publishNewVersionButton'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PublishTemplateVersionScreen(
                        template: template,
                        currentClauses: currentVersion.clauses,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.upgrade),
                  label: const Text('Publish New Version'),
                ),
              const SizedBox(height: 16),
              for (final version in versions) ...[
                ExpansionTile(
                  key: Key('versionTile_${version.version}'),
                  title: Text(
                    'Version ${version.version}'
                    '${version.version == template.currentVersion ? ' (current)' : ''}',
                  ),
                  subtitle: Text('${version.clauses.length} clause(s)'),
                  children: [
                    for (final clause in version.clauses)
                      ListTile(
                        key: Key('clauseTile_${version.version}_${clause.id}'),
                        title: Text(clause.title),
                        subtitle: Text(clause.content),
                        trailing: clause.isLocked ? const Icon(Icons.lock_outline, size: 18) : null,
                      ),
                  ],
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load versions: $error')),
      ),
    );
  }
}
