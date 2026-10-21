import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/item.dart';

/// Lembretes de vencimento via notificações locais agendadas (Android/iOS).
/// Na web o navegador não permite agendar notificações com o app fechado;
/// lá os vencimentos aparecem como avisos no painel.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _syncing = false;
  bool _dirty = false;

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// iOS permite no máximo 64 notificações pendentes.
  static const _maxScheduled = 60;
  static const _slotsPerItem = 4;

  Future<void> init() async {
    if (!supported) return;
    try {
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notificações indisponíveis: $e');
    }
  }

  Future<bool> requestPermission() async {
    if (!_ready) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(
            alert: true, badge: true, sound: true) ??
        false;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'vencimentos',
      'Vencimentos',
      channelDescription: 'Lembretes de prazos, tarefas e compromissos',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> showTest() async {
    if (!_ready) return;
    await _plugin.show(
      id: 0,
      title: 'Ritmo',
      body: 'Tudo certo! Os lembretes de vencimento estão ativos.',
      notificationDetails: _details,
    );
  }

  /// Recria todas as notificações agendadas a partir do estado atual.
  /// Chamadas concorrentes são coalescidas em uma nova passada.
  Future<void> sync(List<Item> items, {required bool enabled}) async {
    if (!_ready) return;
    if (_syncing) {
      _dirty = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _dirty = false;
        await _plugin.cancelAllPendingNotifications();
        if (enabled) await _schedule(items);
      } while (_dirty);
    } catch (e) {
      debugPrint('Falha ao agendar notificações: $e');
    } finally {
      _syncing = false;
    }
  }

  Future<void> _schedule(List<Item> items) async {
    final now = DateTime.now();
    final pending = <({int id, DateTime at, Item item, DateTime due})>[];

    for (final item in items) {
      final minutes = item.reminderMinutes;
      if (minutes == null || item.kind == ItemKind.purchase || !item.isOpen()) {
        continue;
      }
      final dues = item.isRecurring
          ? item.upcomingOccurrences(now, count: _slotsPerItem)
          : [if (item.dueDate != null) item.dueDate!];
      for (var s = 0; s < dues.length; s++) {
        final at = dues[s].subtract(Duration(minutes: minutes));
        if (at.isAfter(now)) {
          pending.add((
            id: item.id * _slotsPerItem + s,
            at: at,
            item: item,
            due: dues[s],
          ));
        }
      }
    }

    pending.sort((a, b) => a.at.compareTo(b.at));
    for (final p in pending.take(_maxScheduled)) {
      await _plugin.zonedSchedule(
        id: p.id,
        scheduledDate: tz.TZDateTime.from(p.at, tz.local),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: p.item.title,
        body: _body(p.item, p.due),
      );
    }
  }

  String _body(Item item, DateTime due) {
    final when = DateFormat("EEE, d 'de' MMM 'às' HH:mm", 'pt_BR').format(due);
    final money = item.isRecurring && item.amount != null
        ? ' · ${NumberFormat.simpleCurrency(locale: 'pt_BR').format(item.amount)}'
        : '';
    return 'Vence $when$money';
  }
}
