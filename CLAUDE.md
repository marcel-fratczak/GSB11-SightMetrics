# GSB11-SightMetrics – Projektkontext

Government Site Builder 11 (TYPO3 13.4 LTS) als lokaler Docker-Stack, gebaut
als Live-Demo für einen Vortrag auf den TYPO3 University Days – erweitert um
die Zugriffsauswertung SightMetrics. Hervorgegangen aus T3UD-GSB11
(Historie vollständig übernommen).

## Stack

- **Basis:** `itzbund/gsb-sitepackage` von Open CoDE, per
  `composer create-project` zur Installationszeit nach `./app` geholt.
  `./app` ist nicht versioniert.
- **Container:** `web` (nginx:stable-alpine), `php` (php:8.3-fpm-bookworm),
  `db` (mariadb:10.11), `sightmetrics` (Einmal-Container, Profil
  `sightmetrics`). Compose-Projektname `gsb11-sightmetrics` – bewusst nicht
  `t3ud-gsb11`, sonst teilt sich der Stack Volumes mit einer
  T3UD-GSB11-Installation auf demselben Rechner.
- **Docroot:** `app/.build/public` – Composer-Mode, nicht `public/`.
- **Skripte:** Bash, kompatibel zu macOS-Bash 3.2 (kein `mapfile`, keine
  assoziativen Arrays).

## Wichtige Eigenheiten der Distribution

- **Das Projekt-Root *ist* die Sitepackage-Extension** (`gsb_sitepackage`).
  Ihre Assets liegen unter `app/Resources/Public/` und hängen als Symlink
  im Docroot unter `_assets/6666cd76f96956469e7be39d750cc7d9/`.
  Eine Datei dort zu überschreiben wirkt sofort, ohne Rebuild.
- **Anpassungspunkt für Mandanten** ist
  `Resources/Public/StyleSheets/mandant.css` – Verzeichnis mit **großem S**,
  eingebunden über `Configuration/TypoScript/setup.typoscript`.
- **Primär-/Sekundärfarbe gehören nicht ins Stylesheet.** `EXT:gsb_core`
  erzeugt `--bs-primary`/`--bs-secondary` als Inline-Style aus
  `config/sites/gsb/settings.yaml`
  (`colors.colorGeneral.gsb-color-primary` usw.).
- **Grundinhalte** kommen aus `.ddev/initial-setup/mysql-db.sql`. Danach ist
  `sys_template.include_static_file` auf
  `EXT:gsb_sitepackage/Configuration/TypoScript/` zu setzen, sonst rendert das
  Frontend ohne Layout.
- **colPos 0 = `top-container`** (volle Breite), **colPos 1 = Inhaltsspalte**.
  Der Democontent nutzt colPos 0.
- **Nach dem Setup `chown -R www-data:www-data`** im php-Container. Das Setup
  läuft als root, php-fpm bedient Requests als `www-data` und muss `var/`,
  `config/system` und `fileadmin` schreiben können – sonst HTTP 500 auf Linux.

## Democontent

- Quelle: `demo/` (HTML-Fragmente, `mandant.css`, Grafiken).
- Import: `scripts/demo-content.sh`, idempotent. Marker:
  `tt_content.rowDescription = 'T3UD-Democontent'` und die Slugs
  `/programm`, `/impressionen`.
- Inhaltselemente sind CType `html`; die Bilder sind **keine** FAL-Referenzen,
  sondern liegen als Dateien unter `fileadmin/user_upload/t3ud/`.
- HTML wird per `sed`-Escaping (Backslash zuerst, dann Hochkomma) in ein
  SQL-String-Literal geschrieben. Wer Inhalte ergänzt: beides bleibt maskiert,
  Backticks und `$` sind unkritisch, weil kein Shell-Parser darüber läuft.

## SightMetrics

- **Herkunft:** `git subtree` von
  `git@github.com:TheMightyNighty/SightMetrics.git` (Branch `master`) unter
  `sightmetrics/`, ohne `--squash`. Änderungen am Code des Kollegen möglichst
  upstream einbringen statt im Subtree – sonst gibt es beim
  `git subtree pull` Konflikte. Die Workflows unter `sightmetrics/.github/`
  laufen hier nicht.
