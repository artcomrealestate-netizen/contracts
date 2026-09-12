/// Mirrors the "Admin" section of TDD §34. Total contract value and
/// invoice-related tiles are omitted — the app has no financial-snapshot or
/// invoice data yet (see Contract's own doc comment), and §34 itself scopes
/// those to "where data is available".
class AdminDashboardSummary {
  final int pendingApprovals;
  final int rejectedContracts;
  final int approvedThisMonth;
  final int finalizedThisMonth;

  const AdminDashboardSummary({
    required this.pendingApprovals,
    required this.rejectedContracts,
    required this.approvedThisMonth,
    required this.finalizedThisMonth,
  });
}

/// Mirrors the "Employee" section of TDD §34 (minus "Recent contracts",
/// which is a short list, not a count — see DashboardScreen).
class EmployeeDashboardSummary {
  final int myDrafts;
  final int pendingApproval;
  final int rejectedContracts;
  final int approvedContracts;

  const EmployeeDashboardSummary({
    required this.myDrafts,
    required this.pendingApproval,
    required this.rejectedContracts,
    required this.approvedContracts,
  });
}
