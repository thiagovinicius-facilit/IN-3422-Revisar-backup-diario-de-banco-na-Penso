# Inventário de backup diário de banco na Penso — IN-3422

> **Status:** em andamento (05/11/2026)
> **Fontes:** `Mapeamento Servidores Oracle.xlsx` (aba "Máquinas", não versionada) + coleta manual nos servidores.
> IPs foram omitidos propositalmente deste documento; consulte a planilha.

**Legenda de status do backup:**
- ✅ Dump diário presente + incluído no envio Penso com sucesso
- ⏳ A verificar
- ❌ Sem backup
- 🆕 Configurado nesta tarefa
- ➖ Fora do escopo

**Progresso da coleta (um servidor por vez):**

| # | Servidor | Coletado | Observação |
|---|---|---|---|
| 1 | DB-PG-PRD-01 | ✅ 05/11 | 47 de 48 bases com dump do dia; só `core` sem backup |
| 2 | Fileserver | ✅ 05/11 | Agente Penso + repositório de dumps (NFS); `clientes/` e `bi/` no backup set |
| 3 | Jenkins (gerador dos dumps) | ⏳ | **Confirmado como gerador** (SSH `jboss` a cada dump); falta ver o job. Recife: origem ainda a confirmar |
| 4 | DB-IR-PRD-01 | 🔄 05/11 | IRIS 2025.1 em `/opt/iris`. **Sem crontab, sem timer, sem montagem remota, sem nenhum arquivo de backup** (nem `mgr/Backup`). Task Manager inacessível: **licença IRIS expirada**. Falta `messages.log` e confirmar backup de volume na OCI |
| 5 | DB-PG-PRD-02 (+ réplica) | ✅ 05/11 | `govba` (180 GB) com dump do dia; **`logi_reports` sem backup** (fora do job) |
| 6 | Banco_iris_Sergipe | ✅ 05/11 | Backup nativo IRIS diário (~20:00 → 22:16, "Backup complete") em `/Backup` (CIFS do Fileserver); licença ok |
| 7 | DB-BI (+ réplica) | ✅ 05/11 | 40 bases: 39 com dump do dia; só `"comunica_br OLD"` sem backup |
| 8 | DB-PG-PRD-03 | 🔄 | Alagoas — **incluído no escopo**, com a ressalva de que a planilha o indica como "não é do Target" |

---

## 0. Mecanismo de backup

### 0.1 Fluxo

```
Jenkins                                   Fileserver (/mnt/nfs = disco local, 3 TB, 73% usado)
 pg_dump por base, 00:00–02:45  ──SSH──▶  /mnt/nfs/services/backup/clientes/<base>/AAAAMMDD.tar.gz
 (usuário jboss, senha)
[origem a confirmar]
 Recife 07:15–07:30 (root)      ───?───▶  /mnt/nfs/services/backup/clientes/recife/recife-DDMMAAAA.tar.xz
                                          /mnt/nfs/services/backup/bi/<base>/AAAAMMDD.tar.gz
                                                   │
                              05:45  retencao_backup.sh  (apaga locais > 10 dias; bi > 3 dias)
                                                   │
                              06:00  Ahsay OBM ("Penso Backup Servidor" v9.15.2.59) ──▶ Penso ("PensoCBS")
```

### 0.2 Job do Jenkins — `Backup_Diário_Automático_Databases_Facilit`

Jenkins roda em contêiner Docker (`jenkins`) no servidor Jenkins. Pipeline com agente `postgres:14.5-alpine`, agendamento `H 0 * * *` (diário, ~00h).

| Stage | Origem | O que faz |
|---|---|---|
| Listar bases | DB-PG-PRD-01 e DB-BI | Lista **dinâmica** de todas as bases não-template |
| Backup db-prd | DB-PG-PRD-01 | `pg_dump` de cada base, **exceto**: `core`, `qa01`, `qa02`, `qa03`, `tests`, `postgres`, `qaapp`, `govba_0912` |
| Backup govba | DB-PG-PRD-02 | `pg_dump -d govba` |
| Backup govbahml | DB-PG-HML-01 | `pg_dump -d govbahml` |
| Backup banco-bi | DB-BI | `pg_dump` de todas as bases, exceto `postgres` |

