class QuotationTemplate {
  final String id;
  final String templateName;
  final String roomType;
  final String contractType;
  final double priceMonth;
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

  const QuotationTemplate({
    required this.id,
    required this.templateName,
    required this.roomType,
    this.contractType = 'residential',
    required this.priceMonth,
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

  QuotationTemplate copyWith({
    String? templateName,
    String? roomType,
    String? contractType,
    double? priceMonth,
    double? cd,
    double? camera,
    bool? includeCd,
    bool? includeCamera,
    double? service,
    double? managementPercent,
    double? vatPercent,
    double? deposit,
    double? industrialDepositPercent,
    int? contractMonths,
    int? numberOfPayments,
    int? khana,
    String? shabraNumbers,
    int? shabraCount,
    double? area,
    double? pricePerSqft,
    double? warehouseDepositPercent,
    double? civilDefensePerShabraRate,
    double? contractCertFee,
    double? hemayaInsuranceRate,
    double? hemayaContractFeeRate,
  }) {
    return QuotationTemplate(
      id: id,
      templateName: templateName ?? this.templateName,
      roomType: roomType ?? this.roomType,
      contractType: contractType ?? this.contractType,
      priceMonth: priceMonth ?? this.priceMonth,
      cd: cd ?? this.cd,
      camera: camera ?? this.camera,
      includeCd: includeCd ?? this.includeCd,
      includeCamera: includeCamera ?? this.includeCamera,
      service: service ?? this.service,
      managementPercent: managementPercent ?? this.managementPercent,
      vatPercent: vatPercent ?? this.vatPercent,
      deposit: deposit ?? this.deposit,
      industrialDepositPercent: industrialDepositPercent ?? this.industrialDepositPercent,
      contractMonths: contractMonths ?? this.contractMonths,
      numberOfPayments: numberOfPayments ?? this.numberOfPayments,
      khana: khana ?? this.khana,
      shabraNumbers: shabraNumbers ?? this.shabraNumbers,
      shabraCount: shabraCount ?? this.shabraCount,
      area: area ?? this.area,
      pricePerSqft: pricePerSqft ?? this.pricePerSqft,
      warehouseDepositPercent: warehouseDepositPercent ?? this.warehouseDepositPercent,
      civilDefensePerShabraRate: civilDefensePerShabraRate ?? this.civilDefensePerShabraRate,
      contractCertFee: contractCertFee ?? this.contractCertFee,
      hemayaInsuranceRate: hemayaInsuranceRate ?? this.hemayaInsuranceRate,
      hemayaContractFeeRate: hemayaContractFeeRate ?? this.hemayaContractFeeRate,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'templateName': templateName,
        'roomType': roomType,
        'contractType': contractType,
        'priceMonth': priceMonth,
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

  factory QuotationTemplate.fromJson(Map<String, dynamic> json) {
    return QuotationTemplate(
      id: json['id'] as String,
      templateName: json['templateName'] as String,
      roomType: json['roomType'] as String,
      contractType: (json['contractType'] as String?) ?? 'residential',
      priceMonth: (json['priceMonth'] as num).toDouble(),
      cd: (json['cd'] as num).toDouble(),
      camera: (json['camera'] as num).toDouble(),
      includeCd: (json['includeCd'] as bool?) ?? true,
      includeCamera: (json['includeCamera'] as bool?) ?? true,
      service: (json['service'] as num?)?.toDouble() ?? 0,
      managementPercent: (json['managementPercent'] as num?)?.toDouble() ?? 0,
      vatPercent: (json['vatPercent'] as num?)?.toDouble() ?? 5,
      deposit: (json['deposit'] as num).toDouble(),
      industrialDepositPercent: (json['industrialDepositPercent'] as num?)?.toDouble() ?? 10,
      // Quotations/templates saved before the contract-period feature existed
      // don't have this key; they were always computed as a full year.
      contractMonths: (json['contractMonths'] as num?)?.toInt() ?? 12,
      numberOfPayments: (json['numberOfPayments'] ?? json['paymentTerms']) as int,
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
