import 'dart:math' as math;

enum ItemKind {
  purchase('Meta de compra', 'Metas de compra'),
  work('Demanda profissional', 'Demandas'),
  task('Tarefa', 'Tarefas'),
  recurring('Compromisso recorrente', 'Recorrentes');

  const ItemKind(this.label, this.plural);
  final String label;
  final String plural;
}

enum ItemPriority {
  low('Baixa'),
  medium('Média'),
  high('Alta');

  const ItemPriority(this.label);
  final String label;
}

enum ItemStatus {
  pending('Pendente'),
  inProgress('Em andamento'),
  done('Concluído');

  const ItemStatus(this.label);
  final String label;
}

/// Opções de antecedência do lembrete, em minutos.
const reminderOptions = <int?, String>{
  null: 'Sem lembrete',
  0: 'No horário do vencimento',
  60: '1 hora antes',
  1440: '1 dia antes',
  4320: '3 dias antes',
  10080: '1 semana antes',
};

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

class Item {
  const Item({
    required this.id,
    required this.title,
    required this.kind,
    required this.createdAt,
    this.notes = '',
    this.priority = ItemPriority.medium,
    this.status = ItemStatus.pending,
    this.dueDate,
    this.reminderMinutes,
    this.targetAmount,
    this.savedAmount = 0,
    this.recurrenceDay = 1,
    this.dueMinutes = 9 * 60,
    this.amount,
    this.paidMonths = const {},
    this.completedAt,
  });

  final int id;
  final String title;
  final String notes;
  final ItemKind kind;
  final ItemPriority priority;
  final ItemStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;

  /// Prazo (data + hora). Não usado em compromissos recorrentes.
  final DateTime? dueDate;
  final int? reminderMinutes;

  /// Metas de compra.
  final double? targetAmount;
  final double savedAmount;

  /// Compromissos recorrentes (mensais).
  final int recurrenceDay;
  final int dueMinutes;
  final double? amount;
  final Set<String> paidMonths;

  bool get isRecurring => kind == ItemKind.recurring;

  Item copyWith({
    String? title,
    String? notes,
    ItemKind? kind,
    ItemPriority? priority,
    ItemStatus? status,
    DateTime? dueDate,
    bool clearDueDate = false,
    int? reminderMinutes,
    bool clearReminder = false,
    double? targetAmount,
    bool clearTarget = false,
    double? savedAmount,
    int? recurrenceDay,
    int? dueMinutes,
    double? amount,
    bool clearAmount = false,
    Set<String>? paidMonths,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return Item(
      id: id,
      createdAt: createdAt,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      kind: kind ?? this.kind,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      reminderMinutes:
          clearReminder ? null : (reminderMinutes ?? this.reminderMinutes),
      targetAmount: clearTarget ? null : (targetAmount ?? this.targetAmount),
      savedAmount: savedAmount ?? this.savedAmount,
      recurrenceDay: recurrenceDay ?? this.recurrenceDay,
      dueMinutes: dueMinutes ?? this.dueMinutes,
      amount: clearAmount ? null : (amount ?? this.amount),
      paidMonths: paidMonths ?? this.paidMonths,
      completedAt:
          clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }

  // ---- Recorrência -------------------------------------------------------

  /// Ocorrência do mês informado; dia 31 vira o último dia em meses curtos.
  DateTime occurrenceIn(int year, int month) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, math.min(recurrenceDay, lastDay),
        dueMinutes ~/ 60, dueMinutes % 60);
  }

  /// Próximas ocorrências ainda não pagas, a partir do mês de [now].
  List<DateTime> upcomingOccurrences(DateTime now, {int count = 3}) {
    final result = <DateTime>[];
    var y = now.year;
    var m = now.month;
    for (var i = 0; i < 36 && result.length < count; i++) {
      final o = occurrenceIn(y, m);
      if (!paidMonths.contains(monthKey(o))) result.add(o);
      m++;
      if (m > 12) {
        m = 1;
        y++;
      }
    }
    return result;
  }

  bool paidThisMonth(DateTime now) => paidMonths.contains(monthKey(now));

  // ---- Estado derivado ---------------------------------------------------

  /// Próximo vencimento relevante (prazo, ou próxima ocorrência não paga).
  DateTime? effectiveDue(DateTime now) {
    if (isRecurring) {
      final next = upcomingOccurrences(now, count: 1);
      return next.isEmpty ? null : next.first;
    }
    return dueDate;
  }

  /// Meta: concluída ao atingir o valor. Recorrente: nunca "concluído"
  /// (só pago/não pago por mês). Demanda e tarefa: pelo status.
  bool get isDone => switch (kind) {
        ItemKind.purchase => targetAmount != null &&
            targetAmount! > 0 &&
            savedAmount >= targetAmount!,
        ItemKind.recurring => false,
        _ => status == ItemStatus.done,
      };

  bool isOpen() => !isDone;

