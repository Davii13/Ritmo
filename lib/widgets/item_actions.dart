import 'package:flutter/material.dart';

import '../models/item.dart';
import '../screens/item_form_screen.dart';
import '../utils/format.dart';
import 'common.dart';

Future<void> deleteWithUndo(BuildContext context, Item item) async {
  final store = StoreScope.of(context);
  final messenger = ScaffoldMessenger.of(context);
  await store.remove(item.id);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text('"${item.title}" excluído'),
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(label: 'Desfazer', onPressed: () => store.upsert(item)),
    ));
}

/// Diálogo para somar (ou subtrair, com valor negativo) ao valor guardado.
Future<void> addSavedDialog(BuildContext context, Item item) async {
  final store = StoreScope.of(context);
  final controller = TextEditingController();
  final value = await showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Adicionar valor'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Guardado: ${money(item.savedAmount)}'
              '${item.targetAmount != null ? ' de ${money(item.targetAmount!)}' : ''}'),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: true),
            decoration: const InputDecoration(
                labelText: 'Valor', prefixText: 'R\$ ',
                helperText: 'Use um valor negativo para retirar'),
            onSubmitted: (_) =>
                Navigator.pop(ctx, parseMoney(controller.text)),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, parseMoney(controller.text)),
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (value != null && value != 0) {
    await store.addSaved(item, value);
  }
}

Future<void> confirmClearAll(BuildContext context) async {
  final store = StoreScope.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Apagar todos os dados?'),
      content: const Text(
          'Todas as metas, tarefas e compromissos serão removidos deste dispositivo. Esta ação não pode ser desfeita.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Apagar tudo'),
        ),
      ],
    ),
  );
  if (ok == true) await store.clearAll();
}

void openItem(BuildContext context, Item item) => openItemForm(context, item: item);
