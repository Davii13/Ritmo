import 'package:intl/intl.dart';

import '../models/item.dart';

const _locale = 'pt_BR';

final _currency = NumberFormat.simpleCurrency(locale: _locale);

String money(double v) => _currency.format(v);

/// Interpreta valores digitados como "1.234,56", "1234,56" ou "1234.56".
double? parseMoney(String text) {
  var t = text.trim().replaceAll(RegExp(r'[^\d,.\-]'), '');
  if (t.isEmpty) return null;
  if (t.contains(',')) {
    t = t.replaceAll('.', '').replaceAll(',', '.');
  }
  return double.tryParse(t);
}

String shortDate(DateTime d) => DateFormat("d 'de' MMM", _locale).format(d);

String longDate(DateTime d) =>
    DateFormat("EEEE, d 'de' MMMM", _locale).format(d);

String monthName(DateTime d) => DateFormat('MMMM', _locale).format(d);

String hourMinute(DateTime d) => DateFormat('HH:mm', _locale).format(d);

String minutesToClock(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

String capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// "Hoje", "Amanhã", "Em 3 dias", "Há 2 dias" ou a data curta.
String relativeDay(DateTime due, DateTime now) {
  final diff = dayOnly(due).difference(dayOnly(now)).inDays;
  return switch (diff) {
    0 => 'Hoje',
    1 => 'Amanhã',
    -1 => 'Ontem',
    > 1 && <= 7 => 'Em $diff dias',
    < -1 && >= -30 => 'Há ${-diff} dias',
    _ => shortDate(due),
  };
}

String greeting(DateTime now) {
  final h = now.hour;
  if (h < 5) return 'Boa madrugada';
  if (h < 12) return 'Bom dia';
  if (h < 18) return 'Boa tarde';
  return 'Boa noite';
}

