#!/bin/sh
#
# SightMetrics – Vorbereitung beim Containerstart. Das Entrypoint-Skript des
# nginx-Images führt es als root aus, bevor nginx startet.
#
# SightMetrics – startup preparation. The nginx image's entrypoint runs it as
# root before nginx starts.
#
# 1. Vertrauenswürdige Proxy-Adressen aus REVERSE_PROXY_IP (Komma-Liste aus IPs
#    oder CIDR-Bereichen, dieselbe Variable wie für TYPO3) als geo-Einträge für
#    default.conf schreiben. '*' akzeptiert TYPO3, hier wird es ignoriert: Dann
#    könnte jeder Besucher seine IP per X-Forwarded-For fälschen.
# 2. Das Log-Verzeichnis dem nginx-Worker übergeben: Mit einer Variable im Pfad
#    legt der Worker die Tagesdateien selbst an.
#
# 1. Write trusted proxy addresses from REVERSE_PROXY_IP (comma list of IPs or
#    CIDR ranges, same variable as for TYPO3) as geo entries. '*' is ignored
#    here – it would let every visitor spoof their IP via X-Forwarded-For.
# 2. Hand the log directory to the nginx worker, which creates the day files.

set -eu
# Keine Glob-Expansion beim Aufteilen – sonst würde '*' zu Dateinamen
# No globbing while splitting – '*' would otherwise expand to file names
set -f

conf_dir=/run/sightmetrics
mkdir -p "$conf_dir"
conf="$conf_dir/proxies.conf"
: > "$conf"

IFS=','
for entry in ${REVERSE_PROXY_IP:-}; do
    entry=$(printf '%s' "$entry" | tr -d ' \t')
    case "$entry" in
        '')
            ;;
        *[!0-9A-Fa-f:./]*)
            echo "30-sightmetrics.sh: REVERSE_PROXY_IP-Eintrag '$entry' ignoriert (nur IP oder CIDR)" >&2
            ;;
        *)
            printf '%s 1;\n' "$entry" >> "$conf"
            ;;
    esac
done
unset IFS

if [ -d /var/log/nginx/sightmetrics ]; then
    chown nginx:nginx /var/log/nginx/sightmetrics
fi
