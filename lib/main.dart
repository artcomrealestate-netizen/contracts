import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/environment.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/contracts_home_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/quotations/data/local_quotation_migrator.dart';
import 'features/quotations/presentation/quotation_providers.dart';
import 'models/quotation_template.dart';
import 'models/saved_quotation.dart';
import 'pdf/quotation_pdf_builder.dart';
import 'screens/archive_screen.dart';
import 'services/template_store.dart';

abstract class LogoPicker {
  Future<Uint8List?> pickLogo();
}

class ImagePickerLogoPicker implements LogoPicker {
  @override
  Future<Uint8List?> pickLogo() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (picked == null) return null;
    return picked.readAsBytes();
  }
}

abstract class PdfSharer {
  Future<void> sharePdf({required Object? bytes, required Object? filename});
}

class PrintingPdfSharer implements PdfSharer {
  @override
  Future<void> sharePdf({required Object? bytes, required Object? filename}) {
    final Uint8List pdfBytes;
    if (bytes is Uint8List) {
      pdfBytes = bytes;
    } else if (bytes is List<int>) {
      pdfBytes = Uint8List.fromList(bytes);
    } else {
      throw ArgumentError('bytes must be Uint8List or List<int>');
    }

    final fileName = filename is String ? filename : 'Quotation.pdf';
    return Printing.sharePdf(bytes: pdfBytes, filename: fileName);
  }
}

class AppSettings extends ChangeNotifier {
  static const _localeKey = 'app_locale';
  static const _companyNameKey = 'company_name';
  static const _companyPhoneKey = 'company_phone';
  static const _companyEmailKey = 'company_email';
  static const _companyWebsiteKey = 'company_website';
  static const _logoBytesKey = 'company_logo_bytes';
  static const _customNotesArKey = 'custom_notes_ar';
  static const _customNotesEnKey = 'custom_notes_en';

  Locale locale;
  String companyName;
  String companyPhone;
  String companyEmail;
  String companyWebsite;
  Uint8List? logoBytes;
  String? customNotesAr;
  String? customNotesEn;

