import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../models/item.dart';

part 'database.g.dart';

@DataClassName('ItemRow')
class Items extends Table {
  IntColumn get id => integer()();
  TextColumn get title => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get kind => text()();
  TextColumn get priority => text()();
  TextColumn get status => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  IntColumn get reminderMinutes => integer().nullable()();
  RealColumn get targetAmount => real().nullable()();
  RealColumn get savedAmount => real().withDefault(const Constant(0))();
  IntColumn get recurrenceDay => integer().withDefault(const Constant(1))();
  IntColumn get dueMinutes => integer().withDefault(const Constant(540))();
  RealColumn get amount => real().nullable()();

  /// Meses pagos de compromissos recorrentes, separados por vírgula ("2026-10,2026-11").
  TextColumn get paidMonths => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Items])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  static QueryExecutor _open() => driftDatabase(
        name: 'ritmo',
        web: DriftWebOptions(
          sqlite3Wasm: Uri.parse('sqlite3.wasm'),
          driftWorker: Uri.parse('drift_worker.js'),
        ),
      );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        // Ao mudar as tabelas: incremente schemaVersion e trate aqui cada
        // versão antiga (ex.: if (from < 2) await m.addColumn(...)).
        onUpgrade: (m, from, to) async {},
      );

  Future<List<Item>> allItems() async =>
      (await select(items).get()).map(_toItem).toList();

  Future<void> save(Item item) =>
      into(items).insertOnConflictUpdate(_toCompanion(item));

  Future<void> saveAll(Iterable<Item> list) => batch((b) {
        b.insertAllOnConflictUpdate(items, list.map(_toCompanion).toList());
      });

  Future<void> deleteById(int id) =>
      (delete(items)..where((t) => t.id.equals(id))).go();

  Future<void> clear() => delete(items).go();
}

Item _toItem(ItemRow r) {
  T pick<T extends Enum>(List<T> values, String name, T fallback) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }

  return Item(
    id: r.id,
    title: r.title,
    notes: r.notes,
    kind: pick(ItemKind.values, r.kind, ItemKind.task),
    priority: pick(ItemPriority.values, r.priority, ItemPriority.medium),
    status: pick(ItemStatus.values, r.status, ItemStatus.pending),
    createdAt: r.createdAt,
    completedAt: r.completedAt,
    dueDate: r.dueDate,
    reminderMinutes: r.reminderMinutes,
    targetAmount: r.targetAmount,
    savedAmount: r.savedAmount,
    recurrenceDay: r.recurrenceDay,
    dueMinutes: r.dueMinutes,
    amount: r.amount,
    paidMonths: r.paidMonths.isEmpty ? {} : r.paidMonths.split(',').toSet(),
  );
}

ItemsCompanion _toCompanion(Item i) => ItemsCompanion(
      id: Value(i.id),
      title: Value(i.title),
      notes: Value(i.notes),
      kind: Value(i.kind.name),
      priority: Value(i.priority.name),
      status: Value(i.status.name),
      createdAt: Value(i.createdAt),
      completedAt: Value(i.completedAt),
      dueDate: Value(i.dueDate),
      reminderMinutes: Value(i.reminderMinutes),
      targetAmount: Value(i.targetAmount),
      savedAmount: Value(i.savedAmount),
      recurrenceDay: Value(i.recurrenceDay),
      dueMinutes: Value(i.dueMinutes),
      amount: Value(i.amount),
      paidMonths: Value(i.paidMonths.join(',')),
    );
