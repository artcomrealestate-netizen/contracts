import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/quotation_template.dart';

class TemplateStore extends ChangeNotifier {
  static const _storageKey = 'quotation_templates';

  final List<QuotationTemplate> _templates;

  TemplateStore._(this._templates);

  /// For tests: builds a store in-memory without touching shared_preferences.
  @visibleForTesting
  TemplateStore.withTemplates(List<QuotationTemplate> templates) : _templates = List.of(templates);

  List<QuotationTemplate> get templates => List.unmodifiable(_templates);

  static List<QuotationTemplate> defaultTemplates() => const [
        QuotationTemplate(
          id: 'default-small',
          templateName: 'Normal Room',
          roomType: 'Small',
          priceMonth: 4500,
          cd: 100,
          camera: 112,
          service: 0,
          deposit: 1500,
          numberOfPayments: 2,
        ),
        QuotationTemplate(
          id: 'default-vip',
          templateName: 'Double Room',
          roomType: 'Large',
          priceMonth: 7500,
          cd: 100,
          camera: 112,
          service: 0,
          deposit: 2500,
          numberOfPayments: 2,
        ),
      ];

  static Future<TemplateStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    List<QuotationTemplate> templates;
    if (raw == null) {
      templates = List.of(defaultTemplates());
      await prefs.setString(_storageKey, jsonEncode(templates.map((t) => t.toJson()).toList()));
    } else {
      final decoded = jsonDecode(raw) as List<dynamic>;
      templates = decoded.map((e) => QuotationTemplate.fromJson(e as Map<String, dynamic>)).toList();
    }
    return TemplateStore._(templates);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_templates.map((t) => t.toJson()).toList()));
  }

  Future<void> upsert(QuotationTemplate template) async {
    final index = _templates.indexWhere((t) => t.id == template.id);
    if (index >= 0) {
      _templates[index] = template;
    } else {
      _templates.add(template);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> delete(String id) async {
    _templates.removeWhere((t) => t.id == id);
    notifyListeners();
    await _persist();
  }
}
