# Gehärtete Images von container.gov.de

[container.gov.de](https://container.gov.de/) ist das Verzeichnis der
**Secure Government Container Initiative** (SGCI) von ZenDiS und openCode.
Gelistet wird ein Image nur, wenn es eine VEX-Attestierung mitbringt und alle
bekannten Schwachstellen der Schweregrade Critical und High darin bewertet
sind ([Technische Zugangsvoraussetzungen](https://container.gov.de/docs/referenzen/technische-zugangsvoraussetzungen/)).
Die Images liegen in der Registry `registry.opencode.de`.

Dieses Dokument hält fest, welche Container des Stacks sich auf ein dort
gelistetes Image umstellen ließen – und warum das derzeit nicht geschieht.

## Stand der Prüfung

Geprüft am **30.09.2026** gegen die Verzeichnisdaten
(`https://container.gov.de/data.json` und `baseimages.json`) und die Manifeste
in `registry.opencode.de`:

| Service | Image heute | Gelistetes Gegenstück | Bewertung |
|---------|-------------|-----------------------|-----------|
| `web` | `nginx:stable-alpine` | `bundesdruckerei-gmbh/plain-images/nginx:1.31-alpine` | Grundsätzlich möglich, aber kein Drop-in (siehe unten) |
| `php` | `php:8.3-fpm-bookworm` | – | Kein PHP-Image im Verzeichnis |
| `db` | `mariadb:10.11` | – | Nur `oci-community/images/zendis/mariadb` (10.11.14, 11.8.6) in der Registry, **nicht gelistet** |
| `sightmetrics` | `debian:trixie-slim` | `oci-community/images/auswaertiges-amt/debian:13.7` | Kein Drop-in: Deb2Scratch-Seed ohne Shell und Paketverwaltung |

Alle geprüften Images gibt es **nur für `amd64`**. Auf einem Mac mit Apple
Silicon liefen sie emuliert.

## Einzelbefunde

**nginx (Bundesdruckerei).** Basis ist `nginxinc/nginx-unprivileged`: Der
Container läuft als Benutzer `nginx` und lauscht auf Port **8080** statt 80.
Eine Umstellung bräuchte:

- `listen 8080` in `docker/nginx/default.conf`, Portzuordnung und Healthcheck
  in `compose.yaml` angepasst
- `docker/nginx/30-sightmetrics.sh` läuft dann nicht mehr als root: das
  `chown` des Log-Verzeichnisses entfällt, `/run/sightmetrics` muss für
  `nginx` beschreibbar sein
- `USER root` für `apk upgrade` im Dockerfile, danach zurück auf `nginx`
- ein zusätzliches tmpfs für `/tmp` (PID-Datei und Temp-Pfade des
  unprivilegierten Images), weil der Container read-only läuft

Im Gegenzug entfiele für `web` die Ausnahme `DS-0002` in `.trivyignore`.

**MariaDB (ZenDiS).** Das Image bringt `docker-entrypoint.sh` und
`healthcheck.sh` mit und läuft als UID 999. Solange es nicht im Verzeichnis
steht, hat es die Compliance-Prüfung nicht bestanden – ein Tausch brächte
gegenüber dem offiziellen `mariadb`-Image keine geprüfte Zusicherung.

**Debian (Auswärtiges Amt).** Das gelistete Image ist ein 390 KB großer
Laufzeit-Seed (Benutzerkennung und Zertifikatsspeicher). Die Ingestion braucht
`bash`, `python3`, den MariaDB-Client und weitere Pakete; dafür wäre ein
Deb2Scratch-Build nötig. Das Dockerfile gehört außerdem zum Subtree von
SightMetrics – eine solche Änderung wäre upstream einzubringen.

## Erneut prüfen

Das Verzeichnis wächst laufend. Die gelisteten Images samt Tags:

```bash
curl -s https://container.gov.de/data.json https://container.gov.de/baseimages.json | jq -r '.[] | "\(.path)  \(.availableTags | join(", "))"'
```

Unterstützte Architekturen eines Images:

```bash
docker manifest inspect registry.opencode.de/bundesdruckerei-gmbh/plain-images/nginx:1.31-alpine
```
