#!/usr/bin/env bash
#
# SightMetrics – Import aller Tagesdateien. Läuft im Container 'sightmetrics',
# aufgerufen über scripts/sightmetrics-import.sh.
#
# SightMetrics – import every day file. Runs inside the 'sightmetrics'
# container, started via scripts/sightmetrics-import.sh.
#
# nginx schreibt je Kalendertag eine Datei access-JJJJ-MM-TT.log. Jede wird zu
# einer Zeile einer temporären sites.conf (alle mit site_id 1); run_all.sh
# übernimmt Sperre, Offsets, Tagesgrenze und Fehlerzählung wie gewohnt. Schon
# vollständig importierte Dateien überspringt load_cube.sh anhand des Offsets.
#
# nginx writes one file access-YYYY-MM-DD.log per calendar day. Each becomes a
# line of a temporary sites.conf (all site_id 1); run_all.sh handles locking,
# offsets, the day cut and error counting as usual.
#
# SM_TODAY=1: laufenden Tag mitnehmen (scripts/sightmetrics-import.sh --heute).
# SM_TODAY=1: include the current day.

set -euo pipefail
shopt -s nullglob

files=(/logs/access-*.log)
if [ ${#files[@]} -eq 0 ]; then
    echo "Keine Tagesdateien unter /logs – seit dem Start noch keine Seitenaufrufe."
    exit 0
fi

sites=$(mktemp /tmp/sites_XXXXXX.conf)
for f in "${files[@]}"; do
    printf '1\t%s\t%s\n' "$f" "${SM_SITE_NAME:-GSB11}" >> "$sites"
done

if [ "${SM_TODAY:-0}" = 1 ]; then
    # Die Cube-DB ersetzt jeden Tag, der in einem Lauf vorkommt. Ein Teil-Tag
    # ist deshalb nur korrekt, wenn der Lauf die ganze Datei liest: Offsets
    # vorher verwerfen. Danach ebenfalls – sonst ersetzte der nächste
    # inkrementelle Lauf den heutigen Tag nur noch mit den Zeilen ab jetzt.
    # The cube DB replaces every day contained in a run, so a partial day is
    # only correct when the whole file is read: drop the offsets before. And
    # after – otherwise the next incremental run would replace today with only
    # the lines from now on.
    rm -f /state/*.offset
    rc=0
    SM_COMPLETE_DAYS=0 bash /app/run_all.sh --sites "$sites" || rc=$?
    rm -f /state/*.offset
    exit "$rc"
fi

exec bash /app/run_all.sh --sites "$sites"
