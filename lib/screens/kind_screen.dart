import 'package:flutter/material.dart';

import '../models/item.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/item_tile.dart';
import 'item_form_screen.dart';

enum _Filter {
  open('Abertas'),
  overdue('Atrasadas'),
  done('Concluídas'),
  all('Todas'),
  inProgress('Em andamento'),
  reached('Atingidas');

  const _Filter(this.label);
  final String label;
}

/// Tela exclusiva de um tipo de cadastro (metas, demandas, tarefas ou
/// recorrentes). Cada tipo só aparece na sua própria aba.
class KindScreen extends StatefulWidget {
  const KindScreen({super.key, required this.kind});

  final ItemKind kind;

  @override
  State<KindScreen> createState() => _KindScreenState();
}

class _KindScreenState extends State<KindScreen> {
  final _search = TextEditingController();
  late _Filter _filter =
      widget.kind == ItemKind.purchase ? _Filter.inProgress : _Filter.open;

  ItemKind get kind => widget.kind;

  List<_Filter> get _filters => switch (kind) {
        ItemKind.purchase => [_Filter.inProgress, _Filter.reached, _Filter.all],
        ItemKind.recurring => const [],
        _ => [_Filter.open, _Filter.overdue, _Filter.done, _Filter.all],
      };

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(Item i, DateTime now) {
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty &&
        !i.title.toLowerCase().contains(q) &&
        !i.notes.toLowerCase().contains(q)) {
      return false;
    }
    if (kind == ItemKind.recurring) return true;
    return switch (_filter) {
      _Filter.open || _Filter.inProgress => !i.isDone,
      _Filter.overdue => i.isOverdue(now),
      _Filter.done || _Filter.reached => i.isDone,
      _Filter.all => true,
    };
  }

  int _compare(Item a, Item b, DateTime now) {
    if (kind == ItemKind.recurring) {
      return a.recurrenceDay.compareTo(b.recurrenceDay);
    }
    if (kind == ItemKind.purchase) {
      return b.progress.compareTo(a.progress);
    }
    final da = a.effectiveDue(now), db = b.effectiveDue(now);
    if (da != null && db != null) {
      final c = da.compareTo(db);
      if (c != 0) return c;
    } else if (da != null) {
      return -1;
    } else if (db != null) {
      return 1;
    }
    return b.priority.index.compareTo(a.priority.index);
  }

  String get _title => switch (kind) {
        ItemKind.purchase => 'Metas',
        ItemKind.work => 'Demandas',
        ItemKind.task => 'Tarefas',
        ItemKind.recurring => 'Recorrentes',
      };

  String get _subtitle => switch (kind) {
        ItemKind.purchase => 'Compras que você está juntando para realizar',
        ItemKind.work => 'Entregas e pendências profissionais',
        ItemKind.task => 'O que precisa ser feito no dia a dia',
        ItemKind.recurring =>
          'Pagamentos e compromissos que se repetem todo mês',
      };

  String get _emptyTitle => switch (kind) {
        ItemKind.purchase => 'Nenhuma meta ainda',
        ItemKind.work => 'Nenhuma demanda ainda',
        ItemKind.task => 'Nenhuma tarefa ainda',
        ItemKind.recurring => 'Nenhum compromisso recorrente',
      };

  String get _emptyMessage => switch (kind) {
        ItemKind.purchase =>
          'Defina o valor de uma compra e acompanhe quanto já guardou.',
        ItemKind.work =>
          'Registre entregas e pendências do trabalho com prazo e prioridade.',
        ItemKind.task => 'Anote o que precisa ser feito e receba lembretes.',
        ItemKind.recurring =>
          'Cadastre contas e pagamentos que vencem em um dia fixo do mês.',
      };

  String get _addLabel => switch (kind) {
        ItemKind.purchase => 'Nova meta',
        ItemKind.work => 'Nova demanda',
        ItemKind.task => 'Nova tarefa',
        ItemKind.recurring => 'Novo compromisso',
      };

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context);
    final now = DateTime.now();
    final all = store.items.where((i) => i.kind == kind).toList();
    final list = all.where((i) => _matches(i, now)).toList()
      ..sort((a, b) => _compare(a, b, now));
    final filters = _filters;

    return PageBody(
      maxWidth: 1100,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_title,
                  style: t.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              Text(_subtitle,
                  style: t.textTheme.bodyMedium
                      ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
        if (all.isNotEmpty) ...[
          _Overview(kind: kind, items: all, now: now),
          const SizedBox(height: 12),
          if (kind != ItemKind.recurring)
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar em ${_title.toLowerCase()}',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(_search.clear),
                      ),
              ),
            ),
          if (filters.isNotEmpty) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<_Filter>(
                showSelectedIcon: false,
                segments: [
                  for (final f in filters)
                    ButtonSegment(value: f, label: Text(f.label)),
                ],
                selected: {_filter},
                onSelectionChanged: (s) => setState(() => _filter = s.first),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
        if (list.isEmpty)
          EmptyState(
            icon: all.isEmpty ? kind.icon : Icons.search_off_rounded,
            title: all.isEmpty ? _emptyTitle : 'Nada encontrado neste filtro',
            message:
                all.isEmpty ? _emptyMessage : 'Tente outro filtro ou busca.',
            action: all.isEmpty
                ? FilledButton.icon(
                    onPressed: () => openItemForm(context, kind: kind),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(_addLabel))
                : null,
          )
        else
          ResponsiveColumns(children: [
            for (final i in list) ItemTile(key: ValueKey(i.id), item: i),
          ]),
      ],
    );
  }
}

