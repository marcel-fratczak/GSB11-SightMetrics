#!/usr/bin/env bash
#
# GSB11-SightMetrics – Zugriffe auswerten
#
# Liest die Tagesdateien des nginx-Access-Logs mit der SightMetrics-Ingestion
# (DuckDB) und schreibt die Tagesaggregate in die Cube-DB 'analytics'. Das
# Backend-Modul von SightMetrics zeigt sie anschließend an. Nach einem
# erfolgreichen Lauf löscht es Tagesdateien, die älter als
# SM_LOG_RETENTION_DAYS sind – sie enthalten vollständige IP-Adressen.
#
# GSB11-SightMetrics – analyse page views. Runs the SightMetrics ingestion
# (DuckDB) over the day files of the nginx access log and writes the daily
# aggregates into the cube DB 'analytics'. After a successful run it deletes
# day files older than SM_LOG_RETENTION_DAYS, as they contain full IPs.

set -euo pipefail

cd "$(dirname "$0")/.."

usage() {
    cat <<'USAGE'
Verwendung: scripts/sightmetrics-import.sh [--heute]

Ohne Option läuft der Import inkrementell und übernimmt nur abgeschlossene
Tage – der laufende Tag erscheint erst beim ersten Lauf am Folgetag. Das ist
der Weg für einen täglichen Cron-Job.

  --heute     Alle Tagesdateien komplett neu einlesen und den laufenden Tag
              mitnehmen. Für die Vorführung: Zugriffe von eben sind sofort
              im Dashboard.
  -h, --help  Diese Hilfe

Nach jedem erfolgreichen Lauf werden Tagesdateien des Access-Logs gelöscht,
die älter als SM_LOG_RETENTION_DAYS (.env, Standard 7) sind.

Usage: scripts/sightmetrics-import.sh [--heute] – without options the import is
incremental and covers completed days only; --heute re-reads every day file and
includes today. Day files older than SM_LOG_RETENTION_DAYS are deleted after a
successful run.
USAGE
}

die() { printf '\nAbbruch: %s\n\n' "$*" >&2; exit 1; }

TODAY=false
while [ $# -gt 0 ]; do
    case "$1" in
        --heute)   TODAY=true ;;
        -h|--help) usage; exit 0 ;;
        *)         usage >&2; die "Unbekannte Option: $1" ;;
    esac
    shift
done

[ -f .env ] || die ".env fehlt – zuerst scripts/setup.sh ausführen."
set -a; . ./.env; set +a

RETENTION="${SM_LOG_RETENTION_DAYS:-7}"
[[ $RETENTION =~ ^[1-9][0-9]*$ ]] || die "SM_LOG_RETENTION_DAYS muss eine ganze Zahl ab 1 sein (ist: '$RETENTION')."

C="docker compose"

if [ "$TODAY" = true ]; then
    $C run --rm -e SM_TODAY=1 sightmetrics
else
    $C run --rm sightmetrics
fi

web_running() { $C ps --status running --services 2>/dev/null | grep -qx "$1"; }

# Löschfrist der Rohdaten. Direkt nach einem erfolgreichen Lauf unkritisch:
# Er hat jede abgeschlossene Tagesdatei vollständig übernommen. Gelöscht wird
# im web-Container, weil die Ingestion das Log nur lesend eingehängt hat.
# Raw data retention. Safe right after a successful run, which imported every
# completed day file in full. Deleted inside the web container because the
# ingestion mounts the log read-only.
if web_running web; then
    $C exec -T web find /var/log/nginx/sightmetrics -name 'access-*.log' \
        -mtime +"$RETENTION" -print -delete
fi

# Das Modul hält Cube-Abfragen bis zu sechs Stunden im TYPO3-Cache. Leeren,
# damit neue Zahlen sofort sichtbar sind. Als www-data, weil php-fpm var/
# sonst nicht mehr schreiben kann (HTTP 500 auf Linux).
# The module caches cube reads for up to six hours; flush so new numbers show
# up right away. As www-data, otherwise php-fpm can no longer write var/.
if web_running php; then
    $C exec -T -u www-data php vendor/bin/typo3 cache:flush >/dev/null
fi

printf '\nImport abgeschlossen. Backend: Web > SightMetrics\n\n'
