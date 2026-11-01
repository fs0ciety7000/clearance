# Site CLEARANCE — build Astro statique, servi par nginx (port 8080).
FROM node:24-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY . .
ARG SITE_URL=https://clearance.cardormedia.com
ARG PUBLIC_DOWNLOAD_URL=https://github.com/fs0ciety7000/clearance/releases/latest
ARG PUBLIC_VERSION=1.0.0
ARG PUBLIC_RELEASED=0
ARG PUBLIC_WEB_DEMO=0
ARG PUBLIC_WEB_DEMO_URL=/play/
# Facultatif : archive .zip de l'export Web (index.html à la racine), dépliée dans public/play/ avant le build.
ARG WEB_DEMO_ZIP_URL=
ENV SITE_URL=$SITE_URL PUBLIC_DOWNLOAD_URL=$PUBLIC_DOWNLOAD_URL PUBLIC_VERSION=$PUBLIC_VERSION \
    PUBLIC_RELEASED=$PUBLIC_RELEASED PUBLIC_WEB_DEMO=$PUBLIC_WEB_DEMO PUBLIC_WEB_DEMO_URL=$PUBLIC_WEB_DEMO_URL \
    ASTRO_TELEMETRY_DISABLED=1
# L'archive contient un dossier racine (CLEARANCE-<version>-web/) : on copie le dossier qui
# porte index.html directement dans public/play/, et le build échoue si index.html manque.
RUN if [ -n "$WEB_DEMO_ZIP_URL" ]; then \
      mkdir -p public/play /tmp/webzip && wget -qO /tmp/web.zip "$WEB_DEMO_ZIP_URL" \
      && unzip -qo /tmp/web.zip -d /tmp/webzip \
      && src="$(dirname "$(find /tmp/webzip -maxdepth 2 -name index.html | head -n 1)")" \
      && cp -a "$src"/. public/play/ && rm -rf /tmp/web.zip /tmp/webzip \
      && test -f public/play/index.html; \
    fi
RUN npm run build

FROM nginx:1.29-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --retries=3 CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1
