import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'data/store.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  final store = await RitmoStore.load();
  final notifications = NotificationService();
  await notifications.init();
  runApp(RitmoApp(store: store, notifications: notifications));
}
