import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/item.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/item_actions.dart';

Future<void> openItemForm(BuildContext context, {Item? item, ItemKind? kind}) {
  return Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => ItemFormScreen(item: item, initialKind: kind),
  ));
}

class ItemFormScreen extends StatefulWidget {
  const ItemFormScreen({super.key, this.item, this.initialKind});

  final Item? item;
  final ItemKind? initialKind;

  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late final TextEditingController _target;
  late final TextEditingController _saved;
  late final TextEditingController _amount;

  late ItemKind _kind;
  late ItemPriority _priority;
  late ItemStatus _status;
  DateTime? _date;
  late int _minutes;
  late int _day;
  int? _reminder;
  bool _initialized = false;

  bool get _editing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _title = TextEditingController(text: i?.title);
    _notes = TextEditingController(text: i?.notes);
    _target = TextEditingController(text: _fmt(i?.targetAmount));
    _saved = TextEditingController(
        text: i != null && i.savedAmount > 0 ? _fmt(i.savedAmount) : '');
    _amount = TextEditingController(text: _fmt(i?.amount));
    _kind = i?.kind ?? widget.initialKind ?? ItemKind.task;
    _priority = i?.priority ?? ItemPriority.medium;
    _status = i?.status ?? ItemStatus.pending;
    _date = i?.dueDate;
    _minutes = i?.dueMinutes ??
        (i?.dueDate != null
            ? i!.dueDate!.hour * 60 + i.dueDate!.minute
            : 9 * 60);
    _day = i?.recurrenceDay ?? DateTime.now().day;
    _reminder = i?.reminderMinutes;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      // Novo item herda a antecedência padrão definida nos ajustes.
      if (!_editing) _reminder = StoreScope.of(context).defaultReminder;
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _notes, _target, _saved, _amount]) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmt(double? v) =>
      v == null ? '' : v.toStringAsFixed(2).replaceAll('.', ',');

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      helpText: 'Prazo',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _minutes ~/ 60, minute: _minutes % 60),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _minutes = picked.hour * 60 + picked.minute);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final store = StoreScope.of(context);
    final old = widget.item;
    final recurring = _kind == ItemKind.recurring;
    final purchase = _kind == ItemKind.purchase;

    DateTime? due;
    if (!recurring && _date != null) {
      due = DateTime(_date!.year, _date!.month, _date!.day, _minutes ~/ 60,
          _minutes % 60);
    }
    final target = purchase ? parseMoney(_target.text) : null;
    final saved = purchase ? (parseMoney(_saved.text) ?? 0) : 0.0;
    final amount = recurring ? parseMoney(_amount.text) : null;

    final hasStatus = _kind == ItemKind.work || _kind == ItemKind.task;
    var status = hasStatus ? _status : ItemStatus.pending;
    DateTime? completedAt = old?.completedAt;
    if (status == ItemStatus.done) {
      completedAt ??= DateTime.now();
    } else {
      completedAt = null;
    }

    final item = Item(
      id: old?.id ?? store.nextId(),
      createdAt: old?.createdAt ?? DateTime.now(),
      title: _title.text.trim(),
      notes: _notes.text.trim(),
      kind: _kind,
      priority: _priority,
      status: status,
      completedAt: completedAt,
      dueDate: due,
      reminderMinutes: purchase ? null : _reminder,
      targetAmount: target,
      savedAmount: saved,
      recurrenceDay: _day,
      dueMinutes: _minutes,
      amount: amount,
      paidMonths: old?.paidMonths ?? const {},
    );
    await store.upsert(item);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final recurring = _kind == ItemKind.recurring;
    final purchase = _kind == ItemKind.purchase;
    final hasDue = recurring || _date != null;
    final hasStatus = _kind == ItemKind.work || _kind == ItemKind.task;

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Editar ${_kindName(_kind)}' : 'Nov${_kind == ItemKind.recurring ? 'o' : 'a'} ${_kindName(_kind)}'),
        actions: [
          if (_editing)
            IconButton(
              tooltip: 'Excluir',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                final nav = Navigator.of(context);
                await deleteWithUndo(context, widget.item!);
                nav.pop();
              },
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: FilledButton(onPressed: _save, child: const Text('Salvar')),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
              children: [
                if (!_editing && widget.initialKind == null) ...[
                _Label('Tipo'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final k in ItemKind.values)
                      ChoiceChip(
                        avatar: Icon(k.icon,
                            size: 18,
                            color: _kind == k ? null : k.color),
                        label: Text(k.label),
                        selected: _kind == k,
                        onSelected: (_) => setState(() => _kind = k),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                ],
                TextFormField(
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Título',
                    hintText: switch (_kind) {
                      ItemKind.purchase => 'Ex.: Notebook novo',
                      ItemKind.work => 'Ex.: Entregar relatório trimestral',
                      ItemKind.task => 'Ex.: Marcar consulta',
                      ItemKind.recurring => 'Ex.: Aluguel',
                    },
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Informe um título'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                      labelText: 'Observações (opcional)'),
                ),
                const SizedBox(height: 20),
                _Label('Prioridade'),
                SegmentedButton<ItemPriority>(
                  showSelectedIcon: false,
                  segments: [
                    for (final p in ItemPriority.values)
                      ButtonSegment(
                          value: p,
                          label: Text(p.label),
                          icon: Icon(p.icon, color: p.color)),
                  ],
                  selected: {_priority},
                  onSelectionChanged: (s) =>
                      setState(() => _priority = s.first),
                ),
                if (hasStatus) ...[
                  const SizedBox(height: 20),
                  _Label('Status'),
                  SegmentedButton<ItemStatus>(
                    showSelectedIcon: false,
                    segments: [
                      for (final s in ItemStatus.values)
                        ButtonSegment(value: s, label: Text(s.label)),
                    ],
                    selected: {_status},
                    onSelectionChanged: (s) => setState(() => _status = s.first),
                  ),
                ],
                if (purchase) ...[
                  const SizedBox(height: 20),
                  _Label('Meta financeira'),
                  Row(
                    children: [
                      Expanded(child: _moneyField(_target, 'Valor da meta')),
                      const SizedBox(width: 12),
                      Expanded(child: _moneyField(_saved, 'Já guardado')),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                _Label(recurring
                    ? 'Repetição mensal'
                    : (purchase ? 'Data alvo (opcional)' : 'Prazo')),
                if (recurring)
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _day,
                          decoration:
                              const InputDecoration(labelText: 'Dia do mês'),
                          items: [
                            for (var d = 1; d <= 31; d++)
                              DropdownMenuItem(value: d, child: Text('Dia $d')),
                          ],
                          onChanged: (v) => setState(() => _day = v ?? _day),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _timeButton()),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: _outlined(),
                          onPressed: _pickDate,
                          icon: const Icon(Icons.event_rounded),
                          label: Text(
                              _date == null ? 'Definir data' : longDate(_date!),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ),
                      if (_date != null) ...[
                        const SizedBox(width: 8),
                        if (!purchase) _timeButton(),
                        IconButton(
                          tooltip: 'Remover prazo',
                          onPressed: () => setState(() {
                            _date = null;
                          }),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ],
                  ),
                if (recurring) ...[
                  const SizedBox(height: 12),
                  _moneyField(_amount, 'Valor (opcional)'),
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Text(
                      'Em meses curtos, o dia $_day vira o último dia do mês.',
                      style: t.textTheme.bodySmall
                          ?.copyWith(color: t.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
                if (!purchase) ...[
                const SizedBox(height: 20),
                _Label('Lembrete'),
                DropdownButtonFormField<int?>(
                  initialValue: _reminder,
                  decoration: InputDecoration(
                    prefixIcon:
                        const Icon(Icons.notifications_active_outlined),
                    helperText: hasDue
                        ? null
                        : 'Defina um prazo para receber o lembrete',
                  ),
                  items: [
                    for (final e in reminderOptions.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => _reminder = v),
                ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _kindName(ItemKind k) => switch (k) {
        ItemKind.purchase => 'meta de compra',
        ItemKind.work => 'demanda',
        ItemKind.task => 'tarefa',
        ItemKind.recurring => 'compromisso recorrente',
      };

  ButtonStyle _outlined() => OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        alignment: Alignment.centerLeft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      );

  Widget _timeButton() => OutlinedButton.icon(
        style: _outlined(),
        onPressed: _pickTime,
        icon: const Icon(Icons.schedule_rounded),
        label: Text(minutesToClock(_minutes)),
      );

  Widget _moneyField(TextEditingController c, String label) => TextFormField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
        decoration: InputDecoration(labelText: label, prefixText: 'R\$ '),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
      );
}
