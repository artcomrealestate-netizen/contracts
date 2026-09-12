import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/firestore_dashboard_repository.dart';
import '../domain/dashboard_repository.dart';
import '../domain/dashboard_summary.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return FirestoreDashboardRepository(ref.watch(firestoreProvider));
});

final adminDashboardSummaryProvider = FutureProvider.autoDispose<AdminDashboardSummary>((ref) {
  return ref.watch(dashboardRepositoryProvider).getAdminSummary();
});

final employeeDashboardSummaryProvider = FutureProvider.autoDispose<EmployeeDashboardSummary>((ref) {
  final user = ref.watch(authControllerProvider).value;
  if (user == null) {
    return Future.value(
      const EmployeeDashboardSummary(myDrafts: 0, pendingApproval: 0, rejectedContracts: 0, approvedContracts: 0),
    );
  }
  return ref.watch(dashboardRepositoryProvider).getEmployeeSummary(user.id);
});
