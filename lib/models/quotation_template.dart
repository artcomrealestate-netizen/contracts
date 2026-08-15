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
  final int contractMonths;
  final int numberOfPayments;

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
    this.contractMonths = 12,
    required this.numberOfPayments,
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
    int? contractMonths,
    int? numberOfPayments,
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
      contractMonths: contractMonths ?? this.contractMonths,
      numberOfPayments: numberOfPayments ?? this.numberOfPayments,
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
        'contractMonths': contractMonths,
        'numberOfPayments': numberOfPayments,
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
      // Quotations/templates saved before the contract-period feature existed
      // don't have this key; they were always computed as a full year.
      contractMonths: (json['contractMonths'] as num?)?.toInt() ?? 12,
      numberOfPayments: (json['numberOfPayments'] ?? json['paymentTerms']) as int,
    );
  }
}
