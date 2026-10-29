# InfraCheck App Admin — contexto para agentes

## Propósito

Este repositório abriga a aplicação web de gestão da InfraCheck. Ela atende administradores, gestores de contrato e demais colaboradores que programam, acompanham e revisam inspeções.

O contexto de produto compartilhado está em `../../AGENTS.md`; os documentos de briefing e detalhamento operacional referenciados nele são a fonte de verdade para regras de negócio ainda não implementadas.

## Responsabilidade no fluxo

A aplicação web deve dar suporte principalmente a:

- gestão de usuários e visibilidade conforme os papéis Administrador, Gestor de Contrato e Inspetor;
- gestão de contratos, clientes, locais e formulários/checklists configuráveis e versionados;
- criação e atribuição de ordens de serviço a inspetores, com prazo e observações prévias;
- acompanhamento da operação por contrato, inspetor, período e status;
- revisão de inspeções concluídas, incluindo respostas, fotos, localização, assinatura e histórico;
- aprovação ou rejeição de inspeções;
- registro de planos de ação para não conformidades Alta ou Crítica antes da aprovação;
- consulta ao relatório PDF gerado pelo sistema e ao histórico auditável.

## Limites e cuidados

- O gestor revisa e aprova; o relatório não deve ser montado ou editado manualmente na interface. Ele deriva fielmente dos dados aprovados da inspeção.
- A execução em campo, a coleta offline e a sincronização pertencem ao app do inspetor, em `../InfraCheck_app_inspetor`.
- Autenticação, autorização efetiva, regras de domínio, persistência e geração de PDF pertencem ao servidor, em `../InfraCheck_Server`. Não duplique essas regras no front-end.
- Informações de localização, imagens, assinaturas e dados de clientes exigem tratamento compatível com a LGPD.
- O repositório está em estado inicial. Não suponha framework, arquitetura ou contratos de API que ainda não tenham sido definidos e documentados.
