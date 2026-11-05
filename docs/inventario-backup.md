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
| 4 | DB-IR-PRD-01 | ⏳ | **GovBA IRIS — nenhum backup localizado no Fileserver** |
| 5 | DB-PG-PRD-02 (+ réplica) | ✅ via Fileserver | `clientes/govba` com dump do dia |
| 6 | Banco_iris_Sergipe | ✅ via Fileserver | `clientes/sergipe` com dump do dia anterior (23:43) |
| 7 | DB-BI (+ réplica) | ⏳ | 39 dumps em `bi/` — cruzar com a lista de bases do servidor |
| 8 | DB-PG-PRD-03 | ⏳ | Alagoas — confirmar escopo |

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

### 0.2 Agendamentos no Fileserver

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
| DB-PG-PRD-02 | PostgreSQL | GovBA | ✅ | `clientes/govba/20261105.tar.gz` (6,1 GB, 01:55) |
| DB-PG-PRD-02-READ-REPLICA | PostgreSQL | Réplica de GovBA | ➖ | Coberta pelo dump do primário |
| Banco_iris_Sergipe | IRIS | Sergipe + Reports | ✅ | `clientes/sergipe/backup_04112026.tar.gz` (04/11 23:43) |
| DB-IR-PRD-01 | IRIS | GovBA + Reports | ❓ | **Nenhuma pasta de backup IRIS GovBA no Fileserver** — verificar no servidor |
| DB-BI | PostgreSQL | Integração de BI | ✅ parcial | 39 dumps do dia em `bi/`, pasta no backup set — falta cruzar com as bases do servidor |
| DB-BI-READ-REPLICA | PostgreSQL | Réplica de DB-BI | ➖ | Coberta pelo dump do primário |
| DB-PG-PRD-03 | PostgreSQL | Alagoas ("não é do Target") | ⏳ | **Decidir se entra no escopo** |

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
| **recife** | **Recife** | 15 GB | `recife-05112026.tar.xz` 05/11 07:23 (1,1 GB) | ✅ diário desde 25/10/2026 — ver nota |
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
- Dumps diários desde **25/10/2026** (12 arquivos `.tar.xz` de ~1,1 GB + um `recife.tar.gz` avulso de 29/10 22:10, provavelmente da migração).
- Confirmado no log da Penso de 05/11: `[New File] ... clientes/recife/recife-04112026.tar.xz`.
- Gerado por **processo diferente** do padrão (dono `root`, `.tar.xz`, ~07:15–07:30), **depois** do envio das 06:00 → o dump do dia D só chega à Penso em D+1 06:00 (defasagem de ~23h).
- Recomendação: integrar o Recife ao job padrão (ou antecipar o horário para antes das 05:00).

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
- [x] **Recife no backup Penso** → dumps diários desde 25/10, confirmados no log de 05/11.
- [x] Base de SECTI/ES → `secti`; base da VM Cloud_001 → `facilit_prod`.
- [x] Mecanismo Penso → Ahsay OBM no Fileserver, diário 06:00, sucesso em 05/11.
- [x] Pastas no backup set Penso → `clientes/` e `bi/`.
- [x] Último dump de todas as pastas de `clientes/`.
- [x] Log da Penso de 05/11 sem avisos/erros.
- [x] Gerador dos dumps padrão → **Jenkins**: `/var/log/secure` do Fileserver mostra um login SSH `jboss` vindo do Jenkins a cada dump (00:01, 00:03, 00:05, 00:06, 00:10…), batendo com os horários dos arquivos. Não há `pg_dump` instalado no Fileserver.
- [ ] Identificar o job no Jenkins (lista de bases, para incluir `core` se necessário).
- [ ] Identificar a origem do dump do Recife (`root`, ~07:20).
- [ ] **DB-IR-PRD-01 (IRIS GovBA)**: localizar backup ou configurar.
- [ ] **`core`**: confirmar se é produtiva; se sim, incluir no job.
- [ ] DB-BI: cruzar lista de bases × pastas em `bi/`.
- [ ] Decidir se DB-PG-PRD-03 (Alagoas) entra no escopo.
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
16. **Nome enganoso:** `/mnt/nfs` não é NFS (disco local; nenhum export ativo). O Fileserver compartilha arquivos via **Samba** (`smbd` rodando como `jboss`).
