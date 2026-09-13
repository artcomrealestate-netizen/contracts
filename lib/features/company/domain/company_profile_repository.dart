import 'dart:typed_data';

import 'company_profile.dart';

abstract class CompanyProfileRepository {
  Future<CompanyProfile?> getProfile();

  Stream<CompanyProfile?> watchProfile();

  /// Any field left null keeps its current stored value — only non-null
  /// arguments are written, so a caller updating just the owner name doesn't
  /// need to re-pass the logo bytes it already has.
  Future<void> updateProfile({
    String? ownerName,
    String? ownerEmiratesId,
    Uint8List? logoBytes,
    required String updatedBy,
  });
}
