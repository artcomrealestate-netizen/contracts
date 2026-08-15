class SavedQuotation {
  final String id;
  final String quotaNumber;
  final String customerName;
  final DateTime createdAt;
  final String roomType;
  final String contractType;
  final int quantity;
  final double priceMonth;
  final double vat;
  final double cd;
  final double camera;
  final bool includeCd;
  final bool includeCamera;
  final double service;
  final double managementPercent;
  final double vatPercent;
  final double deposit;
  final int contractMonths;
  final int numberOfPayments;
  final double yearlyPrice;
  final double finalPrice;

  const SavedQuotation({
    required this.id,
    required this.quotaNumber,
    required this.customerName,
    required this.createdAt,
    required this.roomType,
    this.contractType = 'residential',
    required this.quantity,
    required this.priceMonth,
    required this.vat,
    required this.cd,
    required this.camera,
    this.includeCd = true,
    this.includeCamera = true,
    this.service = 0,
    this.managementPercent = 0,
    this.vatPercent = 5,
    required this.deposit,
    this.contractMonths = 12,
    required this.numberOfPayments,
    required this.yearlyPrice,
    required this.finalPrice,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'quotaNumber': quotaNumber,
        'customerName': customerName,
        'createdAt': createdAt.toIso8601String(),
        'roomType': roomType,
        'contractType': contractType,
        'quantity': quantity,
        'priceMonth': priceMonth,
        'vat': vat,
        'cd': cd,
        'camera': camera,
        'includeCd': includeCd,
        'includeCamera': includeCamera,
        'service': service,
        'managementPercent': managementPercent,
        'vatPercent': vatPercent,
        'deposit': deposit,
        'contractMonths': contractMonths,
        'numberOfPayments': numberOfPayments,
        'yearlyPrice': yearlyPrice,
        'finalPrice': finalPrice,
      };

  factory SavedQuotation.fromJson(Map<String, dynamic> json) {
    return SavedQuotation(
      id: json['id'] as String,
      quotaNumber: json['quotaNumber'] as String,
      customerName: json['customerName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      roomType: json['roomType'] as String,
      contractType: (json['contractType'] as String?) ?? 'residential',
      quantity: json['quantity'] as int,
      priceMonth: (json['priceMonth'] as num).toDouble(),
      vat: (json['vat'] as num).toDouble(),
      cd: (json['cd'] as num).toDouble(),
      camera: (json['camera'] as num).toDouble(),
      includeCd: (json['includeCd'] as bool?) ?? true,
      includeCamera: (json['includeCamera'] as bool?) ?? true,
      service: (json['service'] as num?)?.toDouble() ?? 0,
      managementPercent: (json['managementPercent'] as num?)?.toDouble() ?? 0,
      vatPercent: (json['vatPercent'] as num?)?.toDouble() ?? 5,
      deposit: (json['deposit'] as num).toDouble(),
      // Quotations saved before the contract-period feature existed don't
      // have this key; they were always computed as a full year.
      contractMonths: (json['contractMonths'] as num?)?.toInt() ?? 12,
      numberOfPayments: (json['numberOfPayments'] ?? json['paymentTerms']) as int,
      yearlyPrice: (json['yearlyPrice'] as num).toDouble(),
      finalPrice: (json['finalPrice'] as num).toDouble(),
    );
  }
}