- **Lokale Abweichung vom Upstream:** `sightmetrics/ingestion/Dockerfile` hat
  zusätzlich `apt-get upgrade -y`. Ohne das fällt das Image durch das
  Trivy-Gate (am 2026-09-13: 4 behebbare `pcre2`-CVEs aus `debian:bookworm-slim`).
  Beim Subtree-Pull erhalten, bis es upstream übernommen ist.
- **Extension:** `sightmetrics/extension/sight_metrics` ist in `web` und `php`
  unter `/packages/sight_metrics` eingehängt (gleicher Pfad in beiden, weil
  die `_assets`-Symlinks über `vendor/` dorthin zeigen). `setup.sh` bindet sie
  als Composer-Path-Repository ein; `app/composer.json` wird dabei verändert.
- **Verbindung `cube`** kommt aus `TYPO3__DB__Connections__cube__*` in
  `compose.yaml`. Der GSB11 mappt alle `TYPO3__`-Variablen über
  `helhum/config-loader` – kein `additional.php` nötig.
- **Cube-DB** `analytics` im selben MariaDB; `cube_rw` (Ingestion) und
  `report_ro` (nur SELECT, Extension). Angelegt in `setup.sh` Schritt 8 über
  den `db`-Container als root, nicht per initdb – das greift bei einem schon
  bestehenden Volume nicht. Die Tabellen legt erst der erste Import an.
- **Log:** nginx schreibt zusätzlich eine Tagesdatei
  `/var/log/nginx/sightmetrics/access-JJJJ-MM-TT.log` (Volume
  `sightmetrics-logs`, Zeitzone `TZ` = `SM_TZ`), `/typo3` per `map`
  ausgenommen. Besucher-IP per `geo`/`map` aus `X-Forwarded-For`, nur von
  Adressen aus `REVERSE_PROXY_IP`; die Liste schreibt
  `docker/nginx/30-sightmetrics.sh` beim Start nach `/run/sightmetrics/`.
- **Import:** `scripts/sightmetrics-import.sh` (`--heute` für die Vorführung)
  startet `docker/sightmetrics/import.sh` im Container, das aus den
  Tagesdateien eine temporäre `sites.conf` baut und `run_all.sh` aufruft.
  Danach Löschfrist (`SM_LOG_RETENTION_DAYS`, im web-Container) und
  TYPO3-Cache leeren als `www-data`.
- **Produktivbetrieb** hinter dem NetBird Reverse Proxy: `docs/reverse-proxy.md`,
  Fall 4. Konkrete Domains gehören nicht ins Repo (öffentlich).

## Inhaltliche Leitplanken

Das Repository ist öffentlich und bezieht sich auf eine reale Veranstaltung:

- Kein Personenbezug im Content, keine echten Namen, keine privaten Domains.
- Das Programm ist **erfunden** und muss als Beispielprogramm gekennzeichnet
  bleiben (Hinweisbox auf `/programm`, Link auf t3th.org).
- Die Abbildungen sind stilisierte Grafiken und müssen als solche
  gekennzeichnet bleiben (Hinweisbox auf `/impressionen`).
- Nicht als offizielles Angebot des ITZBund oder der T3UD auftreten.

## CI

- `security.yml`: Trivy (Images, Config, Secrets) + CycloneDX-SBOM,
  wöchentlich montags 06:00 UTC, zusätzlich bei Push/PR.
  Hartes Gate nur für die **eigenen** Images und nur bei **behebbaren**
  MEDIUM/HIGH/CRITICAL; `mariadb` erzeugt nur eine Warn-Annotation, weil das
  Image unverändert von upstream kommt.
- `smoke.yml`: installiert den Stack nicht-interaktiv inklusive Democontent
  und prüft Frontend, Backend, beide Demoseiten, die gerenderten Sektionen und
  die Idempotenz des Importers.
- SBOM wird über `scripts/normalize-sbom.py` normalisiert, bevor sie
  zurückcommittet wird – sonst rauscht jeder Build durch `sbom/`.
- `.trivyignore` enthält `DS-0002` (kein `USER` im Dockerfile) mit Begründung.

## Stolpersteine, die schon Zeit gekostet haben

