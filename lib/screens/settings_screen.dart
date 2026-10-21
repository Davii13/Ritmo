import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/item.dart';
import '../services/notification_service.dart';
import '../widgets/common.dart';
import '../widgets/item_actions.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.notifications});

  final NotificationService notifications;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context);
    final supported = NotificationService.supported;

    return PageBody(
      maxWidth: 720,
      children: [
        const SectionHeader('Aparência', icon: Icons.palette_outlined),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('Sistema'),
                    icon: Icon(Icons.brightness_auto_rounded)),
                ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Claro'),
                    icon: Icon(Icons.light_mode_rounded)),
                ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Escuro'),
                    icon: Icon(Icons.dark_mode_rounded)),
              ],
              selected: {store.themeMode},
              onSelectionChanged: (s) => store.setThemeMode(s.first),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader('Notificações', icon: Icons.notifications_outlined),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Lembretes de vencimento'),
                subtitle: Text(supported
                    ? 'Avisa antes do prazo de tarefas, demandas e pagamentos.'
                    : kIsWeb
                        ? 'O navegador não agenda avisos com o app fechado. Os vencimentos aparecem no painel e nas abas.'
                        : 'Notificações não são suportadas nesta plataforma.'),
                value: store.notificationsEnabled && supported,
                onChanged: supported
                    ? (v) async {
                        if (v) {
                          final granted = await notifications.requestPermission();
                          if (!granted && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                behavior: SnackBarBehavior.floating,
                                content: Text(
                                    'Permissão negada. Ative as notificações do Ritmo nas configurações do sistema.'),
                              ),
                            );
                          }
                        }
                        await store.setNotificationsEnabled(v);
                      }
                    : null,
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: DropdownButtonFormField<int?>(
                  initialValue: store.defaultReminder,
                  decoration: const InputDecoration(
                    labelText: 'Antecedência padrão para novos itens',
                    prefixIcon: Icon(Icons.timer_outlined),
                  ),
                  items: [
                    for (final e in reminderOptions.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => store.setDefaultReminder(v),
                ),
              ),
              if (supported && store.notificationsEnabled)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: notifications.showTest,
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('Enviar notificação de teste'),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader('Dados', icon: Icons.storage_rounded),
        Card(
          child: ListTile(
            leading: Icon(Icons.delete_forever_rounded, color: t.colorScheme.error),
            title: const Text('Apagar todos os dados'),
            subtitle: Text(
                '${store.items.length} itens salvos neste dispositivo'),
            onTap: store.items.isEmpty ? null : () => confirmClearAll(context),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text('Ritmo · seus dados ficam apenas neste dispositivo',
              style: t.textTheme.bodySmall
                  ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
        ),
      ],
    );
  }
}
