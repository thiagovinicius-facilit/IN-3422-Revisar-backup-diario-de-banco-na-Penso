#!/usr/bin/env bash
# IN-3422 - Coleta (somente leitura) de databases e evidências de backup em servidor InterSystems IRIS.
# Uso (no servidor IRIS, como root ou usuário com sudo):
#   sudo bash coletar_iris.sh [NOME_INSTANCIA] > coleta_$(hostname)_$(date +%F).txt 2>&1
# Se a instância exigir login no terminal, a seção "TAREFAS" pedirá usuário/senha
# ou falhará — nesse caso, rode o bloco manualmente (ver comentário abaixo).

set -u
secao() { printf '\n==================== %s ====================\n' "$1"; }

secao "IDENTIFICAÇÃO"
echo "Host: $(hostname)  Data: $(date '+%F %T %Z')"
iris list 2>&1

INST="${1:-$(iris qlist 2>/dev/null | head -1 | cut -d'^' -f1)}"
DIR="$(iris qlist 2>/dev/null | grep "^${INST}^" | cut -d'^' -f2)"
echo "Instância: ${INST}  Diretório: ${DIR}"

secao "DATABASES (seção [Databases] do iris.cpf)"
awk '/^\[Databases\]/{f=1;next} /^\[/{f=0} f' "${DIR}/iris.cpf" 2>/dev/null

secao "TAMANHO DOS IRIS.DAT"
awk '/^\[Databases\]/{f=1;next} /^\[/{f=0} f' "${DIR}/iris.cpf" 2>/dev/null \
  | cut -d= -f2 | cut -d, -f1 | sort -u | while read -r d; do
      [ -f "$d/IRIS.DAT" ] && ls -lh --time-style=+%F "$d/IRIS.DAT"
    done

secao "TAREFAS AGENDADAS DO IRIS (Task Manager)"
# Bloco manual equivalente, no terminal do IRIS (namespace %SYS):
#   do ##class(%SQL.Statement).%ExecDirect(,"SELECT ID,Name,TaskClass,Suspended,LastStarted,LastFinished FROM %SYS.Task").%Display()
iris session "$INST" -U %SYS <<'EOF' 2>&1
do ##class(%SQL.Statement).%ExecDirect(,"SELECT ID,Name,TaskClass,Suspended,LastStarted,LastFinished FROM %SYS.Task ORDER BY Name").%Display()
halt
EOF

secao "LOGS DE BACKUP DO IRIS (últimos arquivos)"
ls -lt "${DIR}/mgr/Backup" 2>/dev/null | head -20
ls -lt "${DIR}"/mgr/*.log 2>/dev/null | head -10

secao "CRONTABS"
for u in root irisowner irisusr; do echo "--- crontab $u"; crontab -l -u "$u" 2>&1; done
cat /etc/crontab 2>/dev/null; grep -H . /etc/cron.d/* 2>/dev/null

secao "SYSTEMD TIMERS"
systemctl list-timers --all --no-pager 2>/dev/null

secao "PROCESSOS/AGENTES DE BACKUP EM EXECUÇÃO"
ps -eo pid,user,etime,cmd | grep -Ei 'backup|rclone|restic|penso' | grep -v grep

secao "ARQUIVOS .cbk / backup DOS ÚLTIMOS 3 DIAS (até 200)"
find / -xdev \( -path /proc -o -path /sys \) -prune -o -type f -mtime -3 \
  \( -iname '*.cbk' -o -iname '*.bck' -o -iname '*backup*' -o -iname '*.tar.gz' \) \
  -printf '%TY-%Tm-%Td %TH:%TM  %10s  %p\n' 2>/dev/null | sort -r | head -200

secao "PONTOS DE MONTAGEM"
df -hT | grep -Ev 'tmpfs|devtmpfs'
grep -Ei 'nfs|cifs|fuse' /proc/mounts

secao "FIM"
