# CLEARANCE — serveur en ligne (M16, D-230) : PocketBase figé + migrations + crochets.
# Déploiement Coolify : server/README.md. Contrat d'API : docs/ONLINE.md.
FROM alpine:3.22

# Version figée et sommes sha256 publiées dans checksums.txt de la release GitHub officielle
# (https://github.com/pocketbase/pocketbase/releases/tag/v0.40.6). Mise à jour : README §8.
ARG PB_VERSION=0.40.6
ARG PB_SHA256_AMD64=0e1f609158ed945f809f8a02ae012aa0427129c66ebb63c1aee76f2c0309373f
ARG PB_SHA256_ARM64=d22c66ceb67ca92b7d767f36d826e848a276bcfa3c197ead20bf87c42208984f
ARG TARGETARCH

RUN set -eux; \
	apk add --no-cache ca-certificates tzdata; \
	apk add --no-cache --virtual .fetch wget unzip; \
	arch="${TARGETARCH:-$(uname -m)}"; \
	case "$arch" in \
		amd64|x86_64) pb_arch=amd64; pb_sum="$PB_SHA256_AMD64" ;; \
		arm64|aarch64) pb_arch=arm64; pb_sum="$PB_SHA256_ARM64" ;; \
		*) echo "Architecture non prise en charge : $arch" >&2; exit 1 ;; \
	esac; \
	wget -q -O /tmp/pb.zip "https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_${pb_arch}.zip"; \
	echo "${pb_sum}  /tmp/pb.zip" | sha256sum -c -; \
	mkdir -p /pb; \
	unzip -q /tmp/pb.zip pocketbase -d /pb; \
	rm /tmp/pb.zip; \
	chmod 0755 /pb/pocketbase; \
	apk del .fetch; \
	addgroup -S -g 10001 pb; \
	adduser -S -D -H -u 10001 -G pb pb; \
	mkdir -p /pb/pb_data; \
	chown pb:pb /pb/pb_data

COPY pb_migrations /pb/pb_migrations
COPY pb_hooks /pb/pb_hooks
COPY docker-entrypoint.sh /pb/docker-entrypoint.sh
RUN chmod 0755 /pb/docker-entrypoint.sh

USER pb
WORKDIR /pb
VOLUME /pb/pb_data
EXPOSE 8090

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
	CMD wget -q -O /dev/null http://127.0.0.1:8090/api/health || exit 1

ENTRYPOINT ["/pb/docker-entrypoint.sh"]
