import 'package:flutter/foundation.dart';
import 'package:infracheck_modules/infracheck_modules.dart';

import '../../core/async_state.dart';

/// Orquestra a tela de detalhe/revisão: carga da inspeção e as ações do gestor
/// (plano de ação, aprovar, rejeitar). Quem chama decide como reagir ao resultado (SnackBar etc.).
class InspectionDetailController extends ChangeNotifier {
  InspectionDetailController(this._api, this.inspectionId);

  final InfraCheckApi _api;
  final String inspectionId;

  AsyncState<InspectionDetail> _state = const AsyncState(loading: true);
  bool _busy = false;
  String? _actionError;
  bool _disposed = false;

  AsyncState<InspectionDetail> get state => _state;

  /// `true` enquanto uma ação (salvar plano, aprovar, rejeitar) está em andamento.
  bool get busy => _busy;

  /// Último erro de ação, com os detalhes do servidor (ex.: itens sem plano de ação).
  String? get actionError => _actionError;

  Future<void> load() async {
    _emit(() => _state = AsyncState(loading: true, data: _state.data));
    try {
      final d = await _api.getInspection(inspectionId);
      _emit(() => _state = AsyncState(data: d));
    } on ApiError catch (e) {
      _emit(() => _state = AsyncState(data: _state.data, error: e.fullMessage));
    }
  }

  /// Itens Alta/Crítica sem plano de ação: bloqueiam a aprovação (o servidor também valida).
  List<InspectionItem> get itemsMissingPlan => (_state.data?.items ?? const [])
      .where((i) => i.isNonConforming && (i.criticality?.requiresActionPlan ?? false) && i.actionPlans.isEmpty)
      .toList();

  Future<bool> savePlan({required String itemId, required String responsible, required DateTime dueDate, required String action}) =>
      _act(() => _api.addActionPlan(inspectionId, itemId: itemId, responsible: responsible, dueDate: dueDate, action: action));

  Future<bool> approve() => _act(() => _api.approve(inspectionId));

  Future<bool> reject(String reason) => _act(() => _api.reject(inspectionId, reason));

  Future<bool> _act(Future<InspectionDetail> Function() run) async {
    _emit(() {
      _busy = true;
      _actionError = null;
    });
    try {
      final d = await run();
      _emit(() {
        _busy = false;
        _state = AsyncState(data: d);
      });
      return true;
    } on ApiError catch (e) {
      _emit(() {
        _busy = false;
        _actionError = e.fullMessage;
      });
      return false;
    }
  }

  void clearActionError() => _emit(() => _actionError = null);

  void _emit(VoidCallback mutate) {
    if (_disposed) return;
    mutate();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
