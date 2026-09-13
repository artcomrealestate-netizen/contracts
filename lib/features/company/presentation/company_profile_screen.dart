import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../main.dart' show LogoPicker, ImagePickerLogoPicker;
import '../../auth/presentation/auth_controller.dart';
import 'company_profile_providers.dart';

/// Admin-only screen (callers gate visibility on Permission.userManage, same
/// as Pending Users) editing the shared `companyProfile/main` document — the
/// legal-signatory name/Emirates ID and logo used across every exported
/// contract PDF, kept in Firestore (not the legacy per-device AppSettings)
/// so every teammate sees the same values.
class CompanyProfileScreen extends ConsumerStatefulWidget {
  const CompanyProfileScreen({super.key, this.logoPicker});

  final LogoPicker? logoPicker;

  @override
  ConsumerState<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends ConsumerState<CompanyProfileScreen> {
  final _ownerNameController = TextEditingController();
  final _ownerEmiratesIdController = TextEditingController();
  Uint8List? _pendingLogoBytes;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _ownerNameController.dispose();
    _ownerEmiratesIdController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = widget.logoPicker ?? ImagePickerLogoPicker();
    final bytes = await picker.pickLogo();
    if (bytes != null) setState(() => _pendingLogoBytes = bytes);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final currentUser = await ref.read(authControllerProvider.future);
      await ref.read(companyProfileRepositoryProvider).updateProfile(
            ownerName: _ownerNameController.text.trim(),
            ownerEmiratesId: _ownerEmiratesIdController.text.trim(),
            logoBytes: _pendingLogoBytes,
            updatedBy: currentUser?.id ?? '',
          );
      if (mounted) {
        setState(() => _pendingLogoBytes = null);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(companyProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Company Profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load company profile: $error')),
        data: (profile) {
          if (!_initialized) {
            _ownerNameController.text = profile?.ownerName ?? '';
            _ownerEmiratesIdController.text = profile?.ownerEmiratesId ?? '';
            _initialized = true;
          }
          final logoBytes = _pendingLogoBytes ?? profile?.logoBytes;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Used as the lessor's legal signatory info and logo on every exported contract PDF — shared across every teammate's device.",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('ownerNameField'),
                    controller: _ownerNameController,
                    decoration: const InputDecoration(labelText: "Owner/Lessor's Legal Name"),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('ownerEmiratesIdField'),
                    controller: _ownerEmiratesIdController,
                    decoration: const InputDecoration(labelText: "Owner's Emirates ID"),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: logoBytes != null
                        ? Image.memory(logoBytes, key: const Key('companyLogoPreview'), height: 80, width: 160, fit: BoxFit.contain)
                        : const SizedBox(height: 80, child: Center(child: Text('No logo set'))),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const Key('pickCompanyLogoButton'),
                    onPressed: _pickLogo,
                    child: const Text('Choose Logo'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    key: const Key('saveCompanyProfileButton'),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
