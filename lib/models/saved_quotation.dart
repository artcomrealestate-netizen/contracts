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
  final double industrialDepositPercent;
  final int contractMonths;
  final int numberOfPayments;
  final double yearlyPrice;
  final double finalPrice;
  final int khana;
  final String shabraNumbers;
  final int shabraCount;
  final double area;
  final double pricePerSqft;
  final double warehouseDepositPercent;
  final double civilDefensePerShabraRate;
  final double contractCertFee;
  final double hemayaInsuranceRate;
  final double hemayaContractFeeRate;

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
    this.industrialDepositPercent = 10,
    this.contractMonths = 12,
    required this.numberOfPayments,
    required this.yearlyPrice,
    required this.finalPrice,
    this.khana = 0,
    this.shabraNumbers = '',
    this.shabraCount = 1,
    this.area = 0,
    this.pricePerSqft = 0,
    this.warehouseDepositPercent = 10,
    this.civilDefensePerShabraRate = 1000,
    this.contractCertFee = 160,
    this.hemayaInsuranceRate = 1500,
    this.hemayaContractFeeRate = 500,
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
        'industrialDepositPercent': industrialDepositPercent,
        'contractMonths': contractMonths,
        'numberOfPayments': numberOfPayments,
        'yearlyPrice': yearlyPrice,
        'finalPrice': finalPrice,
        'khana': khana,
        'shabraNumbers': shabraNumbers,
        'shabraCount': shabraCount,
        'area': area,
        'pricePerSqft': pricePerSqft,
        'warehouseDepositPercent': warehouseDepositPercent,
        'civilDefensePerShabraRate': civilDefensePerShabraRate,
        'contractCertFee': contractCertFee,
        'hemayaInsuranceRate': hemayaInsuranceRate,
        'hemayaContractFeeRate': hemayaContractFeeRate,
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
      industrialDepositPercent: (json['industrialDepositPercent'] as num?)?.toDouble() ?? 10,
      // Quotations saved before the contract-period feature existed don't
      // have this key; they were always computed as a full year.
      contractMonths: (json['contractMonths'] as num?)?.toInt() ?? 12,
      numberOfPayments: (json['numberOfPayments'] ?? json['paymentTerms']) as int,
      yearlyPrice: (json['yearlyPrice'] as num).toDouble(),
      finalPrice: (json['finalPrice'] as num).toDouble(),
      // Warehouse/shabra fields didn't exist before that feature; default to
      // the same sensible values a brand-new warehouse quotation starts with.
      khana: (json['khana'] as num?)?.toInt() ?? 0,
      shabraNumbers: (json['shabraNumbers'] as String?) ?? '',
      shabraCount: (json['shabraCount'] as num?)?.toInt() ?? 1,
      area: (json['area'] as num?)?.toDouble() ?? 0,
      pricePerSqft: (json['pricePerSqft'] as num?)?.toDouble() ?? 0,
      warehouseDepositPercent: (json['warehouseDepositPercent'] as num?)?.toDouble() ?? 10,
      civilDefensePerShabraRate: (json['civilDefensePerShabraRate'] as num?)?.toDouble() ?? 1000,
      contractCertFee: (json['contractCertFee'] as num?)?.toDouble() ?? 160,
      hemayaInsuranceRate: (json['hemayaInsuranceRate'] as num?)?.toDouble() ?? 1500,
      hemayaContractFeeRate: (json['hemayaContractFeeRate'] as num?)?.toDouble() ?? 500,
    );
  }
}
