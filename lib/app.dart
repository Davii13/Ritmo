import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/store.dart';
import 'screens/dashboard_screen.dart';
import 'screens/item_form_screen.dart';
import 'screens/kind_screen.dart';
import 'screens/settings_screen.dart';
import 'services/notification_service.dart';
import 'models/item.dart';
import 'theme.dart';
import 'widgets/common.dart';

class RitmoApp extends StatefulWidget {
  const RitmoApp({super.key, required this.store, required this.notifications});

  final RitmoStore store;
  final NotificationService notifications;

  @override
  State<RitmoApp> createState() => _RitmoAppState();
}

class _RitmoAppState extends State<RitmoApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.store.addListener(_syncNotifications);
    _syncNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.store.removeListener(_syncNotifications);
    super.dispose();
  }

  void _syncNotifications() => widget.notifications
      .sync(widget.store.items, enabled: widget.store.notificationsEnabled);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Novo dia: reavalia "hoje/atrasado" e reagenda os lembretes.
      setState(() {});
      _syncNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: widget.store,
      child: Builder(builder: (context) {
        final store = StoreScope.of(context);
        return MaterialApp(
          title: 'Ritmo',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: store.themeMode,
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Shell(notifications: widget.notifications),
        );
      }),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key, required this.notifications});

  final NotificationService notifications;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  /// Cada tipo de cadastro tem a sua própria aba (índice 0 é o painel).
  static const _tabs = <({IconData icon, IconData selected, String label, ItemKind? kind})>[
    (icon: Icons.dashboard_outlined, selected: Icons.dashboard_rounded, label: 'Painel', kind: null),
    (icon: Icons.shopping_bag_outlined, selected: Icons.shopping_bag_rounded, label: 'Metas', kind: ItemKind.purchase),
    (icon: Icons.work_outline_rounded, selected: Icons.work_rounded, label: 'Demandas', kind: ItemKind.work),
    (icon: Icons.check_circle_outline_rounded, selected: Icons.check_circle_rounded, label: 'Tarefas', kind: ItemKind.task),
    (icon: Icons.event_repeat_outlined, selected: Icons.event_repeat_rounded, label: 'Recorrentes', kind: ItemKind.recurring),
  ];

  void _go(int i) => setState(() => _index = i);

  void _openSettings() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Ajustes')),
          body: SettingsScreen(notifications: widget.notifications),
        ),
      ));

  Future<void> _create() async {
    final kind = _tabs[_index].kind;
    if (kind != null) return openItemForm(context, kind: kind);
    final picked = await showModalBottomSheet<ItemKind>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final k in ItemKind.values)
              ListTile(
                leading: Icon(k.icon, color: k.color),
                title: Text(k.label),
                onTap: () => Navigator.pop(ctx, k),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) openItemForm(context, kind: picked);
  }

  @override
  Widget build(BuildContext context) {
    final kind = _tabs[_index].kind;
    final page = kind == null ? const DashboardScreen() : KindScreen(kind: kind);

    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= wideBreakpoint;
      final body = SafeArea(
        bottom: false,
        child: Stack(children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: KeyedSubtree(key: ValueKey(_index), child: page),
            ),
          ),
          if (!wide)
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                tooltip: 'Ajustes',
                onPressed: _openSettings,
                icon: const Icon(Icons.settings_outlined),
              ),
            ),
        ]),
      );

      final addLabel = switch (kind) {
        null => 'Novo cadastro',
        ItemKind.purchase => 'Nova meta',
        ItemKind.work => 'Nova demanda',
        ItemKind.task => 'Nova tarefa',
        ItemKind.recurring => 'Novo compromisso',
      };
      final fab = wide
          ? FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.add_rounded),
              label: Text(addLabel),
            )
          : FloatingActionButton(
              tooltip: addLabel,
              onPressed: _create,
              child: const Icon(Icons.add_rounded),
            );

      if (wide) {
        return Scaffold(
          floatingActionButton: fab,
          body: Row(
            children: [
              NavigationRail(
                extended: c.maxWidth >= 1100,
                selectedIndex: _index,
                onDestinationSelected: _go,
                leading: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: _Brand(),
                ),
                trailing: Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: IconButton(
                        tooltip: 'Ajustes',
                        onPressed: _openSettings,
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    ),
                  ),
                ),
                destinations: [
                  for (final d in _tabs)
                    NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selected),
                        label: Text(d.label)),
                ],
              ),
              Expanded(child: body),
            ],
          ),
        );
      }

      return Scaffold(
        floatingActionButton: fab,
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _go,
          destinations: [
            for (final d in _tabs)
              NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selected),
                  label: d.label),
          ],
        ),
      );
    });
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: s.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.graphic_eq_rounded, color: s.onPrimary),
    );
  }
}
