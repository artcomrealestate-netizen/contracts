import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/customer.dart';
import '../domain/customer_repository.dart';

class FirestoreCustomerRepository implements CustomerRepository {
  final FirebaseFirestore _firestore;

  FirestoreCustomerRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> get _customers =>
      _firestore.collection('customers');

  Customer _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final individualData = data['individual'] as Map<String, dynamic>?;
    final companyData = data['company'] as Map<String, dynamic>?;
    final contactData = data['contact'] as Map<String, dynamic>?;
    return Customer(
      id: doc.id,
      customerType: customerTypeFromString(data['customerType'] as String? ?? 'individual'),
      individual: individualData == null
          ? null
          : IndividualDetails(
              fullName: individualData['fullName'] as String? ?? '',
              emiratesId: individualData['emiratesId'] as String?,
              passportNumber: individualData['passportNumber'] as String?,
            ),
      company: companyData == null
          ? null
          : CompanyDetails(
              legalName: companyData['legalName'] as String? ?? '',
              tradeLicenseNumber: companyData['tradeLicenseNumber'] as String?,
              licensingAuthority: companyData['licensingAuthority'] as String?,
            ),
      contact: CustomerContact(
        phone: contactData?['phone'] as String?,
        email: contactData?['email'] as String?,
      ),
      address: data['address'] as String?,
      status: customerStatusFromString(data['status'] as String? ?? 'active'),
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> _editableFields(Customer customer) => {
        'customerType': customer.customerType.name,
        'individual': customer.individual == null
            ? null
            : {
                'fullName': customer.individual!.fullName,
                'emiratesId': customer.individual!.emiratesId,
                'passportNumber': customer.individual!.passportNumber,
              },
        'company': customer.company == null
            ? null
            : {
                'legalName': customer.company!.legalName,
                'tradeLicenseNumber': customer.company!.tradeLicenseNumber,
                'licensingAuthority': customer.company!.licensingAuthority,
              },
        'contact': {'phone': customer.contact.phone, 'email': customer.contact.email},
        'address': customer.address,
        'status': customer.status.name,
      };

  @override
  Future<Customer> createCustomer(Customer customer) async {
    final docRef = _customers.doc();
    await docRef.set({
      ..._editableFields(customer),
      'createdBy': customer.createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final saved = await docRef.get();
    return _fromDoc(saved);
  }

  @override
  Future<void> updateCustomer(Customer customer) async {
    await _customers.doc(customer.id).update({
      ..._editableFields(customer),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<Customer?> getCustomer(String id) async {
    final doc = await _customers.doc(id).get();
    if (!doc.exists) return null;
    return _fromDoc(doc);
  }

  @override
  Stream<List<Customer>> watchCustomers() {
    return _customers.orderBy('createdAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs.map(_fromDoc).toList(),
        );
  }
}
