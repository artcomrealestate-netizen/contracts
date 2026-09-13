import 'dart:typed_data';

/// The company's own legal-signatory info and logo — shared Firestore
/// config (`companyProfile/main`), distinct from the legacy per-device
/// `AppSettings` (brand name/phone/email/website, `lib/main.dart`) which
/// stays as-is. Split out because a signatory's legal name/Emirates ID and
/// the logo used on official documents must be the same for every teammate
/// exporting a contract, not configured independently per device.
class CompanyProfile {
  final String? ownerName;
  final String? ownerEmiratesId;
  final Uint8List? logoBytes;
  final DateTime? updatedAt;
  final String? updatedBy;

  const CompanyProfile({
    this.ownerName,
    this.ownerEmiratesId,
    this.logoBytes,
    this.updatedAt,
    this.updatedBy,
  });

  factory CompanyProfile.empty() => const CompanyProfile();
}