  AppSettings({
    required this.locale,
    required this.companyName,
    required this.companyPhone,
    required this.companyEmail,
    required this.companyWebsite,
    this.logoBytes,
    this.customNotesAr,
    this.customNotesEn,
  });

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final localeCode = prefs.getString(_localeKey) ?? 'en';
    final logoBase64 = prefs.getString(_logoBytesKey);
    return AppSettings(
      locale: Locale(localeCode),
      companyName: prefs.getString(_companyNameKey) ?? 'AL-DAHHAN DEVELOPER',
      companyPhone: prefs.getString(_companyPhoneKey) ?? '0555439000',
      companyEmail: prefs.getString(_companyEmailKey) ?? 'louai@aldahandeveloper.com',
      companyWebsite: prefs.getString(_companyWebsiteKey) ?? 'www.aldahandeveloper.com',
      logoBytes: logoBase64 == null ? null : base64Decode(logoBase64),
      customNotesAr: prefs.getString(_customNotesArKey),
      customNotesEn: prefs.getString(_customNotesEnKey),
    );
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
    await prefs.setString(_companyNameKey, companyName);
    await prefs.setString(_companyPhoneKey, companyPhone);
    await prefs.setString(_companyEmailKey, companyEmail);
    await prefs.setString(_companyWebsiteKey, companyWebsite);
    if (logoBytes != null) {
      await prefs.setString(_logoBytesKey, base64Encode(logoBytes!));
    } else {
      await prefs.remove(_logoBytesKey);
    }
    if (customNotesAr != null) {
      await prefs.setString(_customNotesArKey, customNotesAr!);
    } else {
      await prefs.remove(_customNotesArKey);
    }
    if (customNotesEn != null) {
      await prefs.setString(_customNotesEnKey, customNotesEn!);
    } else {
      await prefs.remove(_customNotesEnKey);
    }
  }

  void updateLocale(Locale newLocale) {
    if (newLocale == locale) return;
    locale = newLocale;
    notifyListeners();
    _savePreferences();
  }

  Future<void> updateCompanySettings({
    required String name,
    required String phone,
    required String email,
    required String website,
  }) async {
    companyName = name;
    companyPhone = phone;
    companyEmail = email;
    companyWebsite = website;
    notifyListeners();
    await _savePreferences();
  }

  Future<void> updateLogoBytes(Uint8List? newLogoBytes) async {
    logoBytes = newLogoBytes;
    notifyListeners();
    await _savePreferences();
  }

  Future<void> updateCustomNotes({String? notesAr, String? notesEn}) async {
    customNotesAr = notesAr;
    customNotesEn = notesEn;
    notifyListeners();
    await _savePreferences();
  }
}

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return AppLocalizations(Localizations.localeOf(context));
  }

  bool get isArabic => locale.languageCode == 'ar';

  String get appTitle => isArabic ? 'حاسبة عرض السعر' : 'Quota Calculator';
  String get settingsTitle => isArabic ? 'الإعدادات' : 'Settings';
  String get languageLabel => isArabic ? 'اللغة' : 'Language';
  String get english => 'English';
  String get arabic => 'العربية';
  String get companyName => isArabic ? 'اسم الشركة' : 'Company Name';
  String get phoneNumber => isArabic ? 'رقم الهاتف' : 'Phone Number';
  String get emailAddress => isArabic ? 'البريد الإلكتروني' : 'Email Address';
  String get website => isArabic ? 'الموقع الإلكتروني' : 'Website';
  String get saveSettings => isArabic ? 'حفظ الإعدادات' : 'Save Settings';
  String get settingsSaved => isArabic ? 'تم حفظ الإعدادات' : 'Settings saved';
  String get companyLogo => isArabic ? 'شعار الشركة' : 'Company Logo';
  String get chooseLogo => isArabic ? 'اختيار شعار' : 'Choose Logo';
  String get resetLogo => isArabic ? 'استخدام الشعار الافتراضي' : 'Reset to Default';
  String get cancel => isArabic ? 'إلغاء' : 'Cancel';
  String get delete => isArabic ? 'حذف' : 'Delete';
  String get save => isArabic ? 'حفظ' : 'Save';
  // Templates
  String get templateLabel => isArabic ? 'القالب' : 'Template';
  String get selectTemplate => isArabic ? '-- اختر قالباً --' : '-- Select Template --';
  String get saveAsTemplate => isArabic ? 'حفظ كقالب' : 'Save as Template';
  String get manageTemplates => isArabic ? 'إدارة القوالب' : 'Manage Templates';
  String get templateName => isArabic ? 'اسم القالب' : 'Template Name';
  String get templateSaved => isArabic ? 'تم حفظ القالب' : 'Template saved';
  String get noTemplates => isArabic ? 'لا توجد قوالب محفوظة' : 'No saved templates';
  String get updateExistingTemplate => isArabic ? 'تحديث القالب الحالي بدلاً من إنشاء قالب جديد' : 'Update the currently selected template instead of creating a new one';

  /// The two built-in default templates (see [TemplateStore.defaultTemplates])
  /// get a translated display name; any custom template the user created
  /// keeps showing exactly the name they typed, in whatever language they typed it.
  String templateDisplayName(QuotationTemplate template) {
    switch (template.id) {
      case 'default-small':
        return isArabic ? 'غرفة عادية' : 'Normal Room';
      case 'default-vip':
        return isArabic ? 'غرفة مزدوجة' : 'Double Room';
      default:
        return template.templateName;
    }
  }
  // Archive
  String get archiveTitle => isArabic ? 'أرشيف عروض الأسعار' : 'Quotation Archive';
  String get newQuotation => isArabic ? 'فاتورة جديدة' : 'New Quotation';
  String get searchHint => isArabic ? 'ابحث بالاسم أو رقم العرض' : 'Search by name or quota number';
  String get noQuotations => isArabic ? 'لا توجد عروض أسعار محفوظة' : 'No saved quotations';
  String get shareQuotation => isArabic ? 'مشاركة PDF' : 'Share PDF';
  String get loadQuotation => isArabic ? 'تحميل البيانات' : 'Load Data';
  String get confirmDeleteTitle => isArabic ? 'تأكيد الحذف' : 'Confirm Delete';
  String get confirmDeleteMessage => isArabic ? 'هل أنت متأكد من حذف هذا العنصر؟ لا يمكن التراجع عن هذا الإجراء.' : 'Are you sure you want to delete this? This cannot be undone.';
  // PDF table
  String get tableDescription => isArabic ? 'البيان' : 'Description';
  String get currencySymbol => isArabic ? 'د.إ' : 'AED';
  String get tableAmount => isArabic ? 'المبلغ ($currencySymbol)' : 'Amount ($currencySymbol)';
  String get customerName => isArabic ? 'اسم العميل' : 'Customer Name';
  String get roomQuantity => isArabic ? 'العدد' : 'Quantity';
  String get pricePerMonth => isArabic ? 'السعر الشهري' : 'Price / Month';
  String get managementFee => isArabic ? 'نسبة الإدارة %' : 'Management Fee %';
  String get managementVat => isArabic ? 'الضريبة الإدارية' : 'Management VAT';
  String get cdCharge => isArabic ? 'رسوم الدفاع المدني (سنوي، للوحدة)' : 'C.D Charge (annual, per unit)';
  String get cameraFee => isArabic ? 'رسوم الكاميرا (سنوي، للوحدة)' : 'Camera Fee (annual, per unit)';
  String get contractTypeLabel => isArabic ? 'نوع العقد' : 'Contract Type';
  String get residentialContract => isArabic ? 'سكني' : 'Residential';
  String get commercialContract => isArabic ? 'تجاري' : 'Commercial';
  String get industrialContract => isArabic ? 'صناعي' : 'Industrial';
  String get warehouseContract => isArabic ? 'مستودع' : 'Warehouse';
  String get shopContract => isArabic ? 'محل' : 'Shop';
  String get industrialDepositPercentLabel => isArabic ? 'نسبة الوديعة (من الإيجار) %' : 'Deposit % (of rent)';
  String get khanaLabel => isArabic ? 'خانة' : 'Khana';
  String get shabraNumbersLabel => isArabic ? 'أرقام الشبرات' : 'Shabra Numbers';
  String get shabraCountLabel => isArabic ? 'عدد الشبرات' : 'Number of Shabras';
  String get areaLabel => isArabic ? 'المساحة' : 'Area';
  String get pricePerSqftLabel => isArabic ? 'السعر للقدم' : 'Price / sq ft';
  String get warehouseDepositPercentLabel => isArabic ? 'نسبة التأمين (من الإيجار) %' : 'Deposit % (of rent)';
  String get civilDefensePerShabraLabel => isArabic ? 'الدفاع المدني (للشبرة الواحدة)' : 'Civil Defense (per shabra)';
  String get contractCertFeeLabel => isArabic ? 'رسم تصديق العقد' : 'Contract Certification Fee';
  String get hemayaInsurancePerShabraLabel => isArabic ? 'رسوم حماية HEMAYA - تأمين (للشبرة الواحدة)' : 'HEMAYA Protection Insurance (per shabra)';
  String get hemayaContractFeePerShabraLabel => isArabic ? 'رسوم عقد حماية HEMAYA (للشبرة الواحدة)' : 'HEMAYA Protection Contract Fee (per shabra)';
  String get warehouseRentLabel => isArabic ? 'إجمالي الإيجار (المساحة × السعر للقدم)' : 'Rent Total (Area × Price/sq ft)';
  String get includeCd => isArabic ? 'تضمين رسوم الدفاع المدني' : 'Include Civil Defense fee';
  String get includeCamera => isArabic ? 'تضمين رسوم الكاميرا' : 'Include Camera fee';
  String get howCalculationWorks => isArabic ? 'طريقة الحساب' : 'How Calculations Work';
  String get close => isArabic ? 'إغلاق' : 'Close';
  String get calculationFormulaText => isArabic
      ? '1. إجمالي الإيجار = (السعر الشهري + الخدمات الشهرية) × مدة العقد بالأشهر × عدد الغرف — مش لازم تكون سنة كاملة، فيك تحطي 3 أو 6 أو 9 أشهر وبتنحسب صح.\n'
        '2. رسوم الإدارة = إجمالي الإيجار × نسبة الإدارة % (تُكتب حسب كل عرض سعر).\n'
        '3. الضريبة الإدارية = رسوم الإدارة × نسبة الضريبة % (افتراضي 5%، وقابلة للتعديل).\n'
        '4. الدفاع المدني = سعر الوحدة السنوي × (مدة العقد بالأشهر ÷ 12) × عدد الغرف، والكاميرا نفس الشي — هني رسوم سنوية، فعقد أقصر من سنة بياخذ بس النسبة المتناسبة معه (متلاً عقد 9 أشهر بياخذ 9/12 من الرسم السنوي). كل وحدة منهم إلها checkbox مستقل خاص فيها ("تضمين رسوم الدفاع المدني" و"تضمين رسوم الكاميرا")، فيك تفعّلي وحدة وتلغي التانية، ومنفصلين تماماً عن نوع العقد (سكني/تجاري). الوديعة المستردة وحدها ما بتتناسب مع الأشهر، لأنها مبلغ ثابت لمرة وحدة.\n'
        '5. السعر النهائي = إجمالي الإيجار + رسوم الإدارة + الضريبة الإدارية + الدفاع المدني + الكاميرا + الوديعة المستردة.\n'
        '6. الدفعات: التأمين والدفاع المدني والكاميرا ورسوم الإدارة وضريبتها كلها بتنحط مع الدفعة الأولى، وباقي إجمالي الإيجار بس بينقسم بالتساوي على باقي الدفعات.'
      : '1. Rent Total = (Price/Month + Monthly Services) × Contract Period (Months) × Quantity — it does not have to be a full year; enter 3, 6, or 9 months and it calculates correctly.\n'
        '2. Management Fee = Rent Total × Management % (entered per quotation).\n'
        '3. Management VAT = Management Fee × VAT % (defaults to 5%, editable).\n'
        '4. C.D = Annual Unit Price × (Contract Period in Months ÷ 12) × Quantity, and Camera the same way — these are annual fees, so a contract shorter than a year only bills the matching fraction (e.g. a 9-month contract bills 9/12 of the annual rate). Each has its own independent checkbox ("Include Civil Defense fee" / "Include Camera fee"), so you can turn one on and the other off, fully separate from Contract Type (residential/commercial). The Refundable Deposit alone is not prorated by months, since it is a one-time flat amount.\n'
        '5. Final Price = Rent Total + Management Fee + Management VAT + C.D + Camera + Refundable Deposit.\n'
        '6. Payments: the deposit, C.D, camera, management fee, and its VAT are all bundled into the first payment; only the remaining Rent Total is split evenly across the rest of the payments.';
  String get serviceCharge => isArabic ? 'الخدمات (شهرياً)' : 'Services (Monthly)';
  String get refundableDeposit => isArabic ? 'الوديعة المستردة (للوحدة)' : 'Refundable Deposit (per unit)';
  String get paymentSystem => isArabic ? 'نظام الدفع' : 'Payment System';
  String get numberOfPaymentsLabel => isArabic ? 'عدد الدفعات' : 'Number of Payments';
  String get singlePayment => isArabic ? 'دفعة واحدة' : 'Single Payment';
  String paymentCountOptionLabel(int count) =>
      count == 1 ? singlePayment : (isArabic ? '$count دفعات' : '$count Payments');
  String periodRentLabel(int months) =>
      isArabic ? 'إجمالي الإيجار ($months شهر)' : 'Rent Total ($months months)';
  String get contractPeriodLabel => isArabic ? 'مدة العقد (بالأشهر)' : 'Contract Period (Months)';
  String get minimumOneWarning => isArabic ? 'الحد الأدنى 1 — تم استخدام 1' : 'Minimum is 1 — using 1';
  String get negativeValueWarning => isArabic ? 'ما بينفع تكون القيمة سالبة — تم استخدام 0' : 'Cannot be negative — using 0';
  String get finalPrice => isArabic ? 'الإجمالي النهائي' : 'Final Price';
  String paymentLabel(int index) => isArabic ? 'الدفعة ${index + 1}' : 'Payment ${index + 1}';
  String get exportPdf => isArabic ? 'تصدير PDF ومشاركة' : 'Export PDF and Share';
  String get quotationOffer => isArabic ? 'عرض السعر' : 'QUOTATION OFFER';
  String get dateLabel => isArabic ? 'التاريخ' : 'Date';
  String get propertyType => isArabic ? 'نوع العقار / الغرفة' : 'Property / Room Type';
  String get paymentSchedule => isArabic ? 'جدول الدفعات' : 'Payment Schedule';
  String get notesAndConditions => isArabic ? 'ملاحظات وشروط' : 'Notes & Conditions';
  String get companyRepresentative => isArabic ? 'ممثل الشركة' : 'Company Representative';
  String get customerAcceptance => isArabic ? 'موافقة العميل' : 'Customer Acceptance';
  String get priceFor => isArabic ? 'السعر المذكور لـ' : 'The above-mentioned price is for';
  String get electricityDescription => isArabic ? 'يشمل التوريد الكهربائي على مدار الساعة، ويتم تشغيل المكيف حتى 12 ساعة يومياً طوال الأسبوع عدا الأحد والعطلات الرسمية.' : 'includes 24-hour electricity supply. However, the air conditioning unit will operate for up to 12 hours per day throughout the week, excluding Sundays and official public holidays.';
  String get maintenanceDescription => isArabic ? 'تشمل رسوم الإيجار التنظيف والصيانة اليومية للمقر.' : 'The rental fee includes daily cleaning and maintenance of the accommodation premises.';
  String get utilitiesDescription => isArabic ? 'يشمل الإيجار الكهرباء والمياه والصرف الصحي وتركيب مكيف جديد داخل الغرفة.' : 'The rental fee also includes electricity, water, sewage services, and the installation of a new air conditioning unit inside the room.';
  String get tenantResponsibility => isArabic ? 'يتحمل المستأجر رسوم الغاز والإنترنت الشهرية.' : 'The Tenant shall be responsible for the monthly payment of gas and internet charges.';
  String get notesArabicLabel => isArabic ? 'الملاحظات (عربي)' : 'Notes (Arabic)';
  String get notesEnglishLabel => isArabic ? 'الملاحظات (إنجليزي)' : 'Notes (English)';
  String get notesHelperText => isArabic
      ? 'كل سطر يصبح بنداً منفصلاً بالـ PDF. عدّلي أو احذفي أو ضيفي أسطر حسب الحاجة.'
      : 'Each line becomes a separate item in the PDF. Edit, delete, or add lines as needed.';
  String get resetToDefault => isArabic ? 'استعادة الافتراضي' : 'Reset to Default';

  static const String defaultNotesTemplateAr =
      '1. زيادة سنوية بنسبة 10% على العقد.\n'
      '2. رسوم الإدارة والدفاع المدني والكاميرا مستحقة سنوياً.\n'
      '3. الوديعة المستردة تدفع مرة واحدة فقط.\n'
      '4. السعر المذكور يشمل التوريد الكهربائي على مدار الساعة، ويتم تشغيل المكيف حتى 12 ساعة يومياً طوال الأسبوع عدا الأحد والعطلات الرسمية.\n'
      '5. تشمل رسوم الإيجار التنظيف والصيانة اليومية للمقر. صاحب العقار مسؤول عن تنظيف وصيانة المناطق المشتركة.\n'
      '6. يشمل الإيجار الكهرباء والمياه والصرف الصحي وتركيب مكيف جديد داخل الغرفة.\n'
      '7. يتحمل المستأجر رسوم الغاز والإنترنت الشهرية. وتستكمل هذه الرسوم خلال ثلاثة أيام عمل من بداية الشهر بعد استلام الفواتير.';

  static const String defaultNotesTemplateEn =
      '1. 10% annual increase on the contract.\n'
      '2. Management fees, Civil Defense, and camera fees are payable annually.\n'
      '3. The refundable deposit is payable one time only.\n'
      '4. The above-mentioned price includes 24-hour electricity supply. However, the air conditioning unit will operate for up to 12 hours per day throughout the week, excluding Sundays and official public holidays.\n'
      '5. The rental fee includes daily cleaning and maintenance of the accommodation premises. The Landlord shall be responsible for the cleaning and upkeep of all common areas and facilities outside the rented room, including but not limited to bathrooms, kitchens, corridors, and other shared areas.\n'
      '6. The rental fee also includes electricity, water, sewage services, and the installation of a new air conditioning unit inside the room.\n'
      '7. The Tenant shall be responsible for the monthly payment of gas and internet charges. Such payments must be settled within a maximum of three (3) working days from the beginning of each month, provided that the relevant invoices have been issued and submitted by the Landlord.';

  String get defaultNotesTemplate => isArabic ? defaultNotesTemplateAr : defaultNotesTemplateEn;

  List<String> dynamicNotes({
    required double deposit,
    required double managementFee,
    required double cd,
    required double camera,
    required int contractPeriodMonths,
    required int roomQuantity,
  }) {
    final List<String> notes = [];
    if (contractPeriodMonths > 12) {
      notes.add(isArabic ? '1. زيادة سنوية بنسبة 10% على العقد.' : '1. 10% annual increase on the contract.');
    }
    if (managementFee > 0 || cd > 0 || camera > 0) {
      final feeNamesAr = <String>[if (managementFee > 0) 'رسوم الإدارة', if (cd > 0) 'الدفاع المدني', if (camera > 0) 'الكاميرا'];
      final feeNamesEn = <String>[if (managementFee > 0) 'Management fees', if (cd > 0) 'Civil Defense', if (camera > 0) 'camera'];
      final arText = feeNamesAr.length == 1
          ? feeNamesAr.first
          : '${feeNamesAr.sublist(0, feeNamesAr.length - 1).join('، ')} و${feeNamesAr.last}';
      final enText = feeNamesEn.length == 1
          ? feeNamesEn.first
          : '${feeNamesEn.sublist(0, feeNamesEn.length - 1).join(', ')}, and ${feeNamesEn.last}';
      notes.add(isArabic ? '2. $arText مستحقة سنوياً.' : '2. $enText are payable annually.');
    }
    if (deposit > 0) {
      notes.add(isArabic ? '3. الوديعة المستردة تدفع مرة واحدة فقط.' : '3. The refundable deposit is payable one time only.');
    }
    final roomText = roomQuantity == 1 ? (isArabic ? 'غرفة واحدة' : 'one room') : '$roomQuantity ${isArabic ? 'غرف' : 'rooms'}';
    notes.add(isArabic
        ? '4. $priceFor $roomText ويشمل التوريد الكهربائي على مدار الساعة. $electricityDescription'
        : '4. $priceFor $roomText and $electricityDescription');
    notes.add(isArabic
        ? '5. $maintenanceDescription صاحب العقار مسؤول عن تنظيف وصيانة المناطق المشتركة.'
        : '5. $maintenanceDescription The Landlord shall be responsible for the cleaning and upkeep of all common areas and facilities outside the rented room, including but not limited to bathrooms, kitchens, corridors, and other shared areas.');
    notes.add(isArabic ? '6. $utilitiesDescription' : '6. $utilitiesDescription');
    notes.add(isArabic
        ? '7. $tenantResponsibility وتستكمل هذه الرسوم خلال ثلاثة أيام عمل من بداية الشهر بعد استلام الفواتير.'
        : '7. $tenantResponsibility Such payments must be settled within a maximum of three (3) working days from the beginning of each month, provided that the relevant invoices have been issued and submitted by the Landlord.');
    return notes;
  }

  /// Returns [customNotes] split into lines if provided and non-empty,
  /// otherwise falls back to the computed [dynamicNotes].
  List<String> effectiveNotes({
    required String? customNotes,
    required double deposit,
    required double managementFee,
    required double cd,
    required double camera,
    required int contractPeriodMonths,
    required int roomQuantity,
  }) {
    if (customNotes != null && customNotes.trim().isNotEmpty) {
      return customNotes.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
    }
    return dynamicNotes(
      deposit: deposit,
      managementFee: managementFee,
      cd: cd,
      camera: camera,
      contractPeriodMonths: contractPeriodMonths,
      roomQuantity: roomQuantity,
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  final templateStore = await TemplateStore.load();
  // Quotations now live in Firestore (createdBy-scoped, see
  // features/quotations), so unlike before, the whole app — not just the
  // Contract System module — needs a working Firebase connection.
  Object? firebaseInitError;
  try {
    await Firebase.initializeApp(options: Environment.firebaseOptions);
  } catch (e) {
    firebaseInitError = e;
  }
  runApp(ProviderScope(
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSettings>.value(value: settings),
        ChangeNotifierProvider<TemplateStore>.value(value: templateStore),
      ],
      child: QuotaApp(firebaseInitError: firebaseInitError),
    ),
  ));
}

