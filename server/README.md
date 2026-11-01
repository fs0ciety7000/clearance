# Serveur en ligne CLEARANCE (M16)

PocketBase **0.40.6** (version figée, somme sha256 vérifiée à la construction) avec les
migrations (`pb_migrations/`) et les crochets (`pb_hooks/`) du jeu. Il sert :

- les **comptes sans mot de passe** (code à 6 chiffres envoyé par e-mail) ;
- les **sauvegardes dans le cloud** (facultatives, hors ligne d'abord) ;
- le **classement de la Garde de nuit** ;
- les **statistiques des fins** (pourcentages anonymes).

Contrat d'API complet : [`docs/ONLINE.md`](../docs/ONLINE.md). Décisions : D-230 → D-235.

```
server/
  Dockerfile              image de production (Alpine + PocketBase figé, utilisateur non root)
  docker-entrypoint.sh    lance `pocketbase serve` avec les bons drapeaux
  pb_migrations/          schéma : users (OTP), saves, garde_scores, ending_events, règles, index
  pb_hooks/               routes /api/clearance/*, validation, plausibilité, fréquences, réglages
  dev_hooks/              mode dev OTP — JAMAIS dans l'image (exclu par .dockerignore)
  tests/api_test.mjs      tests d'intégration (tools/test_online_server.sh)
```

---

## 1. Déploiement sur Coolify, pas à pas

Prérequis : Coolify relié au dépôt GitHub du jeu (comme pour le site, `site/README.md`),
et la zone DNS `cardormedia.com` (Cloudflare).

1. **DNS** — enregistrement `A api.clearance.cardormedia.com → IP du serveur Coolify`.
   Cloudflare : proxifié (nuage orange) accepté, SSL/TLS **Full (strict)**. Laisser
   *Rocket Loader* et toute transformation de réponse désactivés pour ce sous-domaine.
2. **Nouvelle ressource** — *Projects › (projet CLEARANCE) › + New › Application* →
   *Public/Private Repository (GitHub App)* → dépôt du jeu, branche de production.
3. **Build Pack** : `Dockerfile`.
   - **Base Directory** : `/server`
   - **Dockerfile Location** : `/Dockerfile`
   - **Ports Exposes** : `8090`
4. **Domaine** — *Configuration › General › Domains* :
   `https://api.clearance.cardormedia.com` (Coolify/Traefik obtient le certificat).
   Si l'interface demande le port : `https://api.clearance.cardormedia.com:8090` est
   la notation Coolify pour « ce domaine → port 8090 du conteneur ».
5. **Stockage persistant** — *Configuration › Persistent Storage › + Add* :
   type **Volume**, nom `clearance-pb-data`, *Destination Path* **`/pb/pb_data`**.
   ⚠️ Sans ce volume, **toutes les données sont perdues** à chaque redéploiement.
   Utiliser un *volume* (pas un *bind mount*) : le conteneur tourne en utilisateur
   non root (uid 10001) et Docker initialise un volume neuf avec les bons droits.
   (Bind mount malgré tout : `chown -R 10001:10001 <dossier hôte>` avant le démarrage.)
6. **Variables d'environnement** — *Configuration › Environment Variables* (voir §2).
   Cocher **« Is Literal »**/secret pour `SMTP_PASSWORD` et `PB_ENCRYPTION_KEY`, et
   **décocher « Build Variable »** pour ces deux-là (elles ne servent qu'à l'exécution).
7. **Health check** — l'image déclare déjà un `HEALTHCHECK` (`/api/health`). Dans
   Coolify, *Health Checks* : chemin `/api/health`, port `8090` (facultatif).
8. **Deploy**. Le premier démarrage applique les migrations (collections, règles,
   index) puis les réglages tirés des variables (SMTP, limites, sauvegardes…).
9. **Compte superadmin** (console `https://api.clearance.cardormedia.com/_/`) —
   *Coolify › l'application › Terminal* (conteneur en cours d'exécution) :

   ```sh
   /pb/pocketbase superuser upsert "admin@cardormedia.com" "<mot de passe long et unique>" --dir /pb/pb_data --encryptionEnv=PB_ENCRYPTION_KEY
   ```

   Le mot de passe ne va **jamais** dans le dépôt ni dans les variables Coolify ;
   le ranger dans le gestionnaire de mots de passe du studio. (Autre voie : au premier
   démarrage, le journal affiche un lien `…/_/#/pbinstall/…` à usage unique ; remplacer
   `http://0.0.0.0:8090` par `https://api.clearance.cardormedia.com`.)
   Puis, dans la console : *Settings › Superusers* → activer **MFA**/OTP pour le
   superadmin si souhaité, et éventuellement restreindre `superuserIPs`.
