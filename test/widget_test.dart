import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ritmo/app.dart';
import 'package:ritmo/data/database.dart';
import 'package:ritmo/data/store.dart';
import 'package:ritmo/models/item.dart';
import 'package:ritmo/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Item recurring({int day = 31, Set<String> paid = const {}}) => Item(
      id: 1,
      title: 'Aluguel',
      kind: ItemKind.recurring,
      createdAt: DateTime(2026, 1, 1),
      recurrenceDay: day,
      paidMonths: paid,
    );

AppDatabase memoryDb() => AppDatabase(NativeDatabase.memory());

void main() {
  group('Recorrência mensal', () {
    test('dia 31 vira o último dia em meses curtos', () {
      final r = recurring();
      expect(r.occurrenceIn(2026, 2).day, 28);
      expect(r.occurrenceIn(2028, 2).day, 29);
      expect(r.occurrenceIn(2026, 4).day, 30);
    });

    test('mês pago avança para a próxima ocorrência', () {
      final now = DateTime(2026, 10, 21);
      expect(recurring(day: 5).effectiveDue(now), DateTime(2026, 10, 5, 9));
      final paid = recurring(day: 5, paid: {'2026-10'});
      expect(paid.effectiveDue(now), DateTime(2026, 11, 5, 9));
      expect(paid.isOverdue(now), isFalse);
    });

    test('ocorrência não paga que já passou fica atrasada', () {
      expect(recurring(day: 5).isOverdue(DateTime(2026, 10, 21)), isTrue);
      expect(recurring(day: 25).isOverdue(DateTime(2026, 10, 21)), isFalse);
    });
  });

  group('Regras por tipo', () {
    Item goal(double saved) => Item(
        id: 2,
        title: 'Moto',
        kind: ItemKind.purchase,
        createdAt: DateTime(2026, 1, 1),
        targetAmount: 1000,
        savedAmount: saved,
        reminderMinutes: 60);

    test('meta conclui ao atingir o valor, sem depender de status', () {
      expect(goal(999).isDone, isFalse);
      expect(goal(1000).isDone, isTrue);
      expect(goal(1000).isOverdue(DateTime(2030)), isFalse);
    });

    test('metas ficam fora das pendências do painel', () {
      final s = Summary.of([goal(100), recurring(day: 25)], DateTime(2026, 10, 21));
      expect(s.open.every((i) => i.kind != ItemKind.purchase), isTrue);
      expect(s.goals.length, 1);
    });
  });

  test('serialização preserva os campos', () {
    final item = Item(
      id: 7,
      title: 'Notebook',
      kind: ItemKind.purchase,
      createdAt: DateTime(2026, 3, 1),
      priority: ItemPriority.high,
      targetAmount: 4000,
      savedAmount: 1000,
      dueDate: DateTime(2026, 12, 1, 9),
      reminderMinutes: 1440,
    );
    final back = Item.fromJson(item.toJson());
    expect(back.title, 'Notebook');
    expect(back.progress, 0.25);
    expect(back.priority, ItemPriority.high);
    expect(back.dueDate, DateTime(2026, 12, 1, 9));
    expect(back.reminderMinutes, 1440);
  });

  test('banco: itens salvos persistem, incluindo meses pagos', () async {
    SharedPreferences.setMockInitialValues({});
    final db = memoryDb();
    final store = await RitmoStore.load(database: db);
    await store.upsert(recurring(day: 5, paid: {'2026-09', '2026-10'}));
    await store.upsert(Item(
        id: 2,
        title: 'Pagar luz',
        kind: ItemKind.task,
        createdAt: DateTime.now(),
        dueDate: DateTime(2026, 11, 3, 9)));

    final reopened = await RitmoStore.load(database: db);
    expect(reopened.items.length, 2);
    final r = reopened.items.firstWhere((i) => i.isRecurring);
    expect(r.paidMonths, {'2026-09', '2026-10'});
    expect(reopened.items.firstWhere((i) => i.id == 2).dueDate,
        DateTime(2026, 11, 3, 9));

    await reopened.remove(2);
    expect((await RitmoStore.load(database: db)).items.length, 1);
    await db.close();
  });

  test('migra dados antigos do SharedPreferences uma única vez', () async {
    final legacy = Item(
        id: 1,
        title: 'Notebook',
        kind: ItemKind.purchase,
        createdAt: DateTime(2026, 1, 1),
        targetAmount: 3000,
        savedAmount: 500);
    SharedPreferences.setMockInitialValues({
      'ritmo.items.v1': jsonEncode([legacy.toJson()]),
    });
    final db = memoryDb();
    final store = await RitmoStore.load(database: db);
    expect(store.items.single.title, 'Notebook');
    expect(store.items.single.savedAmount, 500);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('ritmo.items.v1'), isNull);
    expect((await db.allItems()).length, 1);
    await db.close();
  });

  testWidgets('abre o painel vazio e navega entre as abas', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('pt_BR');
    final store = await RitmoStore.load(database: memoryDb());
    await tester.pumpWidget(
        RitmoApp(store: store, notifications: NotificationService()));
    await tester.pumpAndSettle();

    expect(find.text('Vamos pegar o ritmo?'), findsOneWidget);
    await tester.tap(find.text('Metas').last);
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma meta ainda'), findsOneWidget);
    await tester.tap(find.text('Recorrentes').last);
    await tester.pumpAndSettle();
    expect(find.text('Nenhum compromisso recorrente'), findsOneWidget);
  });
}
