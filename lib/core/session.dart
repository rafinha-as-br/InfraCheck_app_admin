import 'package:flutter/widgets.dart';
import 'package:infracheck_modules/infracheck_modules.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistência do token de sessão no navegador.
///
/// Protótipo: o JWT fica no armazenamento local do navegador quando o usuário marca "Manter conectado".
/// Antes de produção, avaliar cookie `HttpOnly` emitido pelo servidor (reduz o risco de XSS).
class SessionStore {
  static const _key = 'infracheck.token';

  Future<String?> read() async => (await SharedPreferences.getInstance()).getString(_key);

  Future<void> write(String token) async => (await SharedPreferences.getInstance()).setString(_key, token);

  Future<void> clear() async => (await SharedPreferences.getInstance()).remove(_key);
}

/// Sessão do painel: usuário autenticado e acesso ao cliente da API.
///
/// Só Administrador e Gestor de Contrato usam o painel; inspetores são direcionados ao app.
class SessionController extends ChangeNotifier {
  SessionController({required this.api, required SessionStore store}) : _store = store {
    api.onUnauthorized = () {
      if (_user != null) logout();
    };
  }

  final InfraCheckApi api;
  final SessionStore _store;
  UserInfo? _user;
  bool _restoring = true;

  UserInfo? get user => _user;
  bool get isLoggedIn => _user != null;

  /// `true` até terminar de tentar restaurar a sessão salva (evita piscar a tela de login).
  bool get restoring => _restoring;

  /// Retoma a sessão salva, se o token ainda for válido.
  Future<void> restore() async {
    final saved = await _store.read();
    if (saved != null) {
      api.token = saved;
      try {
        final me = await api.me();
        if (me.role.isManagement) _user = me;
      } on ApiError catch (e) {
        // Sem rede: mantém o token para uma próxima tentativa; token inválido: descarta.
        if (!e.isNetwork) await _discard();
      }
    }
    _restoring = false;
    notifyListeners();
  }

  /// Autentica. Devolve a mensagem de erro para a tela, ou `null` em caso de sucesso.
  Future<String?> login(String email, String password, {required bool remember}) async {
    try {
      final result = await api.login(email, password);
      if (!result.user.role.isManagement) {
        api.token = null;
        return 'Inspetores acessam o aplicativo InfraCheck no celular.';
      }
      api.token = result.token;
      if (remember) await _store.write(result.token);
      _user = result.user;
      notifyListeners();
      return null;
    } on ApiError catch (e) {
      return e.isNetwork ? e.message : (e.status == 401 ? 'E-mail ou senha incorretos.' : e.fullMessage);
    }
  }

  Future<void> logout() async {
    await _discard();
    ApiImage.clearCache();
    notifyListeners();
  }

  Future<void> _discard() async {
    api.token = null;
    _user = null;
    await _store.clear();
  }
}

/// Disponibiliza a [SessionController] para a árvore de widgets.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.session, required super.child});

  final SessionController session;

  static SessionController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope ausente na árvore');
    return scope!.session;
  }

  @override
  bool updateShouldNotify(AppScope old) => session != old.session;
}