  /// Só demandas, tarefas e recorrentes têm vencimento "atrasável".
  bool isOverdue(DateTime now) {
    if (kind == ItemKind.purchase || !isOpen()) return false;
    final due = effectiveDue(now);
    return due != null && dayOnly(due).isBefore(dayOnly(now));
  }

  double get progress {
    final target = targetAmount;
    if (target == null || target <= 0) return 0;
    return (savedAmount / target).clamp(0.0, 1.0);
  }

  /// Meta de compra ainda não atingida.
  bool get isGoalInProgress => kind == ItemKind.purchase && !isDone;

  // ---- Serialização ------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'notes': notes,
        'kind': kind.name,
        'priority': priority.name,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'reminderMinutes': reminderMinutes,
        'targetAmount': targetAmount,
        'savedAmount': savedAmount,
        'recurrenceDay': recurrenceDay,
        'dueMinutes': dueMinutes,
        'amount': amount,
        'paidMonths': paidMonths.toList(),
      };

  factory Item.fromJson(Map<String, dynamic> j) {
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) {
      for (final v in values) {
        if (v.name == name) return v;
      }
      return fallback;
    }

    DateTime? date(Object? v) => v is String ? DateTime.tryParse(v) : null;

    return Item(
      id: j['id'] as int,
      title: (j['title'] as String?) ?? '',
      notes: (j['notes'] as String?) ?? '',
      kind: pick(ItemKind.values, j['kind'], ItemKind.task),
      priority: pick(ItemPriority.values, j['priority'], ItemPriority.medium),
      status: pick(ItemStatus.values, j['status'], ItemStatus.pending),
      createdAt: date(j['createdAt']) ?? DateTime.now(),
      completedAt: date(j['completedAt']),
      dueDate: date(j['dueDate']),
      reminderMinutes: j['reminderMinutes'] as int?,
      targetAmount: (j['targetAmount'] as num?)?.toDouble(),
      savedAmount: (j['savedAmount'] as num?)?.toDouble() ?? 0,
      recurrenceDay: (j['recurrenceDay'] as int?) ?? 1,
      dueMinutes: (j['dueMinutes'] as int?) ?? 9 * 60,
      amount: (j['amount'] as num?)?.toDouble(),
      paidMonths: {...((j['paidMonths'] as List?) ?? const []).cast<String>()},
    );
  }
}

/// Resumo calculado para o painel.
class Summary {
  Summary._({
    required this.open,
    required this.overdue,
    required this.today,
    required this.upcoming,
    required this.goals,
    required this.recurringThisMonth,
    required this.monthTotal,
    required this.monthPaidTotal,
    required this.doneThisWeek,
  });

  final List<Item> open;
  final List<Item> overdue;
  final List<Item> today;

  /// Itens abertos com vencimento nos próximos 14 dias (inclui hoje), ordenados.
  final List<({Item item, DateTime due})> upcoming;
  final List<Item> goals;
  final List<Item> recurringThisMonth;
  final double monthTotal;
  final double monthPaidTotal;
  final int doneThisWeek;

  factory Summary.of(List<Item> items, DateTime now) {
    final todayStart = dayOnly(now);
    // Metas não entram em pendências/vencimentos: ficam só na aba Metas.
    final open =
        items.where((i) => i.kind != ItemKind.purchase && i.isOpen()).toList();
    final overdue = open.where((i) => i.isOverdue(now)).toList()
      ..sort((a, b) => a.effectiveDue(now)!.compareTo(b.effectiveDue(now)!));
    final today = open.where((i) {
      final d = i.effectiveDue(now);
      return d != null && dayOnly(d) == todayStart;
    }).toList();

    final horizon = todayStart.add(const Duration(days: 14));
    final upcoming = <({Item item, DateTime due})>[];
    for (final i in open) {
      final d = i.effectiveDue(now);
      if (d != null &&
          !dayOnly(d).isBefore(todayStart) &&
          d.isBefore(horizon)) {
        upcoming.add((item: i, due: d));
      }
    }
    upcoming.sort((a, b) => a.due.compareTo(b.due));

    final goals = items.where((i) => i.isGoalInProgress).toList()
      ..sort((a, b) => b.progress.compareTo(a.progress));

    final recurring = items.where((i) => i.isRecurring).toList()
      ..sort((a, b) => a.recurrenceDay.compareTo(b.recurrenceDay));
    var total = 0.0;
    var paid = 0.0;
    for (final r in recurring) {
      final v = r.amount ?? 0;
      total += v;
      if (r.paidThisMonth(now)) paid += v;
    }

    final weekAgo = todayStart.subtract(const Duration(days: 7));
    final doneThisWeek = items
        .where((i) =>
            (i.kind == ItemKind.work || i.kind == ItemKind.task) &&
            i.status == ItemStatus.done &&
            i.completedAt != null &&
            i.completedAt!.isAfter(weekAgo))
        .length;

    return Summary._(
      open: open,
      overdue: overdue,
      today: today,
      upcoming: upcoming,
      goals: goals,
      recurringThisMonth: recurring,
      monthTotal: total,
      monthPaidTotal: paid,
      doneThisWeek: doneThisWeek,
    );
  }
}
