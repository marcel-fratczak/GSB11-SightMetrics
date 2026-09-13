# GeoIP-Daten für SightMetrics

Dieses Verzeichnis ist im Ingestion-Container unter `/geo` eingehängt.

Mitgeliefert ist nur ein Platzhalter (`country-ipv4-num.csv`), der keiner
echten Adresse ein Land zuordnet. Das Dashboard führt die Länder dann als
unbekannt. Auf dem Notebook ist das ohnehin der Normalfall: Alle Zugriffe kommen
über Dockers Port-Weiterleitung und damit von einer internen Gateway-Adresse.

Echte GeoIP-Daten sind aus Lizenzgründen nicht Teil des Repositorys. Beispiel
DB-IP „IP to Country Lite" (CC BY 4.0, Namensnennung erforderlich, kein Konto
nötig):

1. CSV von <https://db-ip.com/db/download/ip-to-country-lite> laden und entpacken
2. hier ablegen, z. B. als `dbip-country-lite.csv`
3. in `.env` setzen:

   ```
   SM_GEO_SOURCE=dbip
   SM_GEO_FILE=dbip-country-lite.csv
   ```

Abgelegte CSV-Dateien sind per `.gitignore` von der Versionierung ausgenommen.
Weitere Quellen und Formate: [Ingestion-Runbook, Abschnitt 3a](../../../sightmetrics/docs/ingestion-runbook.md#3a-geoip-dataset-todo-for-operators).
