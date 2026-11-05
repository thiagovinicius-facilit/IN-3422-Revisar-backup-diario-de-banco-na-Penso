# Inventário de backup diário de banco na Penso — IN-3422

> **Status:** rascunho (05/11/2026)
> **Fonte:** `Mapeamento Servidores Oracle.xlsx`, aba "Máquinas" (não versionada — contém IPs e custos).
> IPs foram omitidos propositalmente deste documento; consulte a planilha.

**Legenda de status do backup:**
- ⏳ A verificar
- ✅ Configurado (já existia)
- 🆕 Configurado nesta tarefa
- ❌ Sem backup
- ➖ Fora do escopo

---

## 1. Servidores de banco de dados

### 1.1 Produção (escopo)

| Servidor | Engine | Atende | Backup Penso | Última execução OK | Observação |
|---|---|---|---|---|---|
| DB-PG-PRD-01 | PostgreSQL | Banco geral — maioria dos clientes (ver seção 2) | ⏳ | — | Recife deve estar aqui — confirmar |
| DB-PG-PRD-02 | PostgreSQL | GovBA | ⏳ | — | |
| DB-PG-PRD-02-READ-REPLICA | PostgreSQL | Réplica de GovBA | ⏳ | — | Avaliar usar como origem do backup |
| Banco_iris_Sergipe | IRIS | Sergipe + Reports | ⏳ | — | |
| DB-IR-PRD-01 | IRIS | GovBA + Reports | ⏳ | — | |
| DB-BI | PostgreSQL | Integração de BI | ⏳ | — | |
| DB-BI-READ-REPLICA | PostgreSQL | Réplica de DB-BI | ⏳ | — | Avaliar usar como origem do backup |
| DB-PG-PRD-03 | PostgreSQL | Alagoas ("não é do Target") | ⏳ | — | **Decidir se entra no escopo** |

### 1.2 Não produtivos (fora do escopo, salvo decisão contrária)

| Servidor | Engine | Atende | Backup Penso |
|---|---|---|---|
| DB-PG-HML-01 | PostgreSQL | HML GovBA | ➖ |
| DB-IR-HML-01 | IRIS | HML (QA e DEV) / QAIRIS | ➖ |
| DB-IR-HML-02 | IRIS | HML GovBA & Reports | ➖ |
| DB-IR-DEV-01 | IRIS | DEV GovBA | ➖ |
| MSSQL Server + QASQLSERVER | SQL Server | Testes | ➖ |

---

## 2. Clientes × banco × status

Banco inferido pela diferença entre "CUSTO TOTAL (VM + DB)" e "CUSTO" na planilha
(R$ 87,28 = rateio do DB-PG-PRD-01). Nome da base/schema ainda precisa ser levantado
(`psql -c "\l+"` / lista de databases IRIS).

### 2.1 Produção

