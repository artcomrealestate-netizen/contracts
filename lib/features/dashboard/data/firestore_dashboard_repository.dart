import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/dashboard_repository.dart';
import '../domain/dashboard_summary.dart';

class FirestoreDashboardRepository implements DashboardRepository {
  final FirebaseFirestore _firestore;

  FirestoreDashboardRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> get _contracts =>
      _firestore.collection('contracts');

  Future<int> _count(Query<Map<String, dynamic>> query) async {
    final snapshot = await query.count().get();
    return snapshot.count ?? 0;
  }

  @override
  Future<AdminDashboardSummary> getAdminSummary() async {
    final now = DateTime.now();
    final monthStart = Timestamp.fromDate(DateTime(now.year, now.month, 1));

    final results = await Future.wait([
      _count(_contracts.where('status', isEqualTo: 'PENDING_APPROVAL')),
      _count(_contracts.where('status', isEqualTo: 'REJECTED')),
      // approvedAt/finalizedAt stay set even once a contract moves further
      // on (e.g. APPROVED -> FINALIZED), so a plain range filter — no
      // status filter — is what "was approved/finalized this month" means.
      _count(_contracts.where('approvedAt', isGreaterThanOrEqualTo: monthStart)),
      _count(_contracts.where('finalizedAt', isGreaterThanOrEqualTo: monthStart)),
    ]);

    return AdminDashboardSummary(
      pendingApprovals: results[0],
      rejectedContracts: results[1],
      approvedThisMonth: results[2],
      finalizedThisMonth: results[3],
    );
  }

  @override
  Future<EmployeeDashboardSummary> getEmployeeSummary(String userId) async {
    // Every tile filters by createdBy first — the contracts rule requires
    // that shape for anyone without contract.edit_any (see
    // FirestoreContractRepository.watchContracts' own doc comment).
    final mine = _contracts.where('createdBy', isEqualTo: userId);
    final results = await Future.wait([
      _count(mine.where('status', isEqualTo: 'DRAFT')),
      _count(mine.where('status', isEqualTo: 'PENDING_APPROVAL')),
      _count(mine.where('status', isEqualTo: 'REJECTED')),
      _count(mine.where('status', isEqualTo: 'APPROVED')),
    ]);

    return EmployeeDashboardSummary(
      myDrafts: results[0],
      pendingApproval: results[1],
      rejectedContracts: results[2],
      approvedContracts: results[3],
    );
  }
}
