/// Permission key constants (TDD §12). Defined now, ahead of the features
/// that need them (contracts, templates, ...), so every later phase reads
/// permissions off this single source instead of hardcoding strings.
class Permission {
  Permission._();

  // Customer / property
  static const customerRead = 'customer.read';
  static const customerCreate = 'customer.create';
  static const propertyRead = 'property.read';
  // Not in TDD §12's RBAC list (only property.read is), but properties have
  // to be created by someone — added at the same level as customer.create.
  static const propertyCreate = 'property.create';

  // Contract
  static const contractCreate = 'contract.create';
  static const contractRead = 'contract.read';
  static const contractEditOwn = 'contract.edit_own';
  static const contractEditAny = 'contract.edit_any';
  static const contractSubmit = 'contract.submit';
  static const contractApprove = 'contract.approve';
  static const contractReject = 'contract.reject';
  static const contractFinalize = 'contract.finalize';
  static const contractArchive = 'contract.archive';
  static const contractClone = 'contract.clone';

  // Template
  static const templateCreate = 'template.create';
  static const templateEdit = 'template.edit';
  static const templatePublish = 'template.publish';

  // Document
  static const documentUpload = 'document.upload';
  static const documentRead = 'document.read';

  // Admin
  static const userRead = 'user.read';
  static const userManage = 'user.manage';
  static const auditRead = 'audit.read';
  static const dashboardRead = 'dashboard.read';
  static const notificationRead = 'notification.read';

  /// Default permission set for a newly bootstrapped employee/admin account,
  /// matching TDD §12. Used only for the manual first-admin bootstrap in
  /// this phase (no user-management UI yet).
  static Map<String, bool> defaultsFor(bool isAdmin) {
    final employeeDefaults = <String, bool>{
      customerRead: true,
      customerCreate: true,
      propertyRead: true,
      propertyCreate: true,
      contractCreate: true,
      contractRead: true,
      contractEditOwn: true,
      contractSubmit: true,
      contractClone: true,
      documentUpload: true,
      documentRead: true,
      notificationRead: true,
    };
    if (!isAdmin) return employeeDefaults;
    return {
      ...employeeDefaults,
      contractEditAny: true,
      contractApprove: true,
      contractReject: true,
      contractFinalize: true,
      contractArchive: true,
      templateCreate: true,
      templateEdit: true,
      templatePublish: true,
      userRead: true,
      userManage: true,
      auditRead: true,
      dashboardRead: true,
    };
  }
}