- Cada dump é compactado (`tar.gz`) e enviado ao Fileserver via plugin *Publish Over SSH* (config `FileServer`, usuário `jboss`), que executa `move_dump_diario.sh <base> <arquivo>` (ou `move_dump_diario_bi.sh`).
- Tabelas **excluídas de todos os dumps** do PRD-01/PRD-02/HML: `facext_log_entry`, `facext_log_macro_entry`, `jackrabbit_j_r_ds_datastore`.
- Erros de dump/envio são capturados por `try/catch` e **apenas impressos** — o job termina como sucesso mesmo se uma base falhar.
- Senha do `postgres` via credencial Jenkins `POSTGRES_PASSWORD`.

Outros jobs de backup encontrados (sem agendamento próprio): `Backup_Databases_Facilit`, `Backup_Databases_Onpremisses`, `Backup_Databases_QA`.

### 0.3 Agendamentos no Fileserver

| Horário | Usuário | Comando | Função |
|---|---|---|---|
| 23:00 | jboss | `backup/clientes/sergipe/compacta_backup.sh` | Compacta backup do IRIS Sergipe |
| 05:45 | root | `backup/retencao_backup.sh` | Retenção local: `clientes/` 10 dias (`.tar.gz`/`.xz`), `bi/` 3 dias |
| 06:00 | root | `/usr/local/obm/bin/RunBackupSet.sh 1734658693620` | Envio à Penso — backup set **"[fileserver] - BackupSet-Dados"** |

Pastas confirmadas no backup set (pelo log): `/mnt/nfs/services/backup/clientes/` e `/mnt/nfs/services/backup/bi/`.

### 0.3 Última execução Penso (evidência)

Log: `/mnt/nfs/temp-penso/logs/backup_penso.log` (sobrescrito a cada execução).

| Item | Valor |
|---|---|
| Início / fim | 05/11/2026 06:00:16 → 06:43:02 |
| Resultado | **Backup Completed Successfully** — 0 linhas `[warn]`/`[error]` no log |
| Arquivos novos / atualizados / removidos | 92 / 2 / 92 |
| Upload do job | 75,8 GB |
| Total no destino Penso | 1,79 TB |

### 0.4 Histórico Penso — últimos 30 dias

Fonte: logs locais do agente em `/root/.obm/log/1734658693620/Backup/`.

| Período | Execuções | Resultado |
|---|---|---|
| 05/10 a 15/10/2026 | 11 | todas **Backup Completed Successfully** |
| **16/10 a 18/10/2026** | **0** | **sem log — backup não executou nesses 3 dias** |
| 19/10 a 05/11/2026 | 18 | todas **Backup Completed Successfully** |

Desde 25/10 (início dos dumps do Recife) há **12 execuções consecutivas com sucesso**.

---

## 1. Servidores de banco de dados

### 1.1 Produção (escopo)

