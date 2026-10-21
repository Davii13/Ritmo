import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/item.dart';
import 'database.dart';

/// Estado global do app. Os itens ficam num banco SQLite (Drift) e são
/// espelhados em memória; as configurações ficam em SharedPreferences.
class RitmoStore extends ChangeNotifier {
  RitmoStore._(this._db, this._prefs, this._items, this._themeMode,
      this._notificationsEnabled, this._defaultReminder);

  static const _itemsKey = 'ritmo.items.v1';
  static const _themeKey = 'ritmo.theme';
  static const _notifKey = 'ritmo.notifications';
  static const _reminderKey = 'ritmo.defaultReminder';

  final AppDatabase _db;
  final SharedPreferences _prefs;
  List<Item> _items;
  ThemeMode _themeMode;
  bool _notificationsEnabled;
  int? _defaultReminder;

  static Future<RitmoStore> load({AppDatabase? database}) async {
    final prefs = await SharedPreferences.getInstance();
    final db = database ?? AppDatabase();
    var items = await db.allItems();
    if (items.isEmpty) items = await _migrateLegacy(prefs, db);
    final theme = ThemeMode.values.asNameMap()[prefs.getString(_themeKey)] ??
        ThemeMode.system;
    // -1 = o usuário escolheu "sem lembrete"; ausente = padrão (1 dia antes).
    final storedReminder = prefs.getInt(_reminderKey);
    final reminder = storedReminder == null
        ? 1440
        : (storedReminder < 0 ? null : storedReminder);
    return RitmoStore._(
      db,
      prefs,
      items,
      theme,
      prefs.getBool(_notifKey) ?? true,
      reminder,
    );
  }

  /// Versões anteriores guardavam tudo como JSON em SharedPreferences.
  /// Importa esses dados uma única vez e só então apaga o JSON antigo.
  static Future<List<Item>> _migrateLegacy(
      SharedPreferences prefs, AppDatabase db) async {
    final raw = prefs.getString(_itemsKey);
    if (raw == null) return [];
    try {
      final items = (jsonDecode(raw) as List)
          .map((e) => Item.fromJson(e as Map<String, dynamic>))
          .toList();
      await db.saveAll(items);
      await prefs.remove(_itemsKey);
      return items;
    } catch (_) {
      // JSON corrompido: mantém a chave antiga intacta e começa vazio.
      return [];
    }
  }

  List<Item> get items => List.unmodifiable(_items);
  ThemeMode get themeMode => _themeMode;
  bool get notificationsEnabled => _notificationsEnabled;

  /// Antecedência padrão de lembrete para novos itens (null = sem lembrete).
  int? get defaultReminder => _defaultReminder;

  int nextId() =>
      _items.fold<int>(0, (m, i) => i.id > m ? i.id : m) + 1;

  Future<void> upsert(Item item) async {
    final idx = _items.indexWhere((i) => i.id == item.id);
    if (idx >= 0) {
      _items[idx] = item;
    } else {
      _items.add(item);
    }
    notifyListeners();
    await _db.save(item);
  }

  Future<void> remove(int id) async {
    _items.removeWhere((i) => i.id == id);
    notifyListeners();
    await _db.deleteById(id);
  }

  Future<void> clearAll() async {
    _items = [];
    notifyListeners();
    await _db.clear();
  }

  /// Conclui/reabre um item. Em recorrentes, marca/desmarca o mês atual como pago.
  Future<void> toggleDone(Item item, DateTime now) {
    if (item.isRecurring) {
      final paid = {...item.paidMonths};
      final key = monthKey(now);
      if (!paid.remove(key)) paid.add(key);
      return upsert(item.copyWith(paidMonths: paid));
    }
    if (item.status == ItemStatus.done) {
      return upsert(item.copyWith(
          status: ItemStatus.pending, clearCompletedAt: true));
    }
    return upsert(item.copyWith(
      status: ItemStatus.done,
      completedAt: now,
    ));
  }

  Future<void> setStatus(Item item, ItemStatus status, DateTime now) {
    if (status == ItemStatus.done) return toggleDone(item, now);
    return upsert(item.copyWith(status: status, clearCompletedAt: true));
  }

  Future<void> addSaved(Item item, double value) {
    final saved = (item.savedAmount + value).clamp(0.0, double.infinity);
    return upsert(item.copyWith(savedAmount: saved));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _prefs.setString(_themeKey, mode.name);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    notifyListeners();
    await _prefs.setBool(_notifKey, value);
  }

  Future<void> setDefaultReminder(int? minutes) async {
    _defaultReminder = minutes;
    notifyListeners();
    await _prefs.setInt(_reminderKey, minutes ?? -1);
  }
}
