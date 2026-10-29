import 'package:flutter/foundation.dart';
import 'package:infracheck_modules/infracheck_modules.dart';

/// Estado imutável de uma operação assíncrona: carregando, dado e/ou erro.
///
/// Mantém o [data] anterior durante um recarregamento, evitando que a tela "pisque" vazia.
@immutable
class AsyncState<T> {
  const AsyncState({this.loading = false, this.data, this.error});

  final bool loading;
  final T? data;

  /// Mensagem amigável do último erro (nunca stack trace).
  final String? error;

  bool get hasData => data != null;
}

/// Controller genérico para telas que carregam um único recurso.
///
/// Respostas obsoletas são descartadas: se [load] for chamado de novo antes do anterior terminar,
/// só o resultado da chamada mais recente é aplicado.
class AsyncController<T> extends ChangeNotifier {
  AsyncState<T> _state = const AsyncState(loading: true);
  int _generation = 0;
  bool _disposed = false;

  AsyncState<T> get state => _state;

  Future<void> load(Future<T> Function() fetch) async {
    final mine = ++_generation;
    _emit(AsyncState(loading: true, data: _state.data));
    try {
      final result = await fetch();
      if (mine == _generation) _emit(AsyncState(data: result));
    } on ApiError catch (e) {
      if (mine == _generation) _emit(AsyncState(data: _state.data, error: e.fullMessage));
    }
  }

  void _emit(AsyncState<T> s) {
    if (_disposed) return;
    _state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