| Servidor | Engine | Atende | Backup Penso | Observação |
|---|---|---|---|---|
| DB-PG-PRD-01 | PostgreSQL | Banco geral — 48 bases (ver seção 2) | ✅ (exceto `core`) | Dump por base via NFS. `archive_mode=off` (sem PITR). |
| DB-PG-PRD-02 | PostgreSQL | GovBA — bases `govba` (180 GB) e `logi_reports` (8,8 MB) | ✅ `govba` / ❌ `logi_reports` | `clientes/govba/20261105.tar.gz` (6,1 GB, 01:55). O job copia só `govba` (nome fixo no script); **`logi_reports` nunca é copiada** |
| DB-PG-PRD-02-READ-REPLICA | PostgreSQL | Réplica de GovBA | ➖ | Coberta pelo dump do primário |
| Banco_iris_Sergipe | IRIS | Sergipe + Reports | ✅ | Backup nativo IRIS (`FullDBList`, Task Manager) diário ~20:00, último `FullDBList_20261104_001.log` = **"Backup complete"** às 22:16. Destino `/Backup` = CIFS `//fileserver/backup_sergipe` → compactado às 23:00 (`clientes/sergipe/backup_04112026.tar.gz`, 23:43) → Penso 06:00. Falhas isoladas no histórico (11/2024, 01/2025, 02/2026). Licença por core sem aviso de vencimento. |
| DB-IR-PRD-01 | IRIS | GovBA + Reports | ❌ | Nenhum backup no Fileserver nem no servidor; `messages.log` **sem nenhum registro de backup** desde o start (11/05/2026). Database de aplicação `TARGET` (~21 MB, alterada em 05/11) + `USER`. Resta confirmar backup de volume na OCI |
| DB-BI | PostgreSQL | Integração de BI — 40 bases (maiores: comunicabr 45 GB, govba_prod 31 GB, bahia 27 GB, siconv 9,9 GB, sebrae_prophix 7,5 GB) | ✅ 39/40 | Todas com dump de 05/11 em `bi/` (no backup set Penso), **exceto `"comunica_br OLD"`** (9,8 MB, espaço no nome — nunca copiada). Retenção local de só 3 dias. |
| DB-BI-READ-REPLICA | PostgreSQL | Réplica de DB-BI | ➖ | Coberta pelo dump do primário |
| DB-PG-PRD-03 | PostgreSQL | Alagoas — ⚠️ **indicado na planilha como "não é do Target"** | ⏳ | Incluído no levantamento por decisão de 05/11/2026. Não consta em nenhum stage do job do Jenkins. |

### 1.2 Não produtivos

| Servidor | Engine | Atende | Backup |
|---|---|---|---|
| DB-PG-HML-01 | PostgreSQL | HML GovBA | ✅ `clientes/govbahml/20261105.tar.gz` (2,5 GB) |
| DB-IR-HML-01 | IRIS | HML (QA e DEV) / QAIRIS | ➖ (pasta `qairis` vazia desde 04/2025) |
| DB-IR-HML-02 | IRIS | HML GovBA & Reports | ➖ |
| DB-IR-DEV-01 | IRIS | DEV GovBA | ➖ |
| MSSQL Server + QASQLSERVER | SQL Server | Testes | ➖ |

---

## 2. DB-PG-PRD-01 — bases × cliente × status

Coleta de 05/11/2026. Dump = último arquivo em `/mnt/nfs/services/backup/clientes/<base>/`.

### 2.1 Produção — backup obrigatório

| Base | Cliente | Tamanho base | Último dump | Backup Penso |
|---|---|---|---|---|
| **recife** | **Recife** | 15 GB | Jenkins: **falha diária** (Permission denied). Existente: `recife-05112026.tar.xz` 05/11 07:23 — origem on-premise | ⚠️ **Não confirmado** — ver nota |
| adepe | Adepe | 14 GB | 05/11 00:01 | ✅ |
| alagoas_producao | Alagoas | 70 GB | 05/11 00:05 | ✅ |
| ales | Assembleia Legislativa do ES | 7,4 GB | 05/11 00:06 | ✅ |
| aracaju | Aracaju | 17 GB | 05/11 00:10 | ✅ |
| historico_aracaju | Histórico de Aracaju | 11 GB | 05/11 00:53 | ✅ |
| facilit_prod | Facilit (interno, VM Cloud_001) | 19 GB | 05/11 00:26 | ✅ |
| cloud_002 | ❓ cliente a identificar | 8,6 GB | 05/11 00:12 | ✅ |
| cloud_003 | ❓ cliente a identificar | 5,9 GB | 05/11 00:13 | ✅ |
| cloud_004 | ❓ cliente a identificar | 15 GB | 05/11 00:17 | ✅ |
| cloud_004_2 | ❓ cliente a identificar | 21 GB | 05/11 00:22 | ✅ |
| govpe | GovPE | 86 GB | 05/11 00:47 | ✅ |
| idaf | IDAF | 1,7 GB | 05/11 00:53 | ✅ |
| ipojuca | Ipojuca | 6,1 GB | 05/11 00:53 | ✅ |
| jaboatao | Pref. Jaboatão | 19 GB | 05/11 00:57 | ✅ |
| light | Light | 10 GB | 05/11 00:58 | ✅ |
| moodlefacilit | Moodle | 49 MB | 05/11 00:02 | ✅ |
| ons | ONS | 7,1 GB | 05/11 00:59 | ✅ |
| secti | SECTI/ES | 739 MB | 05/11 01:00 | ✅ |
| sedp | SEDP | 14 GB | 05/11 01:01 | ✅ |
| sesa | SESA/ES | 4,1 GB | 05/11 01:02 | ✅ |
| tjpa | TJPA | 2,4 GB | 05/11 01:25 | ✅ |
| tjto | TJTO | 16 GB | 05/11 01:26 | ✅ |
| target_mobile | App mobile Target | 16 MB | 05/11 00:01 | ✅ |
| integracao_backup | Pesquisa de satisfação Target | 9,6 MB | 05/11 00:02 | ✅ |
| core | ❓ compartilhada (QA, produto, squad cognitiva) | 235 MB | **pasta vazia desde 22/02/2025** | ❌ — confirmar se é produtiva |