class QuotaApp extends StatelessWidget {
  final Object? firebaseInitError;

  const QuotaApp({super.key, this.firebaseInitError});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettings>(
      builder: (context, settings, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: AppLocalizations(settings.locale).appTitle,
          locale: settings.locale,
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
          ),
          home: firebaseInitError != null
              ? _FirebaseInitErrorScreen(error: firebaseInitError!)
              : const _AppRoot(),
        );
      },
    );
  }
}

class _FirebaseInitErrorScreen extends StatelessWidget {
  final Object error;

  const _FirebaseInitErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not connect to the server. Check your internet connection and restart the app.\n\n$error',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

/// The whole app is now auth-gated (login is mandatory — the quotation
/// archive lives in Firestore, not just the Contract System module).
class _AppRoot extends ConsumerWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    return authState.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => LoginScreen(errorMessage: error.toString()),
      data: (user) {
        if (user == null) return const LoginScreen();
        return _MigrateAndShowCalculator(userId: user.id);
      },
    );
  }
}

/// One-time, fire-and-forget import of any quotations this device saved
/// locally before quotation storage moved to Firestore (see
/// LocalQuotationMigrator) — the calculator itself doesn't wait on it.
class _MigrateAndShowCalculator extends ConsumerStatefulWidget {
  final String userId;

  const _MigrateAndShowCalculator({required this.userId});

  @override
  ConsumerState<_MigrateAndShowCalculator> createState() => _MigrateAndShowCalculatorState();
}

class _MigrateAndShowCalculatorState extends ConsumerState<_MigrateAndShowCalculator> {
  @override
  void initState() {
    super.initState();
    LocalQuotationMigrator().migrateIfNeeded(
      repository: ref.read(quotationRepositoryProvider),
      migratedByUid: widget.userId,
    );
  }

  @override
  Widget build(BuildContext context) => const QuotaCalculatorScreen();
}

class QuotaCalculatorScreen extends ConsumerStatefulWidget {
  final PdfSharer? pdfSharer;
  final AssetBundle? assetBundle;

  const QuotaCalculatorScreen({super.key, this.pdfSharer, this.assetBundle});

  @override
  ConsumerState<QuotaCalculatorScreen> createState() => _QuotaCalculatorScreenState();
}

class _QuotaCalculatorScreenState extends ConsumerState<QuotaCalculatorScreen> {
  final _customerNameController = TextEditingController();
  final _roomQuantityController = TextEditingController();
  final _priceMonthController = TextEditingController();
  final _contractMonthsController = TextEditingController(text: '12');
  final _cdController = TextEditingController();
  final _cameraController = TextEditingController();
  final _serviceController = TextEditingController();
  final _managementController = TextEditingController();
  final _vatPercentController = TextEditingController(text: formatFieldValue(defaultVatPercent));
  final _depositController = TextEditingController();
  final _industrialDepositPercentController = TextEditingController(text: formatFieldValue(10));

  // Warehouse/shabra quotation fields.
  final _khanaController = TextEditingController();
  final _shabraNumbersController = TextEditingController();
  final _shabraCountController = TextEditingController();
  final _areaController = TextEditingController();
  final _pricePerSqftController = TextEditingController();
  final _warehouseDepositPercentController = TextEditingController(text: formatFieldValue(10));
  final _civilDefensePerShabraController = TextEditingController(text: formatFieldValue(1000));
  final _contractCertFeeController = TextEditingController(text: formatFieldValue(160));
  final _hemayaInsuranceController = TextEditingController(text: formatFieldValue(1500));
  final _hemayaContractFeeController = TextEditingController(text: formatFieldValue(500));

  final Key customerNameKey = const Key('customerName');
  final Key roomQuantityKey = const Key('roomQuantity');
  final Key priceMonthKey = const Key('priceMonth');
  final Key contractMonthsKey = const Key('contractMonths');
  final Key cdKey = const Key('cd');
  final Key cameraKey = const Key('camera');
  final Key serviceKey = const Key('service');
  final Key managementKey = const Key('management');
  final Key vatPercentKey = const Key('vatPercent');
  final Key depositKey = const Key('deposit');
  final Key industrialDepositPercentKey = const Key('industrialDepositPercent');

  final Key khanaKey = const Key('khana');
  final Key shabraNumbersKey = const Key('shabraNumbers');
  final Key shabraCountKey = const Key('shabraCount');
  final Key areaKey = const Key('area');
  final Key pricePerSqftKey = const Key('pricePerSqft');
  final Key warehouseDepositPercentKey = const Key('warehouseDepositPercent');
  final Key civilDefensePerShabraKey = const Key('civilDefensePerShabra');
  final Key contractCertFeeKey = const Key('contractCertFee');
  final Key hemayaInsuranceKey = const Key('hemayaInsurance');
  final Key hemayaContractFeeKey = const Key('hemayaContractFee');

  static const List<int> paymentCountOptions = [1, 2, 3, 4, 6, 12];

  String _selectedRoomType = 'Small';
  String _contractType = 'residential';
  bool _includeCd = true;
  bool _includeCamera = true;
  int _numberOfPayments = 2;
  int _contractMonths = 12;
  double _yearlyPrice = 0;
  double _managementFeeAmount = 0;
  double _vatAmount = 0;
  double _cdAmount = 0;
  double _cameraAmount = 0;
  double _depositAmount = 0;
  double _contractCertFeeAmount = 0;
  double _hemayaInsuranceAmount = 0;
  double _hemayaContractFeeAmount = 0;
  double _finalPrice = 0;
  List<double> _payments = [];
  String? _selectedTemplateId;

