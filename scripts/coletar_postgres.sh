#!/usr/bin/env bash
# IN-3422 - Coleta (somente leitura) de bases e evidências de backup em servidor PostgreSQL.
# Uso (no servidor de banco, como root ou usuário com sudo):
#   sudo bash coletar_postgres.sh > coleta_$(hostname)_$(date +%F).txt 2>&1
# Não altera nada no servidor.

set -u
PSQL="sudo -u postgres psql -X -A -F | -P footer=off"

secao() { printf '\n==================== %s ====================\n' "$1"; }

secao "IDENTIFICAÇÃO"
echo "Host: $(hostname)  Data: $(date '+%F %T %Z')"
$PSQL -tc "select version();"
$PSQL -tc "select pg_is_in_recovery() as is_replica;"

secao "BASES (nome | dono | tamanho | conexões permitidas)"
$PSQL -c "select d.datname, pg_get_userbyid(d.datdba) as owner,
                 pg_size_pretty(pg_database_size(d.datname)) as size,
                 d.datallowconn
          from pg_database d
          where not d.datistemplate
          order by pg_database_size(d.datname) desc;"

secao "ÚLTIMA ATIVIDADE POR BASE (indica se está em uso)"
$PSQL -c "select datname, numbackends, xact_commit, stats_reset
          from pg_stat_database where datname is not null order by datname;"

secao "ARQUIVAMENTO WAL / PITR"
$PSQL -c "select name, setting from pg_settings
          where name in ('archive_mode','archive_command','wal_level','data_directory');"
$PSQL -c "select archived_count, last_archived_wal, last_archived_time,
                 failed_count, last_failed_time from pg_stat_archiver;" 2>/dev/null

secao "CRONTABS"
for u in root postgres; do echo "--- crontab $u"; crontab -l -u "$u" 2>&1; done
echo "--- /etc/crontab e /etc/cron.d"
cat /etc/crontab 2>/dev/null; grep -H . /etc/cron.d/* 2>/dev/null
echo "--- cron.daily"
ls -l /etc/cron.daily 2>/dev/null

secao "SYSTEMD TIMERS"
systemctl list-timers --all --no-pager 2>/dev/null

secao "FERRAMENTAS DE BACKUP INSTALADAS"
for b in pg_dump pg_dumpall pg_basebackup pgbackrest barman rclone restic oci; do
  printf '%-14s %s\n' "$b" "$(command -v $b || echo '-')"
done

secao "PROCESSOS/AGENTES DE BACKUP EM EXECUÇÃO"
ps -eo pid,user,etime,cmd | grep -Ei 'backup|dump|pgbackrest|barman|rclone|restic|penso' | grep -v grep

secao "ARQUIVOS DE DUMP/BACKUP DOS ÚLTIMOS 3 DIAS (até 200)"
find / -xdev \( -path /proc -o -path /sys -o -path /var/lib/pgsql/*/data \) -prune -o \
  -type f -mtime -3 \( -iname '*.dump' -o -iname '*.backup' -o -iname '*.sql' \
  -o -iname '*.sql.gz' -o -iname '*.tar.gz' -o -iname '*.bak' \) \
  -printf '%TY-%Tm-%Td %TH:%TM  %10s  %p\n' 2>/dev/null | sort -r | head -200

secao "PONTOS DE MONTAGEM (destinos remotos de backup)"
df -hT | grep -Ev 'tmpfs|devtmpfs'
grep -Ei 'nfs|cifs|fuse' /proc/mounts

secao "FIM"
