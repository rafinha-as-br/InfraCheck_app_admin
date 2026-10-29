import 'package:flutter/foundation.dart';
import 'package:infracheck_modules/infracheck_modules.dart';

import '../../core/async_state.dart';

/// Estado da listagem: filtros, página atual, resultado e contagens por status.
@immutable
class InspectionListState {
  const InspectionListState({
    this.status,
    this.inspectorId,
    this.type,
    this.query = '',
    this.page = 0,
    this.result = const AsyncState(loading: true),
    this.counts = const {},
    this.inspectors = const [],
  });

  final InspectionStatus? status;
  final String? inspectorId;
  final InspectionType? type;
  final String query;
  final int page;
  final AsyncState<PageResult<InspectionSummary>> result;
  final Map<InspectionStatus, int> counts;
  final List<InspectorOption> inspectors;

  static const pageSize = 10;

  int get totalCount => counts.values.fold(0, (a, b) => a + b);

  InspectionListState copyWith({
    Object? status = _keep,
    Object? inspectorId = _keep,
    Object? type = _keep,
    String? query,
    int? page,
    AsyncState<PageResult<InspectionSummary>>? result,
    Map<InspectionStatus, int>? counts,
    List<InspectorOption>? inspectors,
  }) =>
      InspectionListState(
        status: identical(status, _keep) ? this.status : status as InspectionStatus?,
        inspectorId: identical(inspectorId, _keep) ? this.inspectorId : inspectorId as String?,
        type: identical(type, _keep) ? this.type : type as InspectionType?,
        query: query ?? this.query,
        page: page ?? this.page,
        result: result ?? this.result,
        counts: counts ?? this.counts,
        inspectors: inspectors ?? this.inspectors,
      );

  static const _keep = Object();
}

/// Orquestra a listagem de inspeções (filtros, busca, paginação). Respostas obsoletas são descartadas.
class InspectionListController extends ChangeNotifier {
  InspectionListController(this._api, {InspectionStatus? initialStatus}) : _state = InspectionListState(status: initialStatus);

  final InfraCheckApi _api;
  InspectionListState _state;
  int _generation = 0;
  bool _disposed = false;

  InspectionListState get state => _state;

  /// Carga inicial: lista, contagens e inspetores (para o filtro).
  Future<void> init() async {
    await Future.wait([_loadPage(), _loadCounts(), _loadInspectors()]);
  }

  Future<void> refresh() async => Future.wait([_loadPage(), _loadCounts()]);

  void setStatus(InspectionStatus? s) => _apply(_state.copyWith(status: s, page: 0));
  void setInspector(String? id) => _apply(_state.copyWith(inspectorId: id, page: 0));
  void setType(InspectionType? t) => _apply(_state.copyWith(type: t, page: 0));
  void setQuery(String q) => _apply(_state.copyWith(query: q, page: 0));

  void nextPage() {
    final r = _state.result.data;
    if (r != null && (_state.page + 1) * InspectionListState.pageSize < r.total) _apply(_state.copyWith(page: _state.page + 1));
  }

  void previousPage() {
    if (_state.page > 0) _apply(_state.copyWith(page: _state.page - 1));
  }

  void _apply(InspectionListState s) {
    _emit(s);
    _loadPage();
  }

  Future<void> _loadPage() async {
    final mine = ++_generation;
    _emit(_state.copyWith(result: AsyncState(loading: true, data: _state.result.data)));
    try {
      final page = await _api.listInspections(
        status: _state.status,
        inspectorId: _state.inspectorId,
        type: _state.type,
        q: _state.query,
        page: _state.page,
        size: InspectionListState.pageSize,
      );
      if (mine == _generation) _emit(_state.copyWith(result: AsyncState(data: page)));
    } on ApiError catch (e) {
      if (mine == _generation) _emit(_state.copyWith(result: AsyncState(data: _state.result.data, error: e.fullMessage)));
    }
  }

  Future<void> _loadCounts() async {
    try {
      final counts = await _api.counts(); // aguardar ANTES de ler _state (evita sobrescrever com estado antigo)
      _emit(_state.copyWith(counts: counts));
    } on ApiError {
      // contagens são acessórias: a listagem continua útil sem elas
    }
  }

  Future<void> _loadInspectors() async {
    try {
      final inspectors = await _api.inspectors();
      _emit(_state.copyWith(inspectors: inspectors));
    } on ApiError {
      // filtro por inspetor fica vazio
    }
  }

  void _emit(InspectionListState s) {
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