  @override
  void initState() {
    super.initState();
    _calculateQuota();
  }

  void _applyTemplate(QuotationTemplate template) {
    setState(() {
      _selectedTemplateId = template.id;
      _selectedRoomType = template.roomType;
      _contractType = template.contractType;
      _includeCd = template.includeCd;
      _includeCamera = template.includeCamera;
      _priceMonthController.text = formatFieldValue(template.priceMonth);
      _cdController.text = formatFieldValue(template.cd);
      _cameraController.text = formatFieldValue(template.camera);
      _serviceController.text = formatFieldValue(template.service);
      _managementController.text = formatFieldValue(template.managementPercent);
      _vatPercentController.text = formatFieldValue(template.vatPercent);
      _depositController.text = formatFieldValue(template.deposit);
      _industrialDepositPercentController.text = formatFieldValue(template.industrialDepositPercent);
      _contractMonthsController.text = template.contractMonths.toString();
      _numberOfPayments = template.numberOfPayments;
      _khanaController.text = template.khana.toString();
      _shabraNumbersController.text = template.shabraNumbers;
      _shabraCountController.text = template.shabraCount.toString();
      _areaController.text = formatFieldValue(template.area);
      _pricePerSqftController.text = formatFieldValue(template.pricePerSqft);
      _warehouseDepositPercentController.text = formatFieldValue(template.warehouseDepositPercent);
      _civilDefensePerShabraController.text = formatFieldValue(template.civilDefensePerShabraRate);
      _contractCertFeeController.text = formatFieldValue(template.contractCertFee);
      _hemayaInsuranceController.text = formatFieldValue(template.hemayaInsuranceRate);
      _hemayaContractFeeController.text = formatFieldValue(template.hemayaContractFeeRate);
    });
    _calculateQuota();
  }

  void _loadQuotation(SavedQuotation quotation) {
    setState(() {
      _selectedTemplateId = null;
      _customerNameController.text = quotation.customerName;
      _roomQuantityController.text = quotation.quantity.toString();
      _selectedRoomType = quotation.roomType;
      _contractType = quotation.contractType;
      _includeCd = quotation.includeCd;
      _includeCamera = quotation.includeCamera;
      _priceMonthController.text = formatFieldValue(quotation.priceMonth);
      // quotation.cd/camera are the frozen historical totals; the input
      // fields expect an annual per-unit price, so divide back out by both
      // quantity and the months fraction that was applied when they were
      // first prorated (see calculateProratedFee) to recover that rate.
      final unitDivisor = quotation.quantity > 0 ? quotation.quantity : 1;
      final monthsFraction = quotation.contractMonths / 12;
      _cdController.text = formatFieldValue(quotation.cd / (unitDivisor * monthsFraction));
      _cameraController.text = formatFieldValue(quotation.camera / (unitDivisor * monthsFraction));
      _serviceController.text = formatFieldValue(quotation.service);
      _managementController.text = formatFieldValue(quotation.managementPercent);
      _vatPercentController.text = formatFieldValue(quotation.vatPercent);
      _depositController.text = formatFieldValue(quotation.deposit / unitDivisor);
      _industrialDepositPercentController.text = formatFieldValue(quotation.industrialDepositPercent);
      _contractMonthsController.text = quotation.contractMonths.toString();
      _numberOfPayments = quotation.numberOfPayments;
      // Warehouse fields are stored as raw rates (unlike cd/camera/deposit
      // above), so they're restored with a direct assignment, no math.
      _khanaController.text = quotation.khana.toString();
      _shabraNumbersController.text = quotation.shabraNumbers;
      _shabraCountController.text = quotation.shabraCount.toString();
      _areaController.text = formatFieldValue(quotation.area);
      _pricePerSqftController.text = formatFieldValue(quotation.pricePerSqft);
      _warehouseDepositPercentController.text = formatFieldValue(quotation.warehouseDepositPercent);
      _civilDefensePerShabraController.text = formatFieldValue(quotation.civilDefensePerShabraRate);
      _contractCertFeeController.text = formatFieldValue(quotation.contractCertFee);
      _hemayaInsuranceController.text = formatFieldValue(quotation.hemayaInsuranceRate);
      _hemayaContractFeeController.text = formatFieldValue(quotation.hemayaContractFeeRate);
    });
    _calculateQuota();
  }

  void _newQuotation() {
    setState(() {
      _selectedTemplateId = null;
      _customerNameController.clear();
      _roomQuantityController.clear();
      _priceMonthController.clear();
      _cdController.clear();
      _cameraController.clear();
      _serviceController.clear();
      _managementController.clear();
      _vatPercentController.text = formatFieldValue(defaultVatPercent);
      _depositController.clear();
      _industrialDepositPercentController.text = formatFieldValue(10);
      _contractMonthsController.text = '12';
      _selectedRoomType = 'Small';
      _contractType = 'residential';
      _includeCd = true;
      _includeCamera = true;
      _numberOfPayments = 2;
      _khanaController.clear();
      _shabraNumbersController.clear();
      _shabraCountController.clear();
      _areaController.clear();
      _pricePerSqftController.clear();
      _warehouseDepositPercentController.text = formatFieldValue(10);
      _civilDefensePerShabraController.text = formatFieldValue(1000);
      _contractCertFeeController.text = formatFieldValue(160);
      _hemayaInsuranceController.text = formatFieldValue(1500);
      _hemayaContractFeeController.text = formatFieldValue(500);
    });
    _calculateQuota();
  }

  Future<void> _openArchive() async {
    final result = await Navigator.of(context).push<SavedQuotation>(
      MaterialPageRoute(
        builder: (_) => ArchiveScreen(pdfSharer: widget.pdfSharer, assetBundle: widget.assetBundle),
      ),
    );
    if (result != null) {
      _loadQuotation(result);
    }
  }

