# InfraCheck_app_admin

Painel de gestão do InfraCheck (**Flutter web**) para Administradores e Gestores de Contrato: dashboard, listagem e
criação de inspeções, revisão com plano de ação e aprovação/rejeição.

> **Estado: protótipo do MVP**, seguindo os designs W01–W04 do canvas "InfraCheck — Protótipo MVP". Consome o
> `InfraCheck_Server` e o pacote compartilhado `InfraCheck_modules`.

## Rodar

Pré-requisitos: Flutter 3.35+ e a API rodando (ver `InfraCheck_Server/README.md`).

```bash
flutter pub get
flutter run -d chrome                                  # API em http://localhost:8080
flutter run -d chrome --dart-define=API_BASE_URL=https://api.exemplo.com
```

Login de demonstração: `helena.prado@infracheck.com.br` (a senha dos usuários de demonstração está em
`DevDataSeeder.DEMO_PASSWORD`, no servidor). Inspetores não acessam o painel.

## Telas

| Design | Rota | Arquivo |
| --- | --- | --- |
| W01 Login | `/login` | `presentation/login/login_page.dart` |
| W02 Dashboard | `/dashboard` | `presentation/dashboard/dashboard_page.dart` |
| W03 Inspeções (+ modal "Nova inspeção") | `/inspections?status=...` | `presentation/inspections/` |
| W04 Detalhes e aprovação | `/inspections/<id>` | `presentation/inspection_detail/` |

## Testes

```bash
flutter analyze && flutter test
```

Cobrem sessão (papéis, "manter conectado", 401) e o controller da revisão (bloqueio de aprovação sem plano de ação,
erros do servidor). Mais em [docs/](docs/overview.md).