**Nota — Recife:**

1. **Dump da base atual (DB-PG-PRD-01) — FALHA DIÁRIA.** O job `Backup_Diário_Automático_Databases_Facilit` faz o `pg_dump` da base `recife` com sucesso, mas o `move_dump_diario.sh` no Fileserver falha:
   `mv: cannot create regular file '/mnt/nfs/services/backup/clientes/recife/20261105.tar.gz': Permission denied`.
   Em seguida o Jenkins apaga o arquivo local (`rm recife.tar.gz`) e imprime "realizado". **O dump é perdido todo dia.**
   Causa: a pasta `clientes/recife` tem dono `33:tape` e modo `755`; as demais pastas são `jboss:jboss` `775`.
   Efeito colateral: o job fica **UNSTABLE** em todos os builds recentes (885–894).

   Linha do tempo no Jenkins (job diário):

   | Builds | Datas | Base `recife` no PRD-01 |
   |---|---|---|
   | 875–888 | 17/10 a 30/10/2026 | não existia (job não a lista) |
   | 889–894 | **31/10 a 05/11/2026** | existe — **dump perdido em todos os 6 dias** |

   Conclusão: desde que a base entrou no DB-PG-PRD-01 (entre 30 e 31/10, logo após o `recife.tar.gz` de 29/10 22:10),
   **nenhum dump da base atual do Recife foi preservado**. O último backup conhecido da base migrada é o próprio
   `recife.tar.gz` de 29/10 (dump da migração).
2. **Arquivos `.tar.xz` existentes — origem on-premise.** O Recife está na lista do job `Backup_Databases_Onpremisses`
   (junto com Celepar, Paraíba, Sebrae, Tocantins), que gera links de download em `backup.plataformatarget.com.br`.
   Os `.tar.xz` (dono `root`, ~07:20, histórico desde pelo menos 02/2026) parecem ser **enviados pelo ambiente
   on-premise do Recife**, anterior à migração. Esses arquivos estão na Penso (log de 05/11 confirma o envio de `recife-04112026.tar.xz`).
   Conteúdo de `recife-05112026.tar.xz` (cabeçalho): `recife-05112026.sql`, dono `postgres/postgres`, **7,6 GB** (SQL texto),
   gerado em **05/11 06:01**; "Dumped from database version 14.5" — **mesma versão do DB-PG-PRD-01 (14.5)**, portanto a
   versão não permite distinguir a origem. Dump termina ~06:01 e a compressão `xz` termina ~07:20.
   **Origem confirmada como externa ao DB-PG-PRD-01:** no PRD-01 não há arquivo `recife-*.sql*` recente, o crontab do
   root está vazio (arquivo de 0 bytes desde 01/2023), o `cron.daily` só tem tarefas padrão e não há timers de backup.
   O histórico do root mostra o caminho inverso: dumps `.xz` do Recife **baixados** da intranet e restaurados no PRD-01.
   Logo, os `.tar.xz` são gerados **em outro servidor** (provável ambiente on-premise do Recife), que segue ativo e
   produziu dump em 05/11 06:01.
3. **Risco:** se os `.tar.xz` vêm do ambiente antigo, a Penso guarda backup de uma **base desatualizada**, e a base
   de produção atual do Recife (DB-PG-PRD-01) **não tem backup**. Confirmar a origem/conteúdo do `.tar.xz`.