  Future<void> _saveAsTemplate() async {
    final strings = AppLocalizations.of(context);
    final templateStore = Provider.of<TemplateStore>(context, listen: false);
    final matchingTemplates = templateStore.templates.where((t) => t.id == _selectedTemplateId);
    final existing = matchingTemplates.isEmpty ? null : matchingTemplates.first;
    final nameController = TextEditingController(text: existing?.templateName ?? '');
    var updateExisting = existing != null;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(strings.saveAsTemplate),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('templateNameField'),
                controller: nameController,
                decoration: InputDecoration(labelText: strings.templateName),
                autofocus: true,
                onChanged: (_) => setDialogState(() {}),
              ),
              if (existing != null)
                CheckboxListTile(
                  key: const Key('updateExistingCheckbox'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(strings.updateExistingTemplate, style: const TextStyle(fontSize: 13)),
                  value: updateExisting,
                  onChanged: (value) => setDialogState(() => updateExisting = value ?? false),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(strings.cancel),
            ),
            TextButton(
              key: const Key('confirmSaveTemplateButton'),
              onPressed: nameController.text.trim().isEmpty ? null : () => Navigator.of(dialogContext).pop(true),
              child: Text(strings.save),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) return;

    final template = QuotationTemplate(
      id: (existing != null && updateExisting) ? existing.id : DateTime.now().microsecondsSinceEpoch.toString(),
      templateName: nameController.text.trim(),
      roomType: _selectedRoomType,
      contractType: _contractType,
      priceMonth: double.tryParse(_priceMonthController.text) ?? 0,
      cd: double.tryParse(_cdController.text) ?? 0,
      camera: double.tryParse(_cameraController.text) ?? 0,
      includeCd: _includeCd,
      includeCamera: _includeCamera,
      service: double.tryParse(_serviceController.text) ?? 0,
      managementPercent: double.tryParse(_managementController.text) ?? 0,
      vatPercent: double.tryParse(_vatPercentController.text) ?? defaultVatPercent,
      deposit: double.tryParse(_depositController.text) ?? 0,
      industrialDepositPercent: double.tryParse(_industrialDepositPercentController.text) ?? 10,
      contractMonths: int.tryParse(_contractMonthsController.text) ?? 12,
      numberOfPayments: _numberOfPayments,
      khana: int.tryParse(_khanaController.text) ?? 0,
      shabraNumbers: _shabraNumbersController.text,
      shabraCount: int.tryParse(_shabraCountController.text) ?? 1,
      area: double.tryParse(_areaController.text) ?? 0,
      pricePerSqft: double.tryParse(_pricePerSqftController.text) ?? 0,
      warehouseDepositPercent: double.tryParse(_warehouseDepositPercentController.text) ?? 10,
      civilDefensePerShabraRate: double.tryParse(_civilDefensePerShabraController.text) ?? 1000,
      contractCertFee: double.tryParse(_contractCertFeeController.text) ?? 160,
      hemayaInsuranceRate: double.tryParse(_hemayaInsuranceController.text) ?? 1500,
      hemayaContractFeeRate: double.tryParse(_hemayaContractFeeController.text) ?? 500,
    );
    await templateStore.upsert(template);
    setState(() => _selectedTemplateId = template.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).templateSaved)),
      );
    }
  }

  Future<void> _manageTemplates() async {
    final strings = AppLocalizations.of(context);
    final templateStore = Provider.of<TemplateStore>(context, listen: false);
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final templates = templateStore.templates;
          return SafeArea(
            child: templates.isEmpty
                ? Padding(padding: const EdgeInsets.all(24), child: Text(strings.noTemplates))
                : ListView(
                    shrinkWrap: true,
                    children: templates
                        .map((template) => ListTile(
                              key: Key('manageTemplateTile_${template.id}'),
                              title: Text(strings.templateDisplayName(template)),
                              trailing: IconButton(
                                key: Key('deleteTemplateButton_${template.id}'),
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  await templateStore.delete(template.id);
                                  if (_selectedTemplateId == template.id) {
                                    setState(() => _selectedTemplateId = null);
                                  }
                                  setSheetState(() {});
                                },
                              ),
                            ))
                        .toList(),
                  ),
          );
        },
      ),
    );
  }

  /// Payment counts that make sense for the current contract length — never
  /// more installments than there are months, otherwise a single payment
  /// could end up covering less than a month of rent.
  List<int> get _availablePaymentCounts =>
      paymentCountOptions.where((count) => count <= _contractMonths).toList();

  void _calculateQuota() {
    setState(() {
      _contractMonths = clampMinOne(_contractMonthsController.text).toInt();

      if (_contractType == 'warehouse') {
        final area = clampNonNegative(_areaController.text);
        final pricePerSqft = clampNonNegative(_pricePerSqftController.text);
        final shabraCount = clampMinOne(_shabraCountController.text).toInt();
        final managementPercent = clampNonNegative(_managementController.text);
        final vatPercent = clampNonNegative(_vatPercentController.text);
        final depositPercent = clampNonNegative(_warehouseDepositPercentController.text);
        final cdRate = clampNonNegative(_civilDefensePerShabraController.text);
        final contractCertFee = clampNonNegative(_contractCertFeeController.text);
        final hemayaInsuranceRate = clampNonNegative(_hemayaInsuranceController.text);
        final hemayaContractFeeRate = clampNonNegative(_hemayaContractFeeController.text);

        _yearlyPrice = calculateWarehouseRent(pricePerSqft, area);
        _managementFeeAmount = calculateManagementFee(_yearlyPrice, managementPercent);
        _cdAmount = calculateWarehouseCivilDefense(cdRate, shabraCount);
        _cameraAmount = 0;
        _contractCertFeeAmount = contractCertFee;
        _hemayaInsuranceAmount = calculateHemayaInsurance(hemayaInsuranceRate, shabraCount);
        _hemayaContractFeeAmount = calculateHemayaContractFee(hemayaContractFeeRate, shabraCount);
        _depositAmount = calculatePercentOfRent(_yearlyPrice, depositPercent);
        _vatAmount = calculateWarehouseVat(_yearlyPrice, contractCertFee, _managementFeeAmount, vatPercent);
        _finalPrice = calculateWarehouseFinalPrice(
          totalRent: _yearlyPrice,
          managementFee: _managementFeeAmount,
          civilDefense: _cdAmount,
          contractCertFee: _contractCertFeeAmount,
          hemayaInsurance: _hemayaInsuranceAmount,
          hemayaContractFee: _hemayaContractFeeAmount,
          deposit: _depositAmount,
          vat: _vatAmount,
        );
        // Same rule as rooms: everything except the rent itself bundles into
        // the first installment; only the rent splits evenly across the rest.
        final firstPaymentExtra = _managementFeeAmount + _cdAmount + _contractCertFeeAmount +
            _hemayaInsuranceAmount + _hemayaContractFeeAmount + _depositAmount + _vatAmount;
        if (!_availablePaymentCounts.contains(_numberOfPayments)) {
          _numberOfPayments = _availablePaymentCounts.isNotEmpty ? _availablePaymentCounts.last : 1;
        }
        _payments = splitPayments(_yearlyPrice, numberOfPayments: _numberOfPayments, firstPaymentExtra: firstPaymentExtra);
        return;
      }

      final qty = clampMinOne(_roomQuantityController.text);
      final priceMonth = clampNonNegative(_priceMonthController.text);
      final cdUnit = clampNonNegative(_cdController.text);
      final cameraUnit = clampNonNegative(_cameraController.text);
      final service = clampNonNegative(_serviceController.text);
      final managementPercent = clampNonNegative(_managementController.text);
      final vatPercent = clampNonNegative(_vatPercentController.text);
      final cd = _includeCd ? calculateProratedFee(cdUnit, _contractMonths, qty) : 0.0;
      final camera = _includeCamera ? calculateProratedFee(cameraUnit, _contractMonths, qty) : 0.0;
      _yearlyPrice = calculateBasePrice(priceMonth, service, qty.toInt(), months: _contractMonths);
      final deposit = _contractType == 'industrial'
          ? calculatePercentOfRent(_yearlyPrice, clampNonNegative(_industrialDepositPercentController.text))
          : clampNonNegative(_depositController.text) * qty;
      _managementFeeAmount = calculateManagementFee(_yearlyPrice, managementPercent);
      _vatAmount = calculateManagementVat(_managementFeeAmount, vatPercent);
      _cdAmount = cd;
      _cameraAmount = camera;
      _depositAmount = deposit;
      _contractCertFeeAmount = 0;
      _hemayaInsuranceAmount = 0;
      _hemayaContractFeeAmount = 0;
      _finalPrice = calculateFinalPrice(_yearlyPrice, _vatAmount, cd, camera, _managementFeeAmount, deposit);
      // Insurance/deposit, C.D, management fee + its VAT, and camera are all
      // collected upfront with the first installment; only the rent itself
      // (the rooms payment) is spread evenly across the installments.
      final firstPaymentExtra = _vatAmount + cd + camera + _managementFeeAmount + deposit;
      // If the contract got shorter than the previously chosen number of
      // payments, fall back to the longest option that still fits.
      if (!_availablePaymentCounts.contains(_numberOfPayments)) {
        _numberOfPayments = _availablePaymentCounts.isNotEmpty ? _availablePaymentCounts.last : 1;
      }
      _payments = splitPayments(_yearlyPrice, numberOfPayments: _numberOfPayments, firstPaymentExtra: firstPaymentExtra);
    });
  }

  Widget _buildRoomFields(AppLocalizations strings) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: const Key('propertyTypeDropdown'),
                initialValue: _selectedRoomType,
                decoration: InputDecoration(labelText: strings.propertyType),
                items: ['Small', 'Medium', 'Large', 'Warehouse', 'Shop'].map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (val) => setState(() => _selectedRoomType = val!),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: roomQuantityKey,
                controller: _roomQuantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: strings.roomQuantity,
                  errorText: isBelowMinimumOne(_roomQuantityController.text) ? strings.minimumOneWarning : null,
                ),
                onChanged: (_) => _calculateQuota(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          key: serviceKey,
          controller: _serviceController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: strings.serviceCharge,
            errorText: isNegativeInput(_serviceController.text) ? strings.negativeValueWarning : null,
          ),
          onChanged: (_) => _calculateQuota(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: priceMonthKey,
                controller: _priceMonthController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: strings.pricePerMonth,
                  errorText: isNegativeInput(_priceMonthController.text) ? strings.negativeValueWarning : null,
                ),
                onChanged: (_) => _calculateQuota(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: contractMonthsKey,
                controller: _contractMonthsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: strings.contractPeriodLabel,
                  errorText: isBelowMinimumOne(_contractMonthsController.text) ? strings.minimumOneWarning : null,
                ),
                onChanged: (_) => _calculateQuota(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: managementKey,
                controller: _managementController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: strings.managementFee,
                  suffixText: '%',
                  errorText: isNegativeInput(_managementController.text) ? strings.negativeValueWarning : null,
                ),
                onChanged: (_) => _calculateQuota(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: vatPercentKey,
                controller: _vatPercentController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: strings.managementVat,
                  suffixText: '%',
                  errorText: isNegativeInput(_vatPercentController.text) ? strings.negativeValueWarning : null,
                ),
                onChanged: (_) => _calculateQuota(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        CheckboxListTile(
          key: const Key('includeCdCheckbox'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(strings.includeCd),
          value: _includeCd,
          onChanged: (checked) {
            setState(() => _includeCd = checked ?? true);
            _calculateQuota();
          },
        ),
        if (_includeCd) ...[
          TextField(
            key: cdKey,
            controller: _cdController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: strings.cdCharge,
              errorText: isNegativeInput(_cdController.text) ? strings.negativeValueWarning : null,
            ),
            onChanged: (_) => _calculateQuota(),
          ),
          const SizedBox(height: 12),
        ],
        CheckboxListTile(
          key: const Key('includeCameraCheckbox'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(strings.includeCamera),
          value: _includeCamera,
          onChanged: (checked) {
            setState(() => _includeCamera = checked ?? true);
            _calculateQuota();
          },
        ),
        if (_includeCamera) ...[
          TextField(
            key: cameraKey,
            controller: _cameraController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: strings.cameraFee,
              errorText: isNegativeInput(_cameraController.text) ? strings.negativeValueWarning : null,
            ),
            onChanged: (_) => _calculateQuota(),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 12),
        _contractType == 'industrial'
            ? TextField(
                key: industrialDepositPercentKey,
                controller: _industrialDepositPercentController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: strings.industrialDepositPercentLabel,
                  suffixText: '%',
                  errorText: isNegativeInput(_industrialDepositPercentController.text) ? strings.negativeValueWarning : null,
                ),
                onChanged: (_) => _calculateQuota(),
              )
            : TextField(
                key: depositKey,
                controller: _depositController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: strings.refundableDeposit,
                  errorText: isNegativeInput(_depositController.text) ? strings.negativeValueWarning : null,
                ),
                onChanged: (_) => _calculateQuota(),
              ),
      ],
    );
  }

  Widget _buildWarehouseFields(AppLocalizations strings) {
    Widget numberField(Key key, TextEditingController controller, String label, {String? suffixText}) {
      return TextField(
        key: key,
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffixText,
          errorText: isNegativeInput(controller.text) ? strings.negativeValueWarning : null,
        ),
        onChanged: (_) => _calculateQuota(),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                key: khanaKey,
                controller: _khanaController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: strings.khanaLabel),
                onChanged: (_) => _calculateQuota(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: shabraNumbersKey,
                controller: _shabraNumbersController,
                decoration: InputDecoration(labelText: strings.shabraNumbersLabel),
                onChanged: (_) => _calculateQuota(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: shabraCountKey,
                controller: _shabraCountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: strings.shabraCountLabel,
                  errorText: isBelowMinimumOne(_shabraCountController.text) ? strings.minimumOneWarning : null,
                ),
                onChanged: (_) => _calculateQuota(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: numberField(areaKey, _areaController, strings.areaLabel)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: numberField(pricePerSqftKey, _pricePerSqftController, strings.pricePerSqftLabel)),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: contractMonthsKey,
                controller: _contractMonthsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: strings.contractPeriodLabel,
                  errorText: isBelowMinimumOne(_contractMonthsController.text) ? strings.minimumOneWarning : null,
                ),
                onChanged: (_) => _calculateQuota(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: numberField(managementKey, _managementController, strings.managementFee, suffixText: '%')),
            const SizedBox(width: 10),
            Expanded(child: numberField(vatPercentKey, _vatPercentController, strings.managementVat, suffixText: '%')),
          ],
        ),
        const SizedBox(height: 12),
        numberField(warehouseDepositPercentKey, _warehouseDepositPercentController, strings.warehouseDepositPercentLabel, suffixText: '%'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: numberField(civilDefensePerShabraKey, _civilDefensePerShabraController, strings.civilDefensePerShabraLabel)),
            const SizedBox(width: 10),
            Expanded(child: numberField(contractCertFeeKey, _contractCertFeeController, strings.contractCertFeeLabel)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: numberField(hemayaInsuranceKey, _hemayaInsuranceController, strings.hemayaInsurancePerShabraLabel)),
            const SizedBox(width: 10),
            Expanded(child: numberField(hemayaContractFeeKey, _hemayaContractFeeController, strings.hemayaContractFeePerShabraLabel)),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildRoomResultRows(AppLocalizations strings) {
    return [
      _buildResultRow('${strings.periodRentLabel(_contractMonths)}:', '${formatAmount(_yearlyPrice)} ${strings.currencySymbol}'),
      _buildResultRow(
        '${strings.managementFee} (${formatFieldValue(double.tryParse(_managementController.text) ?? 0)}%):',
        '${formatAmount(_managementFeeAmount)} ${strings.currencySymbol}',
      ),
      _buildResultRow(
        '${strings.managementVat} (${formatFieldValue(double.tryParse(_vatPercentController.text) ?? 0)}%):',
        '${formatAmount(_vatAmount)} ${strings.currencySymbol}',
      ),
      if (_includeCd) _buildResultRow('${strings.cdCharge}:', '${formatAmount(_cdAmount)} ${strings.currencySymbol}'),
      if (_includeCamera) _buildResultRow('${strings.cameraFee}:', '${formatAmount(_cameraAmount)} ${strings.currencySymbol}'),
      _buildResultRow(
        _contractType == 'industrial' ? '${strings.industrialDepositPercentLabel}:' : '${strings.refundableDeposit}:',
        '${formatAmount(_depositAmount)} ${strings.currencySymbol}',
      ),
    ];
  }

  List<Widget> _buildWarehouseResultRows(AppLocalizations strings) {
    return [
      _buildResultRow('${strings.warehouseRentLabel}:', '${formatAmount(_yearlyPrice)} ${strings.currencySymbol}'),
      _buildResultRow(
        '${strings.managementFee} (${formatFieldValue(double.tryParse(_managementController.text) ?? 0)}%):',
        '${formatAmount(_managementFeeAmount)} ${strings.currencySymbol}',
      ),
      _buildResultRow(
        '${strings.managementVat} (${formatFieldValue(double.tryParse(_vatPercentController.text) ?? 0)}%):',
        '${formatAmount(_vatAmount)} ${strings.currencySymbol}',
      ),
      _buildResultRow('${strings.civilDefensePerShabraLabel}:', '${formatAmount(_cdAmount)} ${strings.currencySymbol}'),
      _buildResultRow('${strings.contractCertFeeLabel}:', '${formatAmount(_contractCertFeeAmount)} ${strings.currencySymbol}'),
      _buildResultRow('${strings.hemayaInsurancePerShabraLabel}:', '${formatAmount(_hemayaInsuranceAmount)} ${strings.currencySymbol}'),
      _buildResultRow('${strings.hemayaContractFeePerShabraLabel}:', '${formatAmount(_hemayaContractFeeAmount)} ${strings.currencySymbol}'),
      _buildResultRow('${strings.warehouseDepositPercentLabel}:', '${formatAmount(_depositAmount)} ${strings.currencySymbol}'),
    ];
  }

  Future<void> _generateAndSharePDF() async {
    final settings = Provider.of<AppSettings>(context, listen: false);
    final quotationRepository = ref.read(quotationRepositoryProvider);
    // .future (not .value!) so this works even if AuthController hasn't
    // finished its very first resolve yet — it always has by the time a
    // real user reaches this screen (behind _AppRoot's login gate), but
    // waiting properly here costs nothing and removes the assumption.
    final currentUserId = (await ref.read(authControllerProvider.future))!.id;
    final bundle = widget.assetBundle ?? rootBundle;
    final isWarehouse = _contractType == 'warehouse';
    final quantity = isWarehouse
        ? clampMinOne(_shabraCountController.text).toInt()
        : (int.tryParse(_roomQuantityController.text) ?? 1);
    final service = double.tryParse(_serviceController.text) ?? 0;
    final managementPercent = double.tryParse(_managementController.text) ?? 0;
    final vatPercent = double.tryParse(_vatPercentController.text) ?? defaultVatPercent;
    final khana = int.tryParse(_khanaController.text) ?? 0;
    final shabraNumbers = _shabraNumbersController.text;

    final bytes = await buildQuotationPdfBytes(
      settings: settings,
      bundle: bundle,
      customerName: _customerNameController.text,
      roomType: _selectedRoomType,
      quantity: quantity,
      vat: _vatAmount,
      vatPercent: vatPercent,
      cd: _cdAmount,
      camera: _cameraAmount,
      managementPercent: managementPercent,
      managementFee: _managementFeeAmount,
      deposit: _depositAmount,
      contractMonths: _contractMonths,
      yearlyPrice: _yearlyPrice,
      finalPrice: _finalPrice,
      payments: _payments,
      isWarehouse: isWarehouse,
      contractCertFee: _contractCertFeeAmount,
      hemayaInsurance: _hemayaInsuranceAmount,
      hemayaContractFee: _hemayaContractFeeAmount,
      khana: isWarehouse ? khana : null,
      shabraNumbers: isWarehouse ? shabraNumbers : null,
    );

    final quotaNumber = await quotationRepository.reserveNextQuotaNumber();
    await quotationRepository.add(
      SavedQuotation(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        quotaNumber: quotaNumber,
        customerName: _customerNameController.text,
        createdAt: DateTime.now(),
        roomType: _selectedRoomType,
        contractType: _contractType,
        quantity: quantity,
        priceMonth: double.tryParse(_priceMonthController.text) ?? 0,
        vat: _vatAmount,
        vatPercent: vatPercent,
        cd: isWarehouse ? 0 : _cdAmount,
        camera: _cameraAmount,
        includeCd: _includeCd,
        includeCamera: _includeCamera,
        service: service,
        managementPercent: managementPercent,
        deposit: isWarehouse ? 0 : _depositAmount,
        industrialDepositPercent: double.tryParse(_industrialDepositPercentController.text) ?? 10,
        contractMonths: _contractMonths,
        numberOfPayments: _numberOfPayments,
        yearlyPrice: _yearlyPrice,
        finalPrice: _finalPrice,
        khana: khana,
        shabraNumbers: shabraNumbers,
        shabraCount: quantity,
        area: double.tryParse(_areaController.text) ?? 0,
        pricePerSqft: double.tryParse(_pricePerSqftController.text) ?? 0,
        warehouseDepositPercent: double.tryParse(_warehouseDepositPercentController.text) ?? 10,
        civilDefensePerShabraRate: double.tryParse(_civilDefensePerShabraController.text) ?? 1000,
        contractCertFee: double.tryParse(_contractCertFeeController.text) ?? 160,
        hemayaInsuranceRate: double.tryParse(_hemayaInsuranceController.text) ?? 1500,
        hemayaContractFeeRate: double.tryParse(_hemayaContractFeeController.text) ?? 500,
      ),
      createdBy: currentUserId,
    );

    final sharer = widget.pdfSharer ?? PrintingPdfSharer();
    await sharer.sharePdf(bytes: bytes, filename: 'Quotation_${_customerNameController.text}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context);
    final strings = AppLocalizations.of(context);
    final templateStore = Provider.of<TemplateStore>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.appTitle),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            key: const Key('helpButton'),
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showCalculationHelp(context),
            tooltip: strings.howCalculationWorks,
          ),
          IconButton(
            key: const Key('newQuotationButton'),
            icon: const Icon(Icons.add_box_outlined),
            onPressed: _newQuotation,
            tooltip: strings.newQuotation,
          ),
          IconButton(
            key: const Key('archiveButton'),
            icon: const Icon(Icons.history),
            onPressed: _openArchive,
            tooltip: strings.archiveTitle,
          ),
          IconButton(
            key: const Key('contractSystemButton'),
            icon: const Icon(Icons.gavel_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ContractsHomeScreen()),
              );
            },
            tooltip: strings.isArabic ? 'نظام العقود' : 'Contract System',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            tooltip: strings.settingsTitle,
          ),
        ],
      ),
      body: Directionality(
        textDirection: strings.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0 + MediaQuery.of(context).padding.bottom + 80.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(strings.companyName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(settings.companyName),
                      const SizedBox(height: 8),
                      Text('${strings.phoneNumber}: ${settings.companyPhone}'),
                      const SizedBox(height: 4),
                      Text('${strings.emailAddress}: ${settings.companyEmail}'),
                      if (settings.companyWebsite.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('${strings.website}: ${settings.companyWebsite}'),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              key: const Key('templateDropdown'),
                              initialValue: _selectedTemplateId,
                              isExpanded: true,
                              decoration: InputDecoration(labelText: strings.templateLabel),
                              items: [
                                DropdownMenuItem<String>(
                                  value: null,
                                  child: Text(strings.selectTemplate, overflow: TextOverflow.ellipsis),
                                ),
                                ...templateStore.templates.map((template) => DropdownMenuItem(
                                      value: template.id,
                                      child: Text(strings.templateDisplayName(template), overflow: TextOverflow.ellipsis),
                                    )),
                              ],
                              onChanged: (id) {
                                if (id == null) {
                                  setState(() => _selectedTemplateId = null);
                                  return;
                                }
                                final matches = templateStore.templates.where((t) => t.id == id);
                                if (matches.isNotEmpty) _applyTemplate(matches.first);
                              },
                            ),
                          ),
                          IconButton(
                            key: const Key('saveTemplateButton'),
                            icon: const Icon(Icons.bookmark_add_outlined),
                            tooltip: strings.saveAsTemplate,
                            onPressed: _saveAsTemplate,
                          ),
                          IconButton(
                            key: const Key('manageTemplatesButton'),
                            icon: const Icon(Icons.playlist_remove),
                            tooltip: strings.manageTemplates,
                            onPressed: _manageTemplates,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: customerNameKey,
                        controller: _customerNameController,
                        decoration: InputDecoration(labelText: strings.customerName),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: const Key('contractTypeDropdown'),
                        initialValue: _contractType,
                        decoration: InputDecoration(labelText: strings.contractTypeLabel),
                        items: [
                          DropdownMenuItem(value: 'residential', child: Text(strings.residentialContract)),
                          DropdownMenuItem(value: 'commercial', child: Text(strings.commercialContract)),
                          DropdownMenuItem(value: 'industrial', child: Text(strings.industrialContract)),
                          DropdownMenuItem(value: 'warehouse', child: Text(strings.warehouseContract)),
                          DropdownMenuItem(value: 'shop', child: Text(strings.shopContract)),
                        ],
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() {
                            _contractType = val;
                            if (val == 'warehouse') _selectedRoomType = 'Warehouse';
                          });
                          _calculateQuota();
                        },
                      ),
                      const SizedBox(height: 12),
                      _contractType == 'warehouse' ? _buildWarehouseFields(strings) : _buildRoomFields(strings),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        key: const Key('numberOfPaymentsDropdown'),
                        initialValue: _numberOfPayments,
                        decoration: InputDecoration(labelText: strings.numberOfPaymentsLabel),
                        items: _availablePaymentCounts
                            .map((count) => DropdownMenuItem(
                                  value: count,
                                  child: Text(strings.paymentCountOptionLabel(count)),
                                ))
                            .toList(),
                        onChanged: (count) {
                          if (count == null) return;
                          setState(() => _numberOfPayments = count);
                          _calculateQuota();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                color: Colors.blue.shade50,
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      ...(_contractType == 'warehouse' ? _buildWarehouseResultRows(strings) : _buildRoomResultRows(strings)),
                      const Divider(),
                      _buildResultRow('${strings.finalPrice}:', '${formatAmount(_finalPrice)} ${strings.currencySymbol}', isBold: true),
                      const Divider(),
                      for (var i = 0; i < _payments.length; i++)
                        _buildResultRow(
                          '${_payments.length == 1 ? strings.singlePayment : strings.paymentLabel(i)}:',
                          '${formatAmount(_payments[i])} ${strings.currencySymbol}',
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _generateAndSharePDF,
                icon: const Icon(Icons.picture_as_pdf),
                label: Text(strings.exportPdf),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isBold ? 16 : 14)),
          ),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isBold ? 16 : 14, color: isBold ? Colors.blue.shade900 : Colors.black)),
        ],
      ),
    );
  }

  void _showCalculationHelp(BuildContext context) {
    final strings = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: Directionality(
          textDirection: strings.isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(dialogContext).size.height * 0.85),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(strings.howCalculationWorks, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text(strings.calculationFormulaText, style: const TextStyle(fontSize: 13, height: 1.5)),
                    const SizedBox(height: 16),
                    buildCalculationExample(
                      strings,
                      title: strings.isArabic ? 'مثال 1: غرفة واحدة مع الدفاع المدني والكاميرا' : 'Example 1: 1 room, with C.D & Camera',
                      priceMonth: 2500,
                      service: 500,
                      quantity: 1,
                      managementPercent: 10,
                      vatPercent: 5,
                      includeCd: true,
                      includeCamera: true,
                      cdUnit: 100,
                      cameraUnit: 112,
                      depositUnit: 1500,
                    ),
                    buildCalculationExample(
                      strings,
                      title: strings.isArabic ? 'مثال 2: غرفتين مع الدفاع المدني والكاميرا' : 'Example 2: 2 rooms, with C.D & Camera',
                      priceMonth: 3000,
                      service: 800,
                      quantity: 2,
                      managementPercent: 7,
                      vatPercent: 5,
                      includeCd: true,
                      includeCamera: true,
                      cdUnit: 100,
                      cameraUnit: 112,
                      depositUnit: 1500,
                    ),
                    buildCalculationExample(
                      strings,
                      title: strings.isArabic
                          ? 'مثال 3: بدون الدفاع المدني ولا الكاميرا (مثلاً عقد تجاري/صناعي)'
                          : 'Example 3: without C.D or Camera (e.g. a commercial/industrial deal)',
                      priceMonth: 10000,
                      service: 2000,
                      quantity: 1,
                      managementPercent: 10,
                      vatPercent: 5,
                      includeCd: false,
                      includeCamera: false,
                      cdUnit: 0,
                      cameraUnit: 0,
                      depositUnit: 5000,
                    ),
                    buildCalculationExample(
                      strings,
                      title: strings.isArabic
                          ? 'مثال 4: الدفاع المدني فقط بدون كاميرا (توضيح إنه كل خيار مستقل عن التاني)'
                          : 'Example 4: C.D only, no Camera (showing each checkbox is independent)',
                      priceMonth: 2800,
                      service: 400,
                      quantity: 1,
                      managementPercent: 10,
                      vatPercent: 5,
                      includeCd: true,
                      includeCamera: false,
                      cdUnit: 100,
                      cameraUnit: 112,
                      depositUnit: 1500,
                    ),
                    buildCalculationExample(
                      strings,
                      title: strings.isArabic
                          ? 'مثال 5: 7 غرف بثلاث دفعات (التأمين والدفاع المدني والإدارة والفات والكاميرا كلها مع الدفعة الأولى)'
                          : 'Example 5: 7 rooms in 3 payments (deposit, C.D, management, its VAT & camera all bundled into payment 1)',
                      priceMonth: 2800,
                      service: 0,
                      quantity: 7,
                      managementPercent: 10,
                      vatPercent: 5,
                      includeCd: true,
                      includeCamera: true,
                      cdUnit: 100,
                      cameraUnit: 112,
                      depositUnit: 1500,
                      numberOfPayments: 3,
                    ),
                    buildCalculationExample(
                      strings,
                      title: strings.isArabic
                          ? 'مثال 6: عقد 6 أشهر بس (مش سنة كاملة)، غرفتين بدفعتين'
                          : 'Example 6: a 6-month contract only (not a full year), 2 rooms in 2 payments',
                      priceMonth: 1500,
                      service: 0,
                      quantity: 2,
                      managementPercent: 10,
                      vatPercent: 5,
                      includeCd: true,
                      includeCamera: true,
                      cdUnit: 100,
                      cameraUnit: 112,
                      depositUnit: 1000,
                      months: 6,
                      numberOfPayments: 2,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.center,
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(strings.close),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  final LogoPicker? logoPicker;

  const SettingsScreen({super.key, this.logoPicker});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _companyNameController;
  late final TextEditingController _companyPhoneController;
  late final TextEditingController _companyEmailController;
  late final TextEditingController _companyWebsiteController;
  late final TextEditingController _notesArController;
  late final TextEditingController _notesEnController;
  late String _selectedLanguage;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<AppSettings>(context, listen: false);
    _companyNameController = TextEditingController(text: settings.companyName);
    _companyPhoneController = TextEditingController(text: settings.companyPhone);
    _companyEmailController = TextEditingController(text: settings.companyEmail);
    _companyWebsiteController = TextEditingController(text: settings.companyWebsite);
    _notesArController = TextEditingController(text: settings.customNotesAr ?? AppLocalizations.defaultNotesTemplateAr);
    _notesEnController = TextEditingController(text: settings.customNotesEn ?? AppLocalizations.defaultNotesTemplateEn);
    _selectedLanguage = settings.locale.languageCode;
  }

  Future<void> _pickLogo() async {
    final picker = widget.logoPicker ?? ImagePickerLogoPicker();
    final newLogoBytes = await picker.pickLogo();
    if (newLogoBytes == null || !mounted) return;
    await Provider.of<AppSettings>(context, listen: false).updateLogoBytes(newLogoBytes);
  }

  Future<void> _resetLogo() async {
    await Provider.of<AppSettings>(context, listen: false).updateLogoBytes(null);
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _companyPhoneController.dispose();
    _companyEmailController.dispose();
    _companyWebsiteController.dispose();
    _notesArController.dispose();
    _notesEnController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final settings = Provider.of<AppSettings>(context, listen: false);
    settings.updateLocale(Locale(_selectedLanguage));
    await settings.updateCompanySettings(
      name: _companyNameController.text.trim(),
      phone: _companyPhoneController.text.trim(),
      email: _companyEmailController.text.trim(),
      website: _companyWebsiteController.text.trim(),
    );
    await settings.updateCustomNotes(
      notesAr: _notesArController.text.trim().isEmpty ? null : _notesArController.text.trim(),
      notesEn: _notesEnController.text.trim().isEmpty ? null : _notesEnController.text.trim(),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).settingsSaved)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final settings = Provider.of<AppSettings>(context);
    return Directionality(
      textDirection: strings.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(strings.settingsTitle),
          backgroundColor: Colors.blue.shade700,
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0 + MediaQuery.of(context).padding.bottom + 80.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(strings.companyLogo, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: settings.logoBytes != null
                              ? Image.memory(settings.logoBytes!, key: const Key('logoPreview'), height: 80, width: 160, fit: BoxFit.contain)
                              : Image.asset('assets/logo.png', key: const Key('logoPreview'), height: 80, width: 160, fit: BoxFit.contain),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton(
                            key: const Key('chooseLogoButton'),
                            onPressed: _pickLogo,
                            child: Text(strings.chooseLogo),
                          ),
                          const SizedBox(width: 10),
                          if (settings.logoBytes != null)
                            TextButton(
                              key: const Key('resetLogoButton'),
                              onPressed: _resetLogo,
                              child: Text(strings.resetLogo),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(strings.languageLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      RadioListTile<String>(
                        key: const Key('languageArabicRadio'),
                        title: Text(strings.arabic),
                        value: 'ar',
                        groupValue: _selectedLanguage,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedLanguage = value);
                          }
                        },
                      ),
                      RadioListTile<String>(
                        key: const Key('languageEnglishRadio'),
                        title: Text(strings.english),
                        value: 'en',
                        groupValue: _selectedLanguage,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedLanguage = value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        key: const Key('companyNameField'),
                        controller: _companyNameController,
                        decoration: InputDecoration(labelText: strings.companyName),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('companyPhoneField'),
                        controller: _companyPhoneController,
                        decoration: InputDecoration(labelText: strings.phoneNumber),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('companyEmailField'),
                        controller: _companyEmailController,
                        decoration: InputDecoration(labelText: strings.emailAddress),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('companyWebsiteField'),
                        controller: _companyWebsiteController,
                        decoration: InputDecoration(labelText: strings.website),
                        keyboardType: TextInputType.url,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(strings.notesAndConditions, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(strings.notesHelperText, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('notesArField'),
                        controller: _notesArController,
                        decoration: InputDecoration(labelText: strings.notesArabicLabel, alignLabelWithHint: true),
                        maxLines: 5,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          key: const Key('resetNotesArButton'),
                          onPressed: () => setState(() => _notesArController.text = AppLocalizations.defaultNotesTemplateAr),
                          child: Text(strings.resetToDefault),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        key: const Key('notesEnField'),
                        controller: _notesEnController,
                        decoration: InputDecoration(labelText: strings.notesEnglishLabel, alignLabelWithHint: true),
                        maxLines: 5,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          key: const Key('resetNotesEnButton'),
                          onPressed: () => setState(() => _notesEnController.text = AppLocalizations.defaultNotesTemplateEn),
                          child: Text(strings.resetToDefault),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _saveSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        child: Text(strings.saveSettings),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final _amountFormat = NumberFormat('#,##0.##');

/// Formats a number with thousands separators (e.g. 108000 -> "108,000").
/// For display only - do not use to pre-fill editable number fields, since
/// the comma makes the text unparseable by double.tryParse.
String formatAmount(double value) => _amountFormat.format(value);

/// Plain (no thousands separator) formatting for pre-filling editable
/// number fields, so the text stays parseable by double.tryParse.
String formatFieldValue(double value) {
  if (value == value.truncateToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toString();
}

/// Parses [text] and clamps it to a minimum of 1, treating blank or
/// non-numeric input the same as zero — used for room quantity and contract
/// months, which can never sensibly be zero.
double clampMinOne(String text) {
  final parsed = double.tryParse(text);
  if (parsed == null || parsed < 1) return 1;
  return parsed;
}

/// True when [text] is blank, non-numeric, or below 1 — i.e. whenever
/// [clampMinOne] would silently substitute a fallback value instead of
/// using what was actually typed.
bool isBelowMinimumOne(String text) => (double.tryParse(text) ?? 0) < 1;

/// Parses [text] and clamps negative input up to zero; blank or non-numeric
/// input falls back to zero directly, since a blank fee field just means
/// "no such fee" rather than an error.
double clampNonNegative(String text) {
  final parsed = double.tryParse(text) ?? 0;
  return parsed < 0 ? 0 : parsed;
}

/// True only when [text] parses to an explicit negative number — blank
/// fields are not flagged, since leaving a fee field empty is normal.
bool isNegativeInput(String text) {
  final parsed = double.tryParse(text);
  return parsed != null && parsed < 0;
}

/// The monthly rent and monthly service charges are combined before being
/// multiplied out over the contract period, so the management percentage
/// (see [calculateManagementFee]) is computed on their combined total for
/// however many months the contract actually runs — not always a full year.
double calculateBasePrice(double priceMonth, double service, int quantity, {int months = 12}) {
  return (priceMonth + service) * months * quantity;
}

/// Civil defense and camera fees are quoted as an annual per-unit rate, so
/// a contract shorter (or longer) than 12 months only bills the matching
/// fraction of it — e.g. a 9-month contract bills 9/12 of the annual rate,
/// not the full year. Used for both C.D and camera, which follow the same
/// rule; deposit is intentionally excluded since it's a one-time amount,
/// not an annual recurring fee, so it never gets prorated by months.
double calculateProratedFee(double annualUnitRate, int months, double quantity) {
  return annualUnitRate * (months / 12) * quantity;
}

/// The management fee is a percentage of the base rent total (rent +
/// service, for the contract period) rather than a flat amount.
double calculateManagementFee(double baseRentTotal, double managementPercent) {
  return baseRentTotal * managementPercent / 100;
}

/// The "Management VAT" is a percentage of the management fee (not a flat
/// manually-typed amount), since UAE residential rent itself is VAT-exempt
/// but the management/service fee is taxable. The rate defaults to 5% but
/// stays freely editable per quotation, same as the management percentage.
const double defaultVatPercent = 5;

double calculateManagementVat(double managementFee, double vatPercent) {
  return managementFee * vatPercent / 100;
}

double calculateFinalPrice(
  double baseYearlyPrice,
  double vat,
  double cd,
  double camera,
  double managementFee,
  double deposit,
) {
  return baseYearlyPrice + vat + cd + camera + managementFee + deposit;
}

/// Shared by two independent features that both compute "N% of a rent
/// total": the Industrial room-deposit override and the warehouse deposit.
double calculatePercentOfRent(double rentTotal, double percent) => rentTotal * percent / 100;

/// Warehouse rent is billed directly by area, never multiplied by contract
/// months — unlike [calculateBasePrice] for rooms, months only gate which
/// payment counts are available, not the rent size itself.
double calculateWarehouseRent(double pricePerSqft, double area) => pricePerSqft * area;

/// Flat per-shabra civil defense fee. Deliberately not prorated by months —
/// no such rule applies to warehouse quotations, unlike rooms' C.D/camera
/// (see [calculateProratedFee]).
double calculateWarehouseCivilDefense(double cdPerShabraRate, int shabraCount) =>
    cdPerShabraRate * shabraCount;

double calculateHemayaInsurance(double hemayaInsuranceRate, int shabraCount) =>
    hemayaInsuranceRate * shabraCount;

double calculateHemayaContractFee(double hemayaContractFeeRate, int shabraCount) =>
    hemayaContractFeeRate * shabraCount;

/// VAT base for a warehouse quotation is rent + the flat contract
/// certification fee + the management fee — explicitly excluding civil
/// defense and both HEMAYA fees.
double calculateWarehouseVat(
  double totalRent,
  double contractCertFee,
  double managementFee,
  double vatPercent,
) =>
    (totalRent + contractCertFee + managementFee) * vatPercent / 100;

double calculateWarehouseFinalPrice({
  required double totalRent,
  required double managementFee,
  required double civilDefense,
  required double contractCertFee,
  required double hemayaInsurance,
  required double hemayaContractFee,
  required double deposit,
  required double vat,
}) =>
    totalRent + managementFee + civilDefense + contractCertFee + hemayaInsurance + hemayaContractFee + deposit + vat;

/// Builds one worked example for the "How Calculations Work" help dialog,
/// computed live through the same functions the calculator itself uses so
/// the help text can never drift out of sync with the real formula.
Widget buildCalculationExample(
  AppLocalizations strings, {
  required String title,
  required double priceMonth,
  required double service,
  required int quantity,
  required double managementPercent,
  required double vatPercent,
  required bool includeCd,
  required bool includeCamera,
  required double cdUnit,
  required double cameraUnit,
  required double depositUnit,
  int months = 12,
  int? numberOfPayments,
}) {
  final yearly = calculateBasePrice(priceMonth, service, quantity, months: months);
  final managementFee = calculateManagementFee(yearly, managementPercent);
  final vat = calculateManagementVat(managementFee, vatPercent);
  final cd = includeCd ? calculateProratedFee(cdUnit, months, quantity.toDouble()) : 0.0;
  final camera = includeCamera ? calculateProratedFee(cameraUnit, months, quantity.toDouble()) : 0.0;
  final deposit = depositUnit * quantity;
  final finalPrice = calculateFinalPrice(yearly, vat, cd, camera, managementFee, deposit);

  final lines = <String>[
    '${strings.pricePerMonth}: ${formatAmount(priceMonth)}, ${strings.serviceCharge}: ${formatAmount(service)}, ${strings.roomQuantity}: $quantity',
    '${strings.periodRentLabel(months)} = ${formatAmount(yearly)}',
    '${strings.managementFee} (${formatFieldValue(managementPercent)}%) = ${formatAmount(managementFee)}',
    '${strings.managementVat} (${formatFieldValue(vatPercent)}%) = ${formatAmount(vat)}',
    if (includeCd) '${strings.cdCharge} = ${formatAmount(cd)}',
    if (includeCamera) '${strings.cameraFee} = ${formatAmount(camera)}',
    '${strings.refundableDeposit} = ${formatAmount(deposit)}',
    '${strings.finalPrice} = ${formatAmount(finalPrice)}',
  ];

  if (numberOfPayments != null) {
    final firstPaymentExtra = vat + cd + camera + managementFee + deposit;
    final payments = splitPayments(
      yearly,
      numberOfPayments: numberOfPayments,
      firstPaymentExtra: firstPaymentExtra,
    );
    for (var i = 0; i < payments.length; i++) {
      lines.add(
        '${payments.length == 1 ? strings.singlePayment : strings.paymentLabel(i)} = ${formatAmount(payments[i])}',
      );
    }
  }

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ...lines.map((line) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(line, style: const TextStyle(fontSize: 13)),
            )),
      ],
    ),
  );
}

/// Splits [baseAmount] (the rent/rooms portion) into [numberOfPayments]
/// equal installments, then adds [firstPaymentExtra] (deposit, C.D, camera,
/// management fee, and its VAT — everything collected upfront) onto the
/// first installment. The last installment absorbs any rounding remainder
/// so the payments always sum exactly to `baseAmount + firstPaymentExtra`.
List<double> splitPayments(
  double baseAmount, {
  required int numberOfPayments,
  double firstPaymentExtra = 0,
}) {
  final n = numberOfPayments < 1 ? 1 : numberOfPayments;
  if (n == 1) {
    return [baseAmount + firstPaymentExtra];
  }
  final each = baseAmount / n;
  final payments = List<double>.generate(n - 1, (_) => each);
  payments.add(baseAmount - each * (n - 1));
  payments[0] += firstPaymentExtra;
  return payments;
}
