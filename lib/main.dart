import 'package:flutter/material.dart';
import 'package:infracheck_modules/infracheck_modules.dart';

import 'app.dart';
import 'core/config.dart';
import 'core/session.dart';

/// Ponto de entrada do painel de gestão InfraCheck (Flutter web).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final api = InfraCheckApi(baseUrl: AppConfig.apiBaseUrl);
  final session = SessionController(api: api, store: SessionStore());
  await session.restore();
  runApp(AdminApp(session: session));
}
