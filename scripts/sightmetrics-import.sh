#!/usr/bin/env bash
#
# GSB11-SightMetrics – Zugriffe auswerten
#
# Liest das nginx-Access-Log des web-Containers mit der SightMetrics-Ingestion
# (DuckDB) und schreibt die Tagesaggregate in die Cube-DB 'analytics'. Das
# Backend-Modul von SightMetrics zeigt sie anschließend an.
#
# GSB11-SightMetrics – analyse page views. Runs the SightMetrics ingestion
# (DuckDB) over the web container's nginx access log and writes the daily
# aggregates into the cube DB 'analytics', where the backend module reads them.

set -euo pipefail

cd "$(dirname "$0")/.."

usage() {
    cat <<'USAGE'
Verwendung: scripts/sightmetrics-import.sh [--heute]

Ohne Option läuft der Import inkrementell und übernimmt nur abgeschlossene
Tage – der laufende Tag erscheint erst beim ersten Lauf am Folgetag. Das ist
der Weg für einen täglichen Cron-Job.

  --heute     Log komplett neu einlesen und den laufenden Tag mitnehmen.
              Für die Vorführung: Zugriffe von eben sind sofort im Dashboard.
  -h, --help  Diese Hilfe

Usage: scripts/sightmetrics-import.sh [--heute] – without options the import is
incremental and covers completed days only; --heute re-reads the whole log and
includes today.
USAGE
}

TODAY=false
while [ $# -gt 0 ]; do
    case "$1" in
        --heute)   TODAY=true ;;
        -h|--help) usage; exit 0 ;;
        *)         usage >&2; printf '\nAbbruch: Unbekannte Option: %s\n\n' "$1" >&2; exit 1 ;;
    esac
    shift
done

[ -f .env ] || { printf '\nAbbruch: .env fehlt – zuerst scripts/setup.sh ausführen.\n\n' >&2; exit 1; }

C="docker compose"

if [ "$TODAY" = true ]; then
    # Die Cube-DB ersetzt jeden Tag, der in einem Lauf vorkommt. Ein Teil-Tag
    # ist deshalb nur korrekt, wenn der Lauf das ganze Log liest: Offsets vorher
    # verwerfen. Danach ebenfalls – sonst ersetzte der nächste inkrementelle
    # Lauf den heutigen Tag nur noch mit den Zeilen ab jetzt.
    # The cube DB replaces every day contained in a run, so a partial day is
    # only correct when the whole log is read: drop the offsets before. And
    # after – otherwise the next incremental run would replace today with only
    # the lines from now on.
    $C run --rm -e SM_COMPLETE_DAYS=0 sightmetrics -c \
        'rm -f /state/*.offset; rc=0; bash run_all.sh || rc=$?; rm -f /state/*.offset; exit $rc'
else
    $C run --rm sightmetrics
fi

# Das Modul hält Cube-Abfragen bis zu sechs Stunden im TYPO3-Cache. Leeren,
# damit neue Zahlen sofort sichtbar sind. Als www-data, weil php-fpm var/
# sonst nicht mehr schreiben kann (HTTP 500 auf Linux).
# The module caches cube reads for up to six hours; flush so new numbers show
# up right away. As www-data, otherwise php-fpm can no longer write var/.
if $C ps --status running --services 2>/dev/null | grep -qx php; then
    $C exec -T -u www-data php vendor/bin/typo3 cache:flush >/dev/null
fi

printf '\nImport abgeschlossen. Backend: Web > SightMetrics\n\n'
