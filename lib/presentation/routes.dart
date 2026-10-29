/// Rotas nomeadas do painel (centralizadas; nunca usar strings de caminho soltas).
abstract final class Routes {
  static const login = '/login';
  static const dashboard = '/dashboard';
  static const inspections = '/inspections';

  /// Lista de inspeções já filtrada por status (ex.: vindo do dashboard).
  static String inspectionsWithStatus(String apiStatus) => '/inspections?status=$apiStatus';

  /// Detalhe/revisão de uma inspeção. O id fica na URL, então sobrevive a recarregar a página.
  static String inspection(String id) => '/inspections/$id';
}
