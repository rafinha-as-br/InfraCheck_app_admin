# Visão geral do InfraCheck_app_admin

## Responsabilidade

Painel web (Flutter) para quem programa, acompanha e revisa inspeções. **Não** contém regra de domínio: o servidor
valida tudo (por exemplo, recusa a aprovação sem plano de ação); o painel apenas antecipa o bloqueio na tela.

## Estrutura

| Caminho | Conteúdo | Estado |
| --- | --- | --- |
| `lib/main.dart`, `lib/app.dart` | Boot, tema, rotas por URL (`onGenerateRoute`), retorno ao login ao perder a sessão | Implementado |
| `lib/core/` | `config.dart` (`API_BASE_URL`), `session.dart` (`SessionController`, `SessionStore`, `AppScope`), `async_state.dart` (`AsyncState`/`AsyncController` com descarte de respostas obsoletas) | Implementado |
| `lib/presentation/routes.dart` | Rotas nomeadas | Implementado |
| `lib/presentation/widgets/` | `AppShell` (sidebar 248 px / gaveta < 900 px), `Panel`, `KpiCard`, `DataGridView`, `BarRow`, `StateMessage`, `KeyValueList` | Implementado |
| `lib/presentation/login`, `dashboard`, `inspections`, `inspection_detail` | Telas W01–W04 | Implementado |
| Administração (formulários, usuários) | Seção da sidebar só para Administrador no design | **Não implementado** |
| Seletor de período do dashboard, notificações, mapa, download do PDF | Presentes no design ou previstos | **Não implementado** |

## Fluxo de dados

`Página (StatefulWidget) → Controller (ChangeNotifier) → InfraCheckApi (InfraCheck_modules) → API`.
Widgets de exibição não chamam a rede. Erros chegam como `ApiError` e viram mensagem amigável na tela.

## Detalhes

- **Sessão:** JWT no `shared_preferences` (localStorage) só quando "Manter conectado" está marcado. Antes de produção
  avaliar cookie `HttpOnly`.
- **URL como fonte de verdade:** `/inspections/<id>` e `?status=` sobrevivem a recarregar a página (nada de objetos
  em `extra`).
- **Responsivo:** abaixo de 900 px a sidebar vira gaveta; tabelas rolam horizontalmente.
- **Fotos e assinatura:** carregadas por `ApiImage` com o JWT.
- **Plano de ação:** formulário por não conformidade; "Aprovar" fica desabilitado enquanto houver Alta/Crítica sem plano.
