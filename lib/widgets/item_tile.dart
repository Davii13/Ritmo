import 'package:flutter/material.dart';

import '../models/item.dart';
import '../theme.dart';
import '../utils/format.dart';
import 'common.dart';
import 'item_actions.dart';

enum _Action { edit, pending, inProgress, done, addSaved, delete }

class ItemTile extends StatelessWidget {
  const ItemTile({super.key, required this.item, this.due});

  final Item item;

  /// Vencimento a exibir (padrão: próximo vencimento do item).
  final DateTime? due;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final dueDate = due ?? item.effectiveDue(now);
    final purchase = item.kind == ItemKind.purchase;
    final overdue = !purchase &&
        item.isOpen() &&
        dueDate != null &&
        dayOnly(dueDate).isBefore(dayOnly(now));
    final done = item.isRecurring ? item.paidThisMonth(now) : item.isDone;
    final color = item.kind.color;
    final muted = t.colorScheme.onSurfaceVariant;
    final hasStatus =
        item.kind == ItemKind.work || item.kind == ItemKind.task;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openItem(context, item),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 4, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (purchase)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 4, 0),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(done ? Icons.emoji_events_rounded : item.kind.icon,
                        color: color),
                  ),
                )
              else
              IconButton(
                tooltip: item.isRecurring
                    ? (done ? 'Desmarcar pagamento do mês' : 'Marcar como pago')
                    : (done ? 'Reabrir' : 'Concluir'),
                onPressed: () => store.toggleDone(item, DateTime.now()),
                icon: Icon(
                  done
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: done ? color : muted,
                  size: 28,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          decoration: done && hasStatus
                              ? TextDecoration.lineThrough
                              : null,
                          color: done && hasStatus ? muted : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (item.isRecurring)
                            _Meta(
                                icon: item.kind.icon,
                                text: 'Todo dia ${item.recurrenceDay}',
                                color: color),
                          if (dueDate != null && (!done || item.isRecurring))
                            _Meta(
                              icon: purchase
                                  ? Icons.flag_outlined
                                  : Icons.schedule_rounded,
                              text: purchase
                                  ? 'Até ${shortDate(dueDate)}'
                                  : _dueText(dueDate, now, overdue),
                              color: overdue
                                  ? overdueColor
                                  : (dayOnly(dueDate) == dayOnly(now)
                                      ? const Color(0xFFD97706)
                                      : muted),
                              strong: overdue,
                            ),
                          if (item.isRecurring && item.amount != null)
                            _Meta(
                                icon: Icons.payments_outlined,
                                text: money(item.amount!),
                                color: muted),
                          if (item.isRecurring && done)
                            const _Meta(
                                icon: Icons.check_rounded,
                                text: 'Pago este mês',
                                color: Color(0xFF16A34A)),
                          if (purchase && done)
                            const _Meta(
                                icon: Icons.check_rounded,
                                text: 'Meta atingida',
                                color: Color(0xFF16A34A)),
                          if (!done)
                            _Meta(
                                icon: item.priority.icon,
                                text: item.priority.label,
                                color: item.priority.color),
                          if (item.status == ItemStatus.inProgress && hasStatus)
                            _Meta(
                                icon: ItemStatus.inProgress.icon,
                                text: 'Em andamento',
                                color: const Color(0xFF2563EB)),
                          if (item.reminderMinutes != null && !done && !purchase)
                            Icon(Icons.notifications_active_outlined,
                                size: 15, color: muted),
                        ],
                      ),
                      if (item.kind == ItemKind.purchase &&
                          item.targetAmount != null) ...[
                        const SizedBox(height: 10),
                        GoalProgress(item: item),
                      ],
                    ],
                  ),
                ),
              ),
              PopupMenuButton<_Action>(
                tooltip: 'Mais ações',
                icon: Icon(Icons.more_vert_rounded, color: muted),
                onSelected: (a) => _onAction(context, a),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: _Action.edit,
                      child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Editar'))),
                  if (hasStatus) ...[
                    if (item.status != ItemStatus.inProgress)
                      const PopupMenuItem(
                          value: _Action.inProgress,
                          child: ListTile(
                              leading: Icon(Icons.timelapse_rounded),
                              title: Text('Marcar em andamento'))),
                    if (item.status != ItemStatus.pending)
                      const PopupMenuItem(
                          value: _Action.pending,
                          child: ListTile(
                              leading: Icon(Icons.radio_button_unchecked),
                              title: Text('Marcar pendente'))),
                    if (item.status != ItemStatus.done)
                      const PopupMenuItem(
                          value: _Action.done,
                          child: ListTile(
                              leading: Icon(Icons.check_circle_outline),
                              title: Text('Concluir'))),
                  ],
                  if (item.kind == ItemKind.purchase)
                    const PopupMenuItem(
                        value: _Action.addSaved,
                        child: ListTile(
                            leading: Icon(Icons.savings_outlined),
                            title: Text('Adicionar valor'))),
                  const PopupMenuItem(
                      value: _Action.delete,
                      child: ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('Excluir'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _dueText(DateTime d, DateTime now, bool overdue) {
    final rel = relativeDay(d, now);
    final time = hourMinute(d);
    // Mostra o horário só quando o prazo é hoje ou futuro próximo.
    return overdue ? rel : '$rel · $time';
  }

  void _onAction(BuildContext context, _Action a) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    switch (a) {
      case _Action.edit:
        openItem(context, item);
      case _Action.pending:
        store.setStatus(item, ItemStatus.pending, now);
      case _Action.inProgress:
        store.setStatus(item, ItemStatus.inProgress, now);
      case _Action.done:
        store.toggleDone(item, now);
      case _Action.addSaved:
        addSavedDialog(context, item);
      case _Action.delete:
        deleteWithUndo(context, item);
    }
  }
}

class _Meta extends StatelessWidget {
  const _Meta(
      {required this.icon,
      required this.text,
      required this.color,
      this.strong = false});

  final IconData icon;
  final String text;
  final Color color;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w600)),
      ],
    );
  }
}

class GoalProgress extends StatelessWidget {
  const GoalProgress({super.key, required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final color = item.kind.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: item.progress,
            minHeight: 8,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${money(item.savedAmount)} de ${money(item.targetAmount!)} · ${(item.progress * 100).round()}%',
          style: t.textTheme.labelSmall
              ?.copyWith(color: t.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
