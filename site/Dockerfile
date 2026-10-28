# Site CLEARANCE — build Astro statique, servi par nginx (port 8080).
FROM node:24-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY . .
ARG SITE_URL=https://clearance.cardormedia.com
ARG PUBLIC_DOWNLOAD_URL=https://github.com/fs0ciety7000/clearance/releases
ENV SITE_URL=$SITE_URL PUBLIC_DOWNLOAD_URL=$PUBLIC_DOWNLOAD_URL ASTRO_TELEMETRY_DISABLED=1
RUN npm run build

FROM nginx:1.29-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --retries=3 CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1
