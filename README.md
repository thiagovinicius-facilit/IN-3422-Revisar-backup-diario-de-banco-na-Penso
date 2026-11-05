# Revisar backup diário de banco na Penso para todos os clientes (incluindo Recife) e configurar os faltantes

Descrição

Contexto
Precisamos garantir que as bases de dados de todos os clientes da Plataforma Target estejam sendo salvas no backup diário de banco na Penso. Com a migração do novo cliente Recife, é necessário confirmar que ele também foi incluído na rotina.

Objetivo
Revisar a configuração do backup diário de banco na Penso, cliente a cliente, e configurar aqueles que ainda não estiverem cobertos, para termos a segurança das bases sendo salvas.

Escopo
Levantar a lista de todos os clientes/bases de produção ativos.

Verificar, para cada um, se está configurado no backup diário de banco na Penso.

Incluir o cliente Recife (recém-migrado) na verificação.

Configurar o backup diário para os clientes/bases que não estiverem configurados.

Validar que o backup está rodando (job executado com sucesso e arquivo gerado).

Critérios de aceite

Lista consolidada de clientes x status do backup (configurado / configurado nesta tarefa), anexada ou comentada neste chamado.

Recife configurado no backup diário de banco na Penso.

Todos os clientes que estavam sem backup passaram a ter o backup diário configurado.

Evidência de pelo menos uma execução bem-sucedida para os clientes configurados nesta tarefa.
Referência
Chamado relacionado: IN-3383 (Verificar backups automáticos dos databases da Facilit).