**Correção recomendada (não aplicada — depende de janela/aprovação de mudança):**

```bash
# No Fileserver
sudo chown jboss:jboss /mnt/nfs/services/backup/clientes/recife
sudo chmod 775 /mnt/nfs/services/backup/clientes/recife
# Rollback: sudo chown 33:tape … && sudo chmod 755 …
```

Após aplicar, o próximo build (~00h) grava `recife/AAAAMMDD.tar.gz` e a Penso envia às 06:00 do mesmo dia.
Evidência: arquivo no Fileserver + linha `[New File] ... clientes/recife/AAAAMMDD.tar.gz` no log da Penso + build sem UNSTABLE.

### 2.2 Não produtivas

| Base | Uso | Tamanho | Backup |
|---|---|---|---|
| govbadev | GovBA Dev | 53 GB | ✅ |
| tests05 | QA / testes | 66 GB | ✅ |
| adepehml | Adepe Homologação | 11 GB | ✅ |
| govpehml | GovPE HML | 6,3 GB | ✅ |
| ons_homologacao | ONS HML | 2,6 GB | ✅ |
| cloud_apresentacao | Empresa Modelo | 3,2 GB | ✅ |
| cloud_poc | POCs | 2,9 GB | ✅ |
| qa04, qa_default, qaautomation, qasqlserver, releasenotes, mobile | QA | — | ✅ |
| liferay | Teste Liferay | 681 MB | ✅ |
| target_c_contexto | CI | 182 MB | ✅ |
| sonarqube | CI | 8,8 MB | ✅ |
| qaapp | QA | 7,6 GB | ❌ não existe pasta de backup |
| qa01 / qa02 / qa03 | QA | ~360 MB | ❌ pastas vazias (pararam em 07, 08 e 09/2026) |
| tests | QA | 108 MB | ❌ pasta vazia desde 30/12/2025 |
| postgres | Base de sistema | 8,9 MB | ➖ |

---

## 3. Backups de clientes fora da planilha de servidores

Dumps no Fileserver **sem servidor correspondente na planilha** (provável infraestrutura do cliente / fora da OCI):

| Pasta | Último dump | Backup Penso |
|---|---|---|
| tocantins01 … tocantins06 | `backup_target[N]_postgres_05112026.tar.gz` (05/11 00:01–01:41) | ✅ |
| paraiba-producao | `backup_postgres_05112026.tar.gz` (05/11 00:59) | ✅ |
| sebrae-prod | `backup_postgres_05112026.tar.gz` (05/11 00:24, 7,9 GB) | ✅ |
| sebrae-hml | `backup_postgres_05112026.tar.gz` (05/11 02:28, 7,9 GB) | ✅ |
| celepar | `celepar_prod.tar.xz` (04/11 23:34 — sobrescrito diariamente, sem histórico) | ✅ |

Pastas vazias (clientes antigos/inativos): angola, avantia, bundle, cachoeiro, caruaru, cloud_007,
cloud6, creasp, dashs, fapsoftex, files, goias, govto, gptbot, local, pentaho, qairis, sapsms,
sebrae-dev, targetautomation, uploads.

---

## 4. Pendências