10. **Vérifications** (depuis un poste quelconque) :

    ```sh
    curl -s https://api.clearance.cardormedia.com/api/health
    curl -s https://api.clearance.cardormedia.com/api/clearance/status
    curl -sI https://api.clearance.cardormedia.com/api/clearance/status | grep -i cross-origin-resource-policy
    curl -s -X POST -H 'Content-Type: application/json' \
         -d '{"email":"<votre adresse>"}' https://api.clearance.cardormedia.com/api/collections/users/request-otp
    ```

    Le dernier appel doit déposer un code dans votre boîte (sinon : §5). Le compte de
    test se supprime ensuite depuis la console (*Collections › users*).
11. **Site** (lot W) : ajouter `https://api.clearance.cardormedia.com` à `connect-src`
    de la CSP de `/play/` dans `site/nginx.conf` (`docs/ONLINE.md` §1.2).

---

## 2. Variables d'environnement

| Variable | Défaut | Rôle |
|---|---|---|
| `SMTP_HOST` | *(vide = e-mails désactivés)* | serveur SMTP (ex. `smtp.eu.mailgun.org`, `smtp-relay.brevo.com`, `email-smtp.eu-west-1.amazonaws.com`) |
| `SMTP_PORT` | `587` | 587 (STARTTLS) ou 465 (TLS implicite) |
| `SMTP_USERNAME` | | identifiant SMTP |
| `SMTP_PASSWORD` | | **secret** — mot de passe / clé SMTP |
| `SMTP_TLS` | `1` si port 465, sinon `0` | `1` = TLS implicite ; `0` = STARTTLS automatique |
| `SMTP_AUTH_METHOD` | `PLAIN` | `PLAIN` ou `LOGIN` |
| `SMTP_SENDER_ADDRESS` | `no-reply@cardormedia.com` | expéditeur (domaine autorisé chez le fournisseur : SPF/DKIM) |
| `SMTP_SENDER_NAME` | `CLEARANCE` | nom de l'expéditeur |
| `PB_ENCRYPTION_KEY` | *(vide = pas de chiffrement)* | **secret**, **exactement 32 caractères** : chiffre les réglages stockés (dont `SMTP_PASSWORD`) dans `pb_data`. Générer : `openssl rand -hex 16`. Ne plus jamais le changer ensuite (sinon réglages illisibles). |
| `CLEARANCE_ORIGINS` | `https://clearance.cardormedia.com,https://www.clearance.cardormedia.com` | origines CORS autorisées (page `/play/`). Les clients natifs n'envoient pas d'`Origin`. |
| `CLEARANCE_TRUSTED_PROXY_HEADERS` | `CF-Connecting-IP,X-Forwarded-For` | en-têtes donnant l'IP réelle (limites par IP). Sans Cloudflare : `X-Forwarded-For`. |
| `CLEARANCE_APP_URL` | `https://api.clearance.cardormedia.com` | URL publique (liens de la console) |
| `CLEARANCE_OTP_PER_10MIN` | `5` | demandes de code par IP et par 10 min (échanges : le double) |
| `CLEARANCE_RATE_LIMITS` | `1` | `0` désactive les limites par IP de PocketBase (déconseillé) |
| `CLEARANCE_ENDINGS_CACHE_S` | `300` | cache des agrégats de fins (s) |
| `CLEARANCE_GARDE_MIN_INTERVAL_S` | `15` | délai minimal entre deux envois de score d'un même compte |
| `CLEARANCE_BACKUP_CRON` | `0 3 * * *` | sauvegarde automatique PocketBase (cron UTC) ; `off` pour désactiver |
| `CLEARANCE_BACKUP_KEEP` | `7` | nombre de sauvegardes automatiques gardées |
| `CLEARANCE_LOG_DAYS` | `7` | rétention des journaux de requêtes |
| `CLEARANCE_HIDE_CONTROLS` | `1` | masque l'édition du schéma dans la console (le schéma vient des migrations) |

