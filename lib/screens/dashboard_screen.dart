import 'package:flutter/material.dart';

import '../models/item.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/item_actions.dart';
import '../widgets/item_tile.dart';
import 'item_form_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context);
    final now = DateTime.now();
    final s = Summary.of(store.items, now);
    final pending =
        s.open.where((i) => !i.isRecurring || !i.paidThisMonth(now)).length;

    if (store.items.isEmpty) {
      return PageBody(children: [
        _Header(now: now),
        const SizedBox(height: 24),
        EmptyState(
          icon: Icons.auto_awesome_rounded,
          title: 'Vamos pegar o ritmo?',
          message:
              'Cadastre metas de compra, demandas do trabalho, tarefas e contas que se repetem todo mês. O painel organiza o resto.',
          action: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final k in ItemKind.values)
                ActionChip(
                  avatar: Icon(k.icon, size: 18, color: k.color),
                  label: Text(k.label),
                  onPressed: () => openItemForm(context, kind: k),
                ),
            ],
          ),
        ),
      ]);
    }

    final stats = [
      StatCard(
          label: 'Pendentes',
          value: '$pending',
          icon: Icons.pending_actions_rounded,
          color: t.colorScheme.primary),
      StatCard(
          label: 'Atrasados',
          value: '${s.overdue.length}',
          icon: Icons.warning_amber_rounded,
          color: s.overdue.isEmpty ? const Color(0xFF64748B) : overdueColor),
      StatCard(
          label: 'Vencem hoje',
          value: '${s.today.length}',
          icon: Icons.today_rounded,
          color: const Color(0xFFD97706)),
      StatCard(
          label: 'Metas em andamento',
          value: '${s.goals.length}',
          icon: Icons.flag_rounded,
          color: ItemKind.purchase.color),
    ];

    return PageBody(children: [
      _Header(now: now),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 900 ? 4 : 2;
        const gap = 12.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final st in stats) SizedBox(width: w, child: st)],
        );
      }),
      const SizedBox(height: 16),
      if (s.overdue.isNotEmpty) ...[
        _OverdueBanner(items: s.overdue, now: now),
        const SizedBox(height: 16),
      ],
      ResponsiveColumns(
        breakpoint: 760,
        children: [
          _UpcomingCard(upcoming: s.upcoming, now: now),
          _GoalsCard(goals: s.goals),
          _MonthCard(summary: s, now: now),
          if (s.doneThisWeek > 0) _WeekCard(done: s.doneThisWeek),
        ],
      ),
    ]);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.now});
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(greeting(now),
              style: t.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(capitalize(longDate(now)),
              style: t.textTheme.bodyLarge
                  ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _OverdueBanner extends StatelessWidget {
  const _OverdueBanner({required this.items, required this.now});
  final List<Item> items;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final shown = items.take(3).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: overdueColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: overdueColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.notification_important_rounded,
                color: overdueColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                items.length == 1
                    ? '1 item com vencimento atrasado'
                    : '${items.length} itens com vencimento atrasado',
                style: t.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800, color: overdueColor),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          for (final i in shown)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => openItem(context, i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Icon(i.kind.icon, size: 18, color: i.kind.color),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(i.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Text(relativeDay(i.effectiveDue(now)!, now),
                      style: t.textTheme.labelMedium?.copyWith(
                          color: overdueColor, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          if (items.length > shown.length)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('e mais ${items.length - shown.length}…',
                  style: t.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.upcoming, required this.now});
  final List<({Item item, DateTime due})> upcoming;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final shown = upcoming.take(6).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('Próximas datas', icon: Icons.event_rounded),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text('Nada vence nos próximos 14 dias.',
                    style: t.textTheme.bodyMedium
                        ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
              )
            else
              for (final u in shown)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  dense: true,
                  onTap: () => openItem(context, u.item),
                  leading: Container(
                    width: 44,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: u.item.kind.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${u.due.day}',
                          style: t.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: u.item.kind.color,
                              height: 1)),
                      Text(shortDate(u.due).split(' ').last.toUpperCase(),
                          style: t.textTheme.labelSmall?.copyWith(
                              color: u.item.kind.color, fontSize: 10)),
                    ]),
                  ),
                  title: Text(u.item.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                      '${relativeDay(u.due, now)} · ${hourMinute(u.due)}'
                      '${u.item.isRecurring && u.item.amount != null ? ' · ${money(u.item.amount!)}' : ''}'),
                  trailing: Icon(u.item.priority.icon,
                      color: u.item.priority.color, size: 22),
                ),
          ],
        ),
      ),
    );
  }
}

class _GoalsCard extends StatelessWidget {
  const _GoalsCard({required this.goals});
  final List<Item> goals;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('Metas em andamento', icon: Icons.flag_rounded),
            if (goals.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                    'Nenhuma meta em andamento. Cadastre uma meta de compra e registre quanto já guardou.',
                    style: t.textTheme.bodyMedium
                        ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
              )
            else
              for (final g in goals)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => openItem(context, g),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.title,
                            style: t.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        if (g.targetAmount != null)
                          GoalProgress(item: g)
                        else
                          Text('Defina um valor para acompanhar o progresso',
                              style: t.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.summary, required this.now});
  final Summary summary;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final list = summary.recurringThisMonth;
    final paidCount = list.where((i) => i.paidThisMonth(now)).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader('Compromissos do mês',
                icon: Icons.event_repeat_rounded,
                trailing: list.isEmpty
                    ? null
                    : Text('$paidCount/${list.length} pagos',
                        style: t.textTheme.labelMedium)),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                    'Cadastre contas e pagamentos que se repetem em dias fixos do mês.',
                    style: t.textTheme.bodyMedium
                        ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
              )
            else ...[
              if (summary.monthTotal > 0) ...[
                Text(
                    '${money(summary.monthPaidTotal)} de ${money(summary.monthTotal)}',
                    style: t.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: summary.monthPaidTotal / summary.monthTotal,
                    minHeight: 8,
                    color: ItemKind.recurring.color,
                    backgroundColor:
                        ItemKind.recurring.color.withValues(alpha: 0.15),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              for (final r in list)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  dense: true,
                  onTap: () => openItem(context, r),
                  leading: Icon(
                      r.paidThisMonth(now)
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: r.paidThisMonth(now)
                          ? ItemKind.recurring.color
                          : t.colorScheme.onSurfaceVariant),
                  title: Text(r.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('Dia ${r.recurrenceDay}'),
                  trailing: r.amount == null ? null : Text(money(r.amount!)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.done});
  final int done;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Icon(Icons.emoji_events_rounded,
              color: t.colorScheme.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              done == 1
                  ? '1 item concluído nos últimos 7 dias. Bom ritmo!'
                  : '$done itens concluídos nos últimos 7 dias. Bom ritmo!',
              style: t.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ]),
      ),
    );
  }
}