| Cliente | VM aplicação | Servidor de banco (inferido) | Base / schema | Backup Penso | Evidência |
|---|---|---|---|---|---|
| **Recife** | Standalone_014 | ❓ (provável DB-PG-PRD-01) | ❓ | ⏳ | — |
| TJTO | Standalone_001 | DB-PG-PRD-01 | ❓ | ⏳ | — |
| Alagoas | Standalone_002 | DB-PG-PRD-01 | ❓ | ⏳ | — |
| GovBA | Standalone_003 | DB-PG-PRD-02 (+ DB-IR-PRD-01) | ❓ | ⏳ | — |
| SEDP | Standalone_005 | DB-PG-PRD-01 | ❓ | ⏳ | — |
| Moodle | Standalone_006 | DB-PG-PRD-01 | ❓ | ⏳ | — |
| GovPE | Standalone_008 | DB-PG-PRD-01 | ❓ | ⏳ | — |
| Ipojuca | Standalone_010 | DB-PG-PRD-01 | ❓ | ⏳ | — |
| SECTI/ES | Standalone_011 | ❓ (sem custo na planilha) | ❓ | ⏳ | — |
| Sergipe | Standalone_012 | Banco_iris_Sergipe | ❓ | ⏳ | — |
| Aracaju | Standalone_013 | DB-PG-PRD-01 | ❓ | ⏳ | — |
| Histórico de Aracaju | historico-aracaju | DB-PG-PRD-01 | ❓ | ⏳ | — |
| Assembleia Legislativa do ES | Standalone_015 | DB-PG-PRD-01 | ❓ | ⏳ | — |
| Pref. Jaboatão | Standalone_016 | DB-PG-PRD-01 | ❓ | ⏳ | — |
| Light | Standalone_017 | DB-PG-PRD-01 | ❓ | ⏳ | — |
| IDAF | Standalone_019 | DB-PG-PRD-01 | ❓ | ⏳ | — |
| SESA/ES | Standalone_020 | DB-PG-PRD-01 | ❓ | ⏳ | — |
| Adepe | Standalone_021 | DB-PG-PRD-01 | ❓ | ⏳ | — |
| TJPA | Standalone_031 | DB-PG-PRD-01 | ❓ | ⏳ | — |
| ONS | Standalone_033 | DB-PG-PRD-01 | ❓ | ⏳ | — |
| ❓ (sem cliente) | Cloud_001 | DB-PG-PRD-01 | ❓ | ⏳ | — |
| ❓ (sem cliente) | Cloud_002 | DB-PG-PRD-01 | ❓ | ⏳ | — |
| ❓ (sem cliente) | Cloud_003 | DB-PG-PRD-01 | ❓ | ⏳ | — |
| ❓ (sem cliente) | Cloud_004 | DB-PG-PRD-01 | ❓ | ⏳ | — |
| ❓ (sem cliente) | Cloud_004_2 | DB-PG-PRD-01 | ❓ | ⏳ | — |

### 2.2 Não produtivos (bases no DB-PG-PRD-01 — definir se entram no backup)

| Ambiente | VM aplicação | Servidor de banco (inferido) | Backup Penso |
|---|---|---|---|
| Adepe Homologação | Standalone_004 | DB-PG-PRD-01 | ⏳ |
| Cloud de Apresentação (Empresa Modelo) | Standalone_007 | DB-PG-PRD-01 | ⏳ |
| GovBA Dev | Standalone_009 | DB-PG-PRD-01 | ⏳ |
| GovBA Homologação | Standalone_018 | DB-PG-PRD-01 | ⏳ |
| GovPE HML | Standalone_022 | DB-PG-PRD-01 | ⏳ |
| Cloud de POCs | Standalone_026 | DB-PG-PRD-01 | ⏳ |

> Observação: se o backup na Penso for por **servidor** (dump de todo o DB-PG-PRD-01),
> essas bases já são cobertas junto com as de produção. Se for **por base**, precisam
> ser avaliadas uma a uma.

---

## 3. Pendências

- [ ] Confirmar em qual servidor de banco e com qual nome de base o **Recife** ficou após a migração.
- [ ] Listar as bases de DB-PG-PRD-01, DB-PG-PRD-02, DB-BI (`\l+`) e dos IRIS de produção.
- [ ] Identificar os clientes das VMs Cloud_001 a Cloud_004_2.
- [ ] Identificar onde fica a base de SECTI/ES (sem custo de DB na planilha).
- [ ] Decidir se DB-PG-PRD-03 (Alagoas, "não é do Target") entra no escopo.
- [ ] Levantar os jobs de backup configurados na Penso (granularidade: por servidor ou por base; agendamento; retenção; destino).
- [ ] Cruzar jobs × bases e preencher a coluna "Backup Penso".
- [ ] Configurar os faltantes e registrar evidência de execução bem-sucedida.
- [ ] (Recomendado) Teste de restore por amostragem.

## 4. Inconsistências encontradas na planilha

- Recife (Standalone_014) sem recursos/custo — situação "MIGRANDO".
- Valor "SM" em vez de "SIM" na coluna MONITORADO (várias linhas).
- `qaautomation`: custo total (179,70) menor que o custo da VM (295,80).
- Lacunas na numeração dos Standalone (023–025, 027–030, 032) — confirmar se foram desligados.
