import 'package:flutter/material.dart';
import 'package:infracheck_modules/infracheck_modules.dart';

import '../../core/session.dart';
import '../routes.dart';

/// Destinos da sidebar. Gestor de Contrato vê Dashboard e Inspeções (Formulários e Usuários, da
/// seção "Administração", ainda não existem no MVP).
enum NavDestination { dashboard, inspections }

/// Moldura das telas autenticadas: sidebar fixa (248 px, `primary-900`) + topo branco + miolo `surface-50`.
/// Abaixo de 900 px a sidebar vira gaveta.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.current, required this.title, this.subtitle, this.actions = const [], required this.child});

  final NavDestination current;
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;

  static const _wide = 900.0;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= _wide;
    final content = Column(children: [
      _TopBar(title: title, subtitle: subtitle, actions: actions, showMenu: !wide),
      Expanded(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: wide ? IcSpacing.s10 : IcSpacing.s4, vertical: IcSpacing.s8),
          child: Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1400), child: child)),
        ),
      ),
    ]);
    return Scaffold(
      backgroundColor: IcColors.surface50,
      drawer: wide ? null : Drawer(backgroundColor: IcColors.primary900, child: _Sidebar(current: current)),
      body: wide
          ? Row(children: [
              SizedBox(width: 248, child: _Sidebar(current: current)),
              Expanded(child: content),
            ])
          : content,
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, this.subtitle, required this.actions, required this.showMenu});

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: IcSpacing.s6, vertical: IcSpacing.s4),
      decoration: const BoxDecoration(color: IcColors.surface0, border: Border(bottom: BorderSide(color: IcColors.borderSubtle))),
      child: Row(children: [
        if (showMenu)
          Builder(
              builder: (ctx) => IconButton(
                  tooltip: 'Abrir menu', icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(ctx).openDrawer())),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.headlineMedium),
            if (subtitle != null) Text(subtitle!, style: t.bodySmall?.copyWith(color: IcColors.ink600)),
          ]),
        ),
        ...actions,
      ]),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.current});

  final NavDestination current;

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    final user = session.user;
    final t = Theme.of(context).textTheme;
    return Container(
      color: IcColors.primary900,
      padding: const EdgeInsets.all(IcSpacing.s4),
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Padding(
              padding: EdgeInsets.fromLTRB(8, 8, 8, 28),
              child: Align(alignment: Alignment.centerLeft, child: IcLogo(LogoVariant.horizontalReverse, height: 36))),
          _NavItem(
              icon: Icons.grid_view_rounded,
              label: 'Dashboard',
              active: current == NavDestination.dashboard,
              onTap: () => Navigator.of(context).pushReplacementNamed(Routes.dashboard)),
          _NavItem(
              icon: Icons.fact_check_outlined,
              label: 'Inspeções',
              active: current == NavDestination.inspections,
              onTap: () => Navigator.of(context).pushReplacementNamed(Routes.inspections)),
          const Spacer(),
          const Divider(color: Color(0x24FFFFFF)),
          const SizedBox(height: IcSpacing.s3),
          if (user != null)
            Row(children: [
              CircleAvatar(
                  radius: 20,
                  backgroundColor: IcColors.primary100,
                  child: Text(user.initials, style: t.labelLarge?.copyWith(color: IcColors.primary900))),
              const SizedBox(width: IcSpacing.s3),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.name, style: t.bodyMedium?.copyWith(color: IcColors.onPrimary, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  Text(user.role.label, style: t.bodySmall?.copyWith(color: IcColors.onPrimaryMuted)),
                ]),
              ),
            ]),
          const SizedBox(height: IcSpacing.s2),
          _NavItem(icon: Icons.logout, label: 'Sair', active: false, onTap: () => session.logout()),
        ]),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: active ? IcColors.primary700 : Colors.transparent,
        borderRadius: BorderRadius.circular(IcRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(IcRadius.md),
          onTap: onTap,
          child: Container(
            height: IcSpacing.control,
            padding: const EdgeInsets.symmetric(horizontal: IcSpacing.s3),
            child: Row(children: [
              Icon(icon, size: 20, color: active ? IcColors.signal500 : IcColors.onPrimaryMuted),
              const SizedBox(width: IcSpacing.s3),
              Text(label,
                  style: t.labelLarge?.copyWith(color: active ? IcColors.onPrimary : IcColors.onPrimaryMuted)),
            ]),
          ),
        ),
      ),
    );
  }
}