- [x] Onde ficou o **Recife** → base `recife` (15 GB) no DB-PG-PRD-01.
- [ ] **Recife no backup Penso** → ⚠️ dump da base atual falha por permissão (ver nota na seção 2.1); `.tar.xz` na Penso parece vir do ambiente on-premise. **Aplicar correção de permissão (mudança aprovada)** e confirmar origem do `.tar.xz`.
- [x] Base de SECTI/ES → `secti`; base da VM Cloud_001 → `facilit_prod`.
- [x] Mecanismo Penso → Ahsay OBM no Fileserver, diário 06:00, sucesso em 05/11.
- [x] Pastas no backup set Penso → `clientes/` e `bi/`.
- [x] Último dump de todas as pastas de `clientes/`.
- [x] Log da Penso de 05/11 sem avisos/erros.
- [x] Gerador dos dumps padrão → **Jenkins**: `/var/log/secure` do Fileserver mostra um login SSH `jboss` vindo do Jenkins a cada dump (00:01, 00:03, 00:05, 00:06, 00:10…), batendo com os horários dos arquivos. Não há `pg_dump` instalado no Fileserver.
- [x] Job no Jenkins → `Backup_Diário_Automático_Databases_Facilit`. **`core` está excluída de propósito** na lista do job (junto com qa01–03, tests, qaapp).
- [ ] Decidir com o time se a exclusão da `core` deve continuar.
- [x] Por que não há `recife/AAAAMMDD.tar.gz` → `Permission denied` no `mv` do Fileserver (build 894).
- [x] DB-BI: confirmada a base **`"comunica_br OLD"`** (9,8 MB) — o `split("\\s+")` do job a quebra em `comunica_br` + `OLD` e ela **nunca tem backup**. Pelo nome parece cópia antiga de `comunicabr`: decidir entre renomear (ex.: `comunica_br_old`) ou remover. Qualquer uma das duas resolve o erro diário do job.
- [ ] Teste de restore sugerido para `comunicabr`: base de 45 GB gera dump de só 231 MB compactado (~0,5%) — pode ser só bloat/índices, mas convém validar.
- [ ] Avaliar o impacto da exclusão da tabela `jackrabbit_j_r_ds_datastore` (pode conter os documentos anexados) e das tabelas de log num restore.
- [ ] Identificar a origem do dump do Recife (`root`, ~07:20).
- [ ] **DB-IR-PRD-01 (IRIS GovBA)**: nenhum backup encontrado no SO nem no Fileserver. Pendente: `messages.log` (histórico de backups nativos) e política de backup de volume na OCI. Se confirmado sem backup → configurar (ex.: backup online nativo do IRIS ou export da database `TARGET` enviado ao Fileserver).
- [ ] **Licença do IRIS expirada no DB-IR-PRD-01** desde **01/11/2026 00:27** (`LMF Error: License has expired`, avisos diários desde 27/10). **Ação:** falar com o **Manoel** para renovar a licença; em seguida, atualizar a chave/certificado de licença no servidor.
- [ ] **`core`**: confirmar se é produtiva; se sim, incluir no job.
- [x] DB-BI: lista de bases × pastas em `bi/` cruzada (39/40).
- [ ] **DB-PG-PRD-02: base `logi_reports` (8,8 MB) sem backup** — o stage do job tem `govba` fixo. Confirmar se é produtiva (provável configuração de relatórios do Logi Reports do GovBA) e, se sim, incluir no job (ou tornar o stage dinâmico como o do PRD-01).
- [x] DB-PG-PRD-03 (Alagoas) **entra no escopo** (decisão de 05/11/2026), registrando que a planilha o indica como "não é do Target".
- [ ] Coletar bases e backup do DB-PG-PRD-03.
- [ ] Identificar os clientes de `cloud_002`, `cloud_003`, `cloud_004`, `cloud_004_2`.
- [ ] Evidência de execução bem-sucedida para os configurados nesta tarefa.
- [ ] (Recomendado) Teste de restore por amostragem (sugestão: `recife`).

## 5. Inconsistências encontradas na planilha

- Recife (Standalone_014) sem recursos/custo — situação "MIGRANDO" (base em produção com backup desde 25/10).
- Valor "SM" em vez de "SIM" na coluna MONITORADO (várias linhas).
- `qaautomation`: custo total (179,70) menor que o custo da VM (295,80).
- Lacunas na numeração dos Standalone (023–025, 027–030, 032).
- Clientes com backup ativo e sem servidor na planilha: Tocantins (6), Paraíba, Sebrae, Celepar.

## 6. Achados colaterais (fora do escopo — abrir chamado próprio)