Les réglages correspondants sont **réappliqués à chaque démarrage** : Coolify est la
source de vérité ; une modification faite dans la console (*Settings › Mail settings*,
*Rate limits*…) est écrasée au redémarrage suivant. Les réglages S3 de sauvegarde
(*Settings › Backups › S3*) ne sont pas touchés.

**Ne jamais** définir `CLEARANCE_DEV_OTP` en production (sans effet de toute façon :
le crochet de dev n'est pas dans l'image).

---

## 3. Sauvegardes des données

Tout l'état du serveur est dans le volume `/pb/pb_data` (SQLite `data.db`,
`auxiliary.db`, sauvegardes `backups/`).

- **Automatique (PocketBase)** : chaque nuit à 03:00 UTC (`CLEARANCE_BACKUP_CRON`), une
  archive `.zip` cohérente est écrite dans `pb_data/backups/` (7 gardées). Elle est sur
  le **même disque** : configurer en plus une copie hors serveur :
  - *Console › Settings › Backups › Store backups in S3* (bucket S3/R2/B2/MinIO), ou
  - la sauvegarde de volume de Coolify / du serveur (snapshot du disque).
- **Manuelle** : *Console › Settings › Backups › Backup now*, puis télécharger l'archive.
- **Restauration** : *Console › Settings › Backups › (archive) › Restore* (redémarre
  l'application), ou, conteneur arrêté, remplacer le contenu du volume par celui de l'archive.
- Tester une restauration sur une instance locale au moins une fois
  (`tools/online_dev_server.sh --data <dossier>` avec le contenu de l'archive).

---

## 4. Mise à jour

- **Du jeu (migrations/crochets)** : pousser sur la branche suivie, puis *Redeploy*
  dans Coolify. Les nouvelles migrations (`pb_migrations/<horodatage>_<nom>.js`) sont
  appliquées au démarrage ; ne **jamais** modifier une migration déjà déployée : en
  ajouter une nouvelle.
- **De PocketBase** : lire les notes de version (changements incompatibles du JSVM,
  des règles, des migrations) ; changer `PB_VERSION` et les deux `PB_SHA256_*` du
  `Dockerfile` **et** de `tools/online_dev_server.sh` (sommes de `checksums.txt` de la
  release) ; lancer `tools/test_online_server.sh` ; faire une sauvegarde manuelle ;
  redéployer. Note : 0.40.6 annonce être la dernière version publiée sur GitHub
  (les suivantes seraient sur un autre hôte) : toute mise à jour passe par une
  décision (source de téléchargement, somme, revue).
- Avant toute mise à jour : *Backup now*.

---

## 5. Dépannage

| Symptôme | Piste |
|---|---|
| Pas d'e-mail de code | `request-otp` répond `200` même si l'envoi échoue : voir *Console › Logs* (erreur SMTP). Vérifier `SMTP_*`, l'expéditeur autorisé (SPF/DKIM), le port (465 ⇒ `SMTP_TLS=1`). *Console › Settings › Mail settings › Send test email*. |
| `429` pour tout le monde | IP réelle mal transmise : tous les joueurs partagent l'IP du proxy. Régler `CLEARANCE_TRUSTED_PROXY_HEADERS` (Cloudflare : `CF-Connecting-IP`). Vérifier dans *Console › Logs* que l'IP affichée est celle du client. |
| La version Web n'atteint pas l'API | CSP de `/play/` (`connect-src`), `CLEARANCE_ORIGINS`, en-tête `Cross-Origin-Resource-Policy: cross-origin` présent (`curl -sI`). |
| Données disparues après redéploiement | Volume persistant absent ou mal monté (`/pb/pb_data`). Restaurer depuis une sauvegarde. |
| `permission denied` sur `pb_data` | Bind mount au lieu d'un volume : `chown -R 10001:10001` sur le dossier hôte. |
| Réglages illisibles au démarrage | `PB_ENCRYPTION_KEY` changée ou supprimée après coup : remettre l'ancienne valeur. |

---

## 6. Développement local et tests

```sh
tools/online_dev_server.sh            # PocketBase local sur http://127.0.0.1:8090 (mode dev OTP)
tools/online_dev_server.sh --fresh    # repart d'une base vide
tools/test_online_server.sh           # lance un serveur neuf + tests d'intégration (Node ≥ 18)
```

- Binaire téléchargé (et vérifié) dans `build/pocketbase/` (ignoré par git).
- Superadmin de test : `dev@clearance.local`, mot de passe aléatoire à chaque lancement (ou `CLEARANCE_DEV_SUPERUSER_PASSWORD`), copié dans `<data>/.dev_superuser` — **local uniquement**.
- Mode dev OTP : aucun e-mail ; code dans le journal (`[dev-otp] <otpId> <code>`) et via
  `GET /api/clearance/dev/otp?otpId=…` (`docs/ONLINE.md` §10).
- Les tests GUT du jeu n'utilisent jamais le réseau réel (M16 §3) ; un test d'intégration
  facultatif du client peut viser ce serveur local.

---

## 7. Politique de confidentialité (courte)

> **CLEARANCE — compte en ligne et confidentialité**
>
> Le compte en ligne est **facultatif** : le jeu est entièrement jouable sans compte
> ni connexion.
>
> **Données conservées** — si vous créez un compte : votre **adresse e-mail** (pour
> vous envoyer les codes de connexion, jamais affichée ni partagée) ; un **pseudo**
> facultatif et un **identifiant court** (ex. `#B8C0`), visibles dans le classement de
> la Garde de nuit ; vos **sauvegardes** (pour les retrouver sur vos autres appareils) ;
> vos **meilleurs scores** de Garde de nuit ; les **fins** que vous avez obtenues,
> utilisées uniquement pour calculer des pourcentages anonymes (« X % des agents »).
>
> **Ce que nous ne faisons pas** — pas de publicité, pas de revente, pas de traceur, pas
> de télémétrie au-delà de ces données. Les e-mails passent par notre prestataire
> d'envoi (SMTP) ; les données sont hébergées sur notre serveur. Les journaux
> techniques (adresse IP, requêtes) sont gardés **7 jours** pour la sécurité.
>
> **Vos droits** — *Options › Compte › Supprimer le compte et les données* efface
> immédiatement et définitivement le compte et toutes les données associées sur le
> serveur (vos fichiers locaux restent sur votre appareil). Les sauvegardes
> automatiques du serveur, qui peuvent encore les contenir, sont écrasées sous
> 7 jours. Pour toute question ou demande (accès, rectification) : contact indiqué
> sur clearance.cardormedia.com.

*English summary* — The online account is optional. We store your e-mail address
(sign-in codes only, never shown), an optional nickname and a short public tag
(leaderboard), your cloud saves, your best Night Watch scores and the endings you
reached (anonymous percentages only). No ads, no tracking, no resale. Server logs are
kept 7 days. *Options › Account › Delete account and data* erases everything
immediately (server backups roll over within 7 days).