- **Der `mysql`-Client im php-Image verbindet sich als `latin1`.** Jeder Aufruf
  braucht `--default-character-set=utf8mb4`, sonst nimmt der Server UTF-8-Inhalte
  als latin1 entgegen und kodiert sie doppelt: aus `ö` (`C3 B6`) wird `Ã¶`
  (`C3 83 C2 B6`). Der Grundinhalts-Dump der Distribution fällt nicht darauf
  herein, weil er sein eigenes `SET NAMES utf8mb4` mitbringt – wer eine eigene
  Anweisung ergänzt, schon. `smoke.yml` prüft das Frontend deshalb auf `Ã`.
- **Dateien nach `app/` immer durch den Container schreiben**, nie vom Host.
  `setup.sh` chownt `app/` zum Schluss auf `www-data`; ein Host-Schreibzugriff
  scheitert danach unter Linux mit `Permission denied`. Auf macOS fällt das
  nicht auf, weil Docker Desktop die Eigentümer bei Bind-Mounts umschreibt.
- `pecl install` im PHP-Build bricht bei wackliger Leitung ab. Der Fehler sieht
  nach einem Konfigurationsproblem aus, ist aber transient – einfach erneut
  bauen, gecachte Layer bleiben erhalten.
- `TRUSTED_HOSTS_PATTERN` ist ein regulärer Ausdruck gegen den Host-Header.
  Passt er nicht, gibt es HTTP 500 statt einer Fehlermeldung, die das sagt.
- Docker trägt seine iptables-Regeln vor denen von ufw/firewalld ein. Bei
  veröffentlichten Ports greift keine Host-Firewall – `BIND_IP` ist die Grenze.
- `head` gehört bei der Passworterzeugung an den **Anfang** der Pipe. Am Ende
  beendet es `tr` per SIGPIPE, und unter `set -o pipefail` bricht das den Lauf ab.
- **SightMetrics ersetzt pro Lauf jeden enthaltenen Tag komplett.** Ein
  inkrementeller Lauf mit einem angebrochenen Tag würde dessen frühe Stunden
  beim nächsten Lauf verlieren; deshalb hält der Standard-Import den laufenden
  Tag zurück. `--heute` verwirft die Offsets vor **und** nach dem Lauf – fehlt
  das zweite Löschen, zerstört der nächste Cron-Lauf den heutigen Tag.
- **`curl` zählt in SightMetrics nicht:** Die eingebaute Bot-Heuristik filtert
  den User-Agent. Tests brauchen einen Browser-UA.
- **Ohne GeoIP-Datei bricht die Ingestion ab.** Der Platzhalter
  `docker/sightmetrics/geo/country-ipv4-num.csv` muss bleiben.
- **Kein nginx-realip-Modul für die Besucher-IP.** Es schreibt `REMOTE_ADDR`
  um; TYPO3 erkennt den Proxy dann nicht mehr über `reverseProxyIP`, und
  `reverseProxySSL` greift nicht (http-Links, Redirect-Schleifen). Die IP wird
  nur fürs SightMetrics-Log per `geo`/`map` bestimmt.
- **Log-Rotation per Umbenennen verliert Daten.** Die Ingestion erkennt sie am
  Inode und liest die neue Datei ab Byte 0; die zurückgestellten Zeilen des
  laufenden Tags in der alten Datei gehen verloren. Deshalb Tagesdateien.
- **Variable im `access_log`-Pfad:** nginx prüft dann das `root`-Verzeichnis
  und schreibt ohne existierendes `root` still nichts. Der Worker (`nginx`)
  legt die Dateien an – das Verzeichnis muss ihm gehören.
- **TYPO3 wertet `X-Forwarded-For` nur mit `reverseProxyHeaderMultiValue`
  aus** (Standard `none`). Ohne `last` sieht auch die IP-basierte
  Login-Sperre alle Besucher unter der Proxy-Adresse.

## Repository

- Remote `origin`: `git@github.com:marcel-fratczak/GSB11-SightMetrics.git`
  (SSH, public). Push über den Account `blutfisch` (Collaborator).
- Remote `sightmetrics`: `git@github.com:TheMightyNighty/SightMetrics.git`
  (nur für `git subtree pull`)
- Branch: `main`
- Commit-Identität vor dem ersten Commit prüfen:
  `git log -1 --format='%an <%ae>'`
