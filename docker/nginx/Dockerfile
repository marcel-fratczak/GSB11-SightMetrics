# GSB11 – nginx-Webserver / nginx web server
FROM nginx:stable-alpine

# Sicherheitspatches der Alpine-Pakete einspielen (schließt behebbare CVEs)
# Apply Alpine package security patches (closes fixable CVEs)
RUN apk upgrade --no-cache

COPY default.conf /etc/nginx/conf.d/default.conf

# SightMetrics: Proxy-Adressen und Log-Verzeichnis beim Start vorbereiten
# SightMetrics: prepare proxy addresses and log directory at startup
COPY --chmod=0755 30-sightmetrics.sh /docker-entrypoint.d/30-sightmetrics.sh
