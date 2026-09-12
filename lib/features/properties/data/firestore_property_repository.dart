import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/property.dart';
import '../domain/property_repository.dart';

class FirestorePropertyRepository implements PropertyRepository {
  final FirebaseFirestore _firestore;

  FirestorePropertyRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> get _properties =>
      _firestore.collection('properties');

  Property _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final locationData = data['location'] as Map<String, dynamic>?;
    return Property(
      id: doc.id,
      propertyCode: data['propertyCode'] as String? ?? '',
      name: data['name'] as String? ?? '',
      propertyType: data['propertyType'] as String? ?? '',
      unitNumber: data['unitNumber'] as String?,
      area: (data['area'] as num?)?.toDouble() ?? 0,
      location: PropertyLocation(
        emirate: locationData?['emirate'] as String?,
        city: locationData?['city'] as String?,
        district: locationData?['district'] as String?,
      ),
      status: propertyStatusFromString(data['status'] as String? ?? 'active'),
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> _editableFields(Property property) => {
        'propertyCode': property.propertyCode,
        'name': property.name,
        'propertyType': property.propertyType,
        'unitNumber': property.unitNumber,
        'area': property.area,
        'location': {
          'emirate': property.location.emirate,
          'city': property.location.city,
          'district': property.location.district,
        },
        'status': property.status.name,
      };

  @override
  Future<Property> createProperty(Property property) async {
    final docRef = _properties.doc();
    await docRef.set({
      ..._editableFields(property),
      'createdBy': property.createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final saved = await docRef.get();
    return _fromDoc(saved);
  }

  @override
  Future<void> updateProperty(Property property) async {
    await _properties.doc(property.id).update({
      ..._editableFields(property),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<Property?> getProperty(String id) async {
    final doc = await _properties.doc(id).get();
    if (!doc.exists) return null;
    return _fromDoc(doc);
  }

  @override
  Stream<List<Property>> watchProperties() {
    return _properties.orderBy('createdAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs.map(_fromDoc).toList(),
        );
  }
}
