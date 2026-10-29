import 'package:flutter/material.dart';
import 'package:infracheck_modules/infracheck_modules.dart';

import 'core/session.dart';
import 'presentation/dashboard/dashboard_page.dart';
import 'presentation/inspection_detail/inspection_detail_page.dart';
import 'presentation/inspections/inspections_page.dart';
import 'presentation/login/login_page.dart';
import 'presentation/routes.dart';

/// Aplicação raiz do painel: tema InfraCheck, rotas por URL e guarda de autenticação.
class AdminApp extends StatefulWidget {
  const AdminApp({super.key, required this.session});

  final SessionController session;

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  final _navigator = GlobalKey<NavigatorState>();
  late bool _wasLoggedIn = widget.session.isLoggedIn;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    super.dispose();
  }

  /// Ao perder a sessão (logout ou 401), volta ao login limpando a pilha.
  void _onSessionChanged() {
    final logged = widget.session.isLoggedIn;
    if (_wasLoggedIn && !logged) {
      _navigator.currentState?.pushNamedAndRemoveUntil(Routes.login, (_) => false);
    }
    _wasLoggedIn = logged;
  }

  Route<dynamic> _onGenerateRoute(RouteSettings settings) {
    final uri = Uri.parse(settings.name ?? '/');
    final segments = uri.pathSegments;
    Widget page;
    if (!widget.session.isLoggedIn) {
      page = const LoginPage();
    } else if (segments.isEmpty || segments.first == 'dashboard' || segments.first == 'login') {
      page = const DashboardPage();
    } else if (segments.first == 'inspections' && segments.length == 2) {
      page = InspectionDetailPage(inspectionId: segments[1]);
    } else if (segments.first == 'inspections') {
      final status = uri.queryParameters['status'];
      page = InspectionsPage(
          initialStatus: status == null ? null : enumFromApiOrNull(InspectionStatus.values, status));
    } else {
      page = const DashboardPage();
    }
    return PageRouteBuilder<void>(
      settings: settings,
      pageBuilder: (_, _, _) => page,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      session: widget.session,
      child: MaterialApp(
        title: 'InfraCheck — Painel de gestão',
        debugShowCheckedModeBanner: false,
        theme: InfraCheckTheme.light(),
        navigatorKey: _navigator,
        initialRoute: widget.session.isLoggedIn ? Routes.dashboard : Routes.login,
        onGenerateRoute: _onGenerateRoute,
      ),
    );
  }
}
