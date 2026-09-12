import 'dashboard_summary.dart';

abstract class DashboardRepository {
  /// Every tile is a server-side count aggregation, never a full document
  /// read (TDD §34: "must not read the entire collection").
  Future<AdminDashboardSummary> getAdminSummary();

  Future<EmployeeDashboardSummary> getEmployeeSummary(String userId);
}