/// Resumo no topo de cada aba, específico do tipo.
class _Overview extends StatelessWidget {
  const _Overview({required this.kind, required this.items, required this.now});

  final ItemKind kind;
  final List<Item> items;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final color = kind.color;

    switch (kind) {
      case ItemKind.purchase:
        final target =
            items.fold<double>(0, (a, i) => a + (i.targetAmount ?? 0));
        final saved = items.fold<double>(
            0,
            (a, i) =>
                a +
                (i.targetAmount == null
                    ? i.savedAmount
                    : i.savedAmount.clamp(0, i.targetAmount!)));
        final reached = items.where((i) => i.isDone).length;
        return _Panel(
          color: color,
          title: '${money(saved)} guardados',
          subtitle: target > 0
              ? 'de ${money(target)} · $reached de ${items.length} metas atingidas'
              : '$reached de ${items.length} metas atingidas',
          progress: target > 0 ? saved / target : null,
        );
      case ItemKind.recurring:
        final total = items.fold<double>(0, (a, i) => a + (i.amount ?? 0));
        final paidTotal = items.fold<double>(
            0, (a, i) => a + (i.paidThisMonth(now) ? (i.amount ?? 0) : 0));
        final paid = items.where((i) => i.paidThisMonth(now)).length;
        return _Panel(
          color: color,
          title: total > 0
              ? '${money(paidTotal)} de ${money(total)} pagos'
              : '$paid de ${items.length} pagos',
          subtitle:
              '${capitalize(monthName(now))} · $paid de ${items.length} compromissos pagos',
          progress: total > 0 ? paidTotal / total : paid / items.length,
        );
      default:
        final open = items.where((i) => !i.isDone).length;
        final overdue = items.where((i) => i.isOverdue(now)).length;
        return Row(children: [
          Expanded(
              child: StatCard(
                  label: 'Abertas',
                  value: '$open',
                  icon: kind.icon,
                  color: color)),
          const SizedBox(width: 12),
          Expanded(
              child: StatCard(
                  label: 'Atrasadas',
                  value: '$overdue',
                  icon: Icons.warning_amber_rounded,
                  color: overdue == 0 ? t.colorScheme.outline : overdueColor)),
          const SizedBox(width: 12),
          Expanded(
              child: StatCard(
                  label: 'Concluídas',
                  value: '${items.length - open}',
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xFF16A34A))),
        ]);
    }
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.color,
    required this.title,
    required this.subtitle,
    this.progress,
  });

  final Color color;
  final String title;
  final String subtitle;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: t.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: t.textTheme.bodySmall
                    ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            if (progress != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress!.clamp(0.0, 1.0),
                  minHeight: 8,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.15),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