### DB-PG-PRD-01
1. **Sem PITR:** `archive_mode=off`. Recuperação limitada ao último dump (até ~24h de perda).
2. **Regra aberta para qualquer IP:** usuário `bi_ipojuca` na base `ipojuca` liberado para `0.0.0.0/0`.
3. **Regra `trust` (sem senha):** usuário `bi` em todas as bases a partir de uma faixa de rede interna.
4. **Acessos de IPs públicos externos:** usuário `bi` (2 IPs) e `cachoeiro_readonly` (1 IP).
5. **Acesso amplo:** a VM Cloud_001 e o servidor Pentaho têm `all/all`.
6. **Autenticação `md5`** na maioria das regras (recomendado `scram-sha-256`).
7. **~30 regras órfãs** no `pg_hba.conf` para bases que não existem mais.
8. **Arquivo `/tmp/02-grants-targetpass.sql`** no servidor — verificar se contém senha e removê-lo.

### Fileserver
9. **Exceção do Sebrae na retenção não funciona:** o script exclui `"$BACKUP_DIR/sebrae-producao/*"`, mas
   (a) a pasta real é `sebrae-prod` e (b) `BACKUP_DIR` já termina em `/`, gerando `//` no padrão.
   Resultado: os dumps do Sebrae Prod também são apagados com 10 dias, ao contrário do pretendido.
10. **Defasagem de ~23h na Penso para o Recife:** dump às ~07:20, envio às 06:00.
11. **Log da Penso é sobrescrito** a cada execução (`>`), sem histórico local de falhas.
12. **Celepar sem histórico local:** arquivo único `celepar_prod.tar.xz` sobrescrito diariamente.
13. **SSH com senha:** o Jenkins entra no Fileserver como `jboss` por **senha** (não chave). Recomendado migrar para chave SSH restrita.
14. **Lacuna de 3 dias na Penso (16–18/10/2026):** nenhum log de execução. Investigar a causa (servidor reiniciado? agente parado?) e criar alerta de "backup não executado".
15. **Recife — cópias manuais:** o histórico do root mostra cópias de dumps do Recife para `services/intranet/clientes/recife/` (inclusive `recife-07022026.xz`, de 02/2026). Confirmar a finalidade (entrega ao cliente?) e se a pasta da intranet deve conter dumps.
16. **Falhas silenciosas no job do Jenkins:** `try/catch` só faz `echo` do erro; o build fica verde mesmo com bases sem dump. Recomendado marcar o build como `UNSTABLE`/`FAILURE` e alertar.
17. **Dumps sem tabelas:** `--exclude-table` remove a tabela **inteira** (estrutura + dados) de `facext_log_entry`, `facext_log_macro_entry` e `jackrabbit_j_r_ds_datastore`. Um restore gera uma base sem essas tabelas; se o Jackrabbit guarda os binários dos documentos no banco, **os anexos não estão no backup**. Avaliar trocar por `--exclude-table-data` (mantém a estrutura) e confirmar onde ficam os binários.
18. **Job diário UNSTABLE sem ninguém perceber:** builds 885–894 todos `UNSTABLE`. Configurar notificação (e-mail/Slack) para resultado ≠ SUCCESS.
19. **Bases com espaço no nome não são copiadas:** o job separa a lista de bases por espaço (`split("\\s+")`).
20. **Link de download do Recife errado no job `Backup_Databases_Onpremisses`:** usa formato `MMddyyyy`, mas os arquivos são `ddMMyyyy` (ex.: em 05/11 gera `recife-11052026.tar.xz` em vez de `recife-05112026.tar.xz`).
21. **Senha interpolada em `sh`:** Jenkins alerta "A secret was passed to sh using Groovy String interpolation, which is insecure" (`PGPASSWORD`). Usar a variável de ambiente sem interpolação.
22. **Senha trivial do superusuário `postgres` em texto puro** no histórico do root do DB-PG-PRD-01 (comandos `psql` com `PGPASSWORD=` explícito). Trocar a senha e limpar o histórico. Também usada no `pg_hba` com `md5` a partir de outros hosts.
23. **Dados de produção do Recife restaurados em bases de QA:** histórico mostra restores de dumps do Recife nas bases `tests`, `qa01` e `qa03` do PRD-01. Avaliar exposição de dados pessoais (LGPD) e limpar/anonimizar.
24. **Nome enganoso:** `/mnt/nfs` não é NFS (disco local; nenhum export ativo). O Fileserver compartilha arquivos via **Samba** (`smbd` rodando como `jboss`).
