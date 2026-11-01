# ONLINE — contrat d'API du serveur CLEARANCE (M16, lot S)

Propriétaire : Architecte back-end (lot S). Lecteurs : lot C (client Godot), lot W (site).
Décisions : D-230 → D-235 (+ propositions S-1 → S-5, §12). Contrat parent : `docs/M16.md`.
Version du contrat : **API 1** (`api_version` de `GET /api/clearance/status`).
Serveur : **PocketBase 0.40.6** (`server/`), une seule instance, SQLite.

> Toute modification incompatible de ce document passe par l'Orchestrateur et
> incrémente `api_version`. Les ajouts compatibles (nouveau champ en réponse,
> nouvelle route) n'incrémentent pas : **le client ignore les champs inconnus**.

---

## 1. Généralités

| | |
|---|---|
| URL de base (production) | `https://api.clearance.cardormedia.com` |
| URL de base (dev local) | `http://127.0.0.1:8090` (`tools/online_dev_server.sh`) |
| Format | JSON UTF-8 (`Content-Type: application/json`) en requête et en réponse |
| Authentification | en-tête `Authorization: <jeton>` (le préfixe `Bearer ` est aussi accepté) |
| Horodatages | `*_unix_ms` = millisecondes Unix (entier) ; `created`/`updated` = chaîne PocketBase `"2026-11-01 02:00:25.123Z"` (UTC) |
| Entiers | ≤ 2^53 − 1 (exacts en JSON ; les graines du jeu sont déjà sur 53 bits) |

- L'URL de base est une **constante surchargeable** côté client (réglage). Le jeu reste entièrement jouable si elle est injoignable (M16 §1).
- **Délais conseillés** côté client : connexion 5 s, requête 10 s ; nouvelles tentatives espacées (2 s, 8 s, 30 s, puis abandon jusqu'à la prochaine occasion) **uniquement** sur erreur réseau, `429` ou `5xx` ; jamais sur `4xx` (sauf `429`).
- Tous les chemins propres au jeu commencent par **`/api/clearance/`** ; l'authentification utilise les routes PocketBase standard de la collection `users`.

### 1.1 Format des erreurs

Toute erreur a la forme PocketBase, enrichie d'un `code` stable sur les routes `/api/clearance/*` :

```json
{ "status": 422, "code": "score_implausible", "message": "Score hors des bornes plausibles.", "data": { "reasons": ["score_above_max"] } }
```

- `message` : texte anglais/français pour les journaux, **jamais affiché tel quel** : le client traduit d'après `status` + `code`.
- `data` : détails facultatifs (champs fautifs : `data.<champ> = {code, message}` comme PocketBase).
- Les routes PocketBase natives (OTP, `users`) renvoient `{status, message, data}` **sans** `code`.

| HTTP | `code` | Sens / réaction du client |
|---|---|---|
| 400 | `bad_request` | Corps illisible ou paramètre manquant. Bug client : journaliser, ne pas réessayer. |
| 400 | `invalid_field` | Champ invalide ; `data.<champ>.code` (`required`, `out_of_range`, `bad_format`, `bad_value`). |
| 401 | `unauthorized` | Jeton absent, expiré ou révoqué → état « déconnecté » (garder les données locales). |
| 403 | `forbidden` | Action interdite pour ce compte. |
| 403 | `quota_exceeded` | Trop de lignes de sauvegarde pour ce compte (§5.4). |
| 404 | `not_found` | Ligne absente (sauvegarde distante supprimée entre-temps : traiter comme « rien à tirer »). |
| 409 | `rev_conflict` | Écriture conditionnelle refusée : la ligne distante a changé (`data.current` = méta distante, §5.3). |
| 413 | `payload_too_large` | Charge utile > 256 Kio ou corps > 320 Kio. |
| 422 | `score_implausible` | Score de Garde rejeté (`data.reasons`, §6.2). Ne pas réessayer ; garder le record local. |
| 429 | `rate_limited` | Trop de requêtes ; `data.retry_after_s` (secondes). Réessayer après ce délai. PocketBase natif : `429` sans `code`. |
| 5xx | — | Serveur indisponible → état « hors ligne », réessayer plus tard. |

### 1.2 En-têtes, CORS et Web (COEP)

- **Toutes** les réponses portent `Cross-Origin-Resource-Policy: cross-origin` : la page `/play/` est servie en `Cross-Origin-Embedder-Policy: require-corp` (`docs/WEB.md` §7) et doit pouvoir lire les réponses de l'API.
- **CORS** : origines autorisées = variable `CLEARANCE_ORIGINS` du serveur (défaut : `https://clearance.cardormedia.com,https://www.clearance.cardormedia.com`). PocketBase répond aux pré-vols `OPTIONS` (`Access-Control-Allow-Headers` reprend les en-têtes demandés, dont `Authorization` et `Content-Type` ; méthodes `GET, HEAD, PUT, PATCH, POST, DELETE`). Pas de cookies : le client Web appelle `fetch` **sans** `credentials`.
- **Clients natifs** (PC, Steam Deck) : `HTTPRequest` n'envoie pas d'`Origin` ⇒ CORS sans objet ; aucune restriction.
- **`Origin: null`** (fichier local, iframe isolée) : **non autorisée** par défaut (M16 §2 l'évoquait) — aucun client du jeu n'en émet ; l'ajouter à `CLEARANCE_ORIGINS` reviendrait à ouvrir l'API à toute page. L'authentification passe par un en-tête (pas de cookie) : CORS n'est pas une barrière de sécurité ici, seulement une hygiène.
- **Lot W** : la CSP de `/play/` (`site/nginx.conf`) doit ajouter l'API à `connect-src` : `connect-src 'self' blob: data: https://api.clearance.cardormedia.com`. Sans cela, le navigateur bloque les appels même si CORS/CORP sont corrects.
- Le serveur ajoute aussi, par défaut (PocketBase), `X-Content-Type-Options: nosniff`, `X-Frame-Options: SAMEORIGIN`, `Cross-Origin-Opener-Policy: same-origin` (sans effet sur un appel `fetch`).

### 1.3 État du serveur

`GET /api/clearance/status` — public, sans authentification. Sert de test de joignabilité et d'horloge (graine du jour en UTC).

```json
{
  "api_version": 1,
  "server": "clearance-pb",
  "time_unix_ms": 1793498425123,
  "limits": {
    "payload_max_bytes": 262144,
    "body_max_bytes": 327680,
    "save_rows_max": 240,
    "pseudo_max_chars": 20
  },
  "garde_versions": [1, 2],
  "otp": { "length": 6, "duration_s": 600 },
  "token_duration_s": 2592000
}
```

`GET /api/health` (PocketBase) → `200 {"message":"API is healthy.","code":200,"data":{}}` (sonde Coolify).

---

## 2. Compte et authentification (OTP par e-mail, D-231)

Compte **sans mot de passe** : un code à **6 chiffres**, valable **10 minutes**, envoyé par e-mail. Le compte est **créé automatiquement** à la première demande de code pour une adresse inconnue (aucun formulaire d'inscription). Collection PocketBase : `users` (authentification par mot de passe et OAuth **désactivées**).

### 2.1 Demander un code

`POST /api/collections/users/request-otp`

```json
{ "email": "agent@example.org" }
```

→ `200 {"otpId": "8fz6g3kq2x1m0cd"}`

- Toujours `200` pour une adresse valide, qu'elle soit connue ou non (le compte est créé au besoin) — **même si l'envoi de l'e-mail échoue** côté serveur (échec journalisé seulement) : l'UI propose « Renvoyer le code » après ~60 s.
- `400` : adresse invalide (`data.email.code`). `429` : trop de demandes (par IP, §8).
- Le client garde `otpId` en mémoire (pas sur disque) jusqu'à la saisie du code ; une nouvelle demande produit un nouvel `otpId` (l'ancien code reste valable jusqu'à expiration).

### 2.2 Échanger le code contre un jeton

`POST /api/collections/users/auth-with-otp`

```json
{ "otpId": "8fz6g3kq2x1m0cd", "password": "042317" }
```

→ `200`

```json
{
  "token": "eyJhbGciOi…",
  "record": {
    "collectionId": "_pb_users_auth_", "collectionName": "users",
    "id": "k3p9x7q2m1n4b8c", "email": "agent@example.org", "emailVisibility": false, "verified": true,
    "pseudo": "", "tag": "B8C0", "created": "2026-11-01 02:00:25.123Z", "updated": "2026-11-01 02:00:25.123Z"
  }
}
```

- `400` (message PocketBase, sans `code`) : code faux, expiré ou déjà utilisé. Après **5 échecs** sur le même `otpId`, il est verrouillé : `429` avec `code` `otp_locked` (même si le 6ᵉ essai est juste) → redemander un code.
- `password` = le code saisi (chiffres seulement ; le client retire espaces et tirets).
- **Le client ne journalise jamais** l'e-mail ni le jeton. Il stocke localement : le jeton, `record.id`, `pseudo`, `tag` (et l'e-mail seulement si l'UI doit l'afficher dans Options › Compte, jamais dans `user://logs`).

### 2.3 Rafraîchir le jeton

`POST /api/collections/users/auth-refresh` (en-tête `Authorization`), corps vide → `200 {token, record}` (même forme qu'en §2.2).

- Durée d'un jeton : **30 jours** (`token_duration_s`). Le client rafraîchit au démarrage (si en ligne) et dès que le jeton a plus de 24 h ; il remplace le jeton stocké par le nouveau.
- `401` : jeton expiré ou révoqué → déconnecté (redemander un code).

### 2.4 Profil public et pseudo

`GET /api/clearance/me` (auth) →

```json
{ "id": "k3p9x7q2m1n4b8c", "pseudo": "Nadia", "tag": "B8C0", "created": "2026-11-01 02:00:25.123Z",
  "counts": { "saves": 34, "garde_scores": 5, "ending_events": 2 } }
```

`PATCH /api/collections/users/records/{id}` (auth, seulement son propre `id`) :

```json
{ "pseudo": "Nadia" }
```

→ `200` record (forme §2.2).

- **Seul `pseudo` est modifiable** ; tout autre champ (`email`, `password`, `verified`, `emailVisibility`, `tag`…) ⇒ `400` (`data.<champ>.code = "not_editable"`).
- `pseudo` : 0 à 20 caractères après suppression des espaces de bord ; lettres (toutes écritures), chiffres, espace, `_ . ' -`. Vide = anonyme. Pas d'unicité (le `tag` départage).
- **Nom affiché** (classement) : `pseudo` s'il n'est pas vide, sinon le client compose « Agent·e #`tag` » (FR) / « Agent #`tag` » (EN). `tag` = 4 caractères de l'alphabet des N° ID (`A–Z` et `2–9` sans `O`, `I`, `0`, `1`), tiré au hasard à la création, non modifiable.

### 2.5 Déconnexion

- **Déconnexion de cet appareil** : purement locale (le client oublie le jeton). Aucun appel.
- **Déconnecter tous les appareils** : `POST /api/clearance/logout-all` (auth) → `204`. Tous les jetons émis deviennent invalides (`401`), y compris celui de l'appelant.

### 2.6 Supprimer le compte et toutes ses données (RGPD)

`DELETE /api/collections/users/records/{id}` (auth, son propre `id`) → `204`.

- Supprime le compte, **toutes** ses sauvegardes, ses scores de Garde et ses événements de fin (suppression en cascade + nettoyage serveur), ses codes OTP en attente. Irréversible. Le cache des agrégats de fins est invalidé.
- Le client confirme deux fois, puis oublie le jeton. Les **données locales ne sont pas touchées**.
- `401`/`403` : jeton invalide ou autre `id`.

---

## 3. Collections (schémas)

Toutes les collections ont les champs système PocketBase `id` (15 caractères `[a-z0-9]`), `created`, `updated`. **Règles d'accès** : un joueur ne **lit** que ses propres lignes via l'API standard (`GET /api/collections/<nom>/records`, filtre automatique `user = @request.auth.id`) ; **aucune écriture** par l'API standard (création/modification/suppression = routes `/api/clearance/*` ou suppression du compte). Lecture publique **uniquement** via les routes d'agrégats (§6.3, §7.2). Les superadmins voient tout (console `/_/`).

### 3.1 `users` (authentification)

| Champ | Type | Notes |
|---|---|---|
| `email` | e-mail, unique | jamais renvoyé à un autre utilisateur (`emailVisibility = false`) |
| `verified` | bool | `true` après la première connexion par code |
| `pseudo` | texte 0–20 | public (classement) |
| `tag` | texte 4 car. (alphabet des N° ID) | public, fixé à la création |

Règles : lecture/modification/suppression de soi seulement ; création **uniquement** par la demande de code (§2.1).

### 3.2 `saves` (sauvegardes, D-232)

| Champ | Type | Contraintes |
|---|---|---|
| `user` | relation `users` | requis, cascade à la suppression du compte |
| `slot` | entier | 0–3 ; **0 = profil**, 1–3 = emplacements (`SaveService.SLOT_COUNT`) |
| `kind` | texte | `current`, `meta`, `snapshot`, `profile`, et leurs variantes démo `demo_current`, `demo_meta`, `demo_snapshot`, `demo_profile` |
| `day` | entier | 1–31 pour `snapshot` (`day_NN.json`, 31 = graine d'épilogue `day_31.json`) ; **0** pour tous les autres `kind` |
| `payload` | JSON objet | le contenu exact du fichier local (`current.json`, `meta.json`, `day_NN.json`, `profile.json`) ; ≤ **256 Kio** sérialisé |
| `game_version` | texte ≤ 32 | `application/config/version` de l'appareil émetteur |
| `save_serial` | entier ≥ 0 | recopié de `meta.json` (`save_serial`) ou 0 |
| `saved_unix_ms` | entier ≥ 0 | horodatage local de l'écriture (`meta.saved_unix_ms` ; profil : instant d'écriture) |
| `device` | texte ≤ 32 | libellé court (`"PC"`, `"Deck"`, `"Web"`, `"Linux"`…) |
| `rev` | entier ≥ 1 | **serveur** : 1 à la création, +1 à chaque écriture (concurrence optimiste, §5.3) |
| `size` | entier | **serveur** : taille en octets de `payload` sérialisé |

- **Unicité** : (`user`, `slot`, `kind`, `day`). Une écriture **remplace** la ligne existante.
- **Cohérence** imposée : `profile`/`demo_profile` ⇒ `slot = 0`, `day = 0` ; `current`/`meta` (et `demo_`) ⇒ `slot` 1–3, `day = 0` ; `snapshot`/`demo_snapshot` ⇒ `slot` 1–3, `day` 1–31.
- Démo : le serveur **accepte** les `kind` préfixés `demo_` (familles séparées : `family=demo`). Le choix de synchroniser ou non la démo appartient au lot C (M16 §3) ; les deux familles ne se mélangent jamais côté serveur.

### 3.3 `garde_scores` (classement, D-233)

| Champ | Type | Contraintes |
|---|---|---|
| `user` | relation `users` | cascade |
| `seed_code` | texte | canonique : `NUIT-AAAA-MM-JJ` (graine du jour) ou `XXX-XXX` (code libre, alphabet `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`) |
| `kind` | texte | **serveur** : `daily` ou `free` (déduit du code) |
| `garde_version` | entier 1–1000 | `GardeDef.version` (actuellement **2**) |
| `score` | entier ≥ 0 | |
| `errors` | entier 0–3 | erreurs (citations) de la garde |
| `tier_max` | entier 0–4 | palier atteint (`GardeRun.tier_index`, « palier ») |
| `passengers` | entier 0–400 | passagers traités |
| `directives` | entier ≥ 0 | directives tirées |
| `duration_s` | entier 0–86400 | durée réelle de la garde |
| `first_try` | bool | la garde était le premier essai du joueur sur cette graine |
| `end_reason` | texte | `errors` \| `quit` \| `""` |
| `game_version` | texte ≤ 32 | |
| `attempts` | entier ≥ 1 | **serveur** : envois acceptés pour (`user`, `seed_code`, `garde_version`) |

- **Unicité** : (`user`, `seed_code`, `garde_version`) — la ligne garde le **meilleur** essai.
- Index de classement : (`seed_code`, `garde_version`, `score`).

### 3.4 `ending_events` (statistiques des fins, D-234)

| Champ | Type | Contraintes |
|---|---|---|
| `user` | relation `users` | cascade |
| `ending_id` | texte | une des 10 fins : `f1_arrested`, `f2_reassigned`, `f3_family_lost`, `f4_glory`, `f5_air`, `f6_drift`, `f7_reopens`, `f8_registre`, `f9_strike`, `f10_pont` (`EndingService.ALL_ENDINGS`) |
| `variant` | texte 0–16 `[a-z0-9_]` | `EpilogueService.variant_of` (`""`, `audit`, `review`, `deposition`, `double`, `c`, `s`, `b`, `j10`, `j20`, `t`, `d`…) |
| `act` | entier 1–3 | |
| `difficulty` | texte | `hard` \| `story` |
| `game_version` | texte ≤ 32 | |

- **Unicité** : (`user`, `ending_id`, `variant`) — un seul événement par fin et variante et par joueur (rejouer la même fin ne compte pas deux fois).

---

## 4. Correspondance avec les fichiers locaux

| Fichier local (`user://saves/…`) | `slot` | `kind` | `day` |
|---|---|---|---|
| `slot_N/current.json` | N | `current` | 0 |
| `slot_N/meta.json` | N | `meta` | 0 |
| `slot_N/day_NN.json` | N | `snapshot` | NN |
| `profile.json` | 0 | `profile` | 0 |
| démo : `user://demo/saves/…` | idem | `demo_…` | idem |

Les `.tmp`/`.bak`, `slot_0.v5.bak`, `profile.v1.bak` et `conflict_*` ne sont **jamais** envoyés.

---

## 5. Sauvegardes — routes

Toutes exigent l'authentification. `{slot}`, `{kind}`, `{day}` : voir §3.2.

### 5.1 Manifeste (sans les charges utiles)

`GET /api/clearance/saves?family=game` (`family` = `game` (défaut) | `demo` | `all`) →

```json
{
  "items": [
    { "id": "q8w1…", "slot": 1, "kind": "meta", "day": 0, "rev": 7, "save_serial": 12, "saved_unix_ms": 1793498425123,
      "game_version": "1.1.0", "device": "Deck", "size": 412, "updated": "2026-11-01 02:00:25.123Z", "updated_unix_ms": 1793498425130 }
  ],
  "rows": 34,
  "rows_max": 240
}
```

Trié par `slot`, `kind`, `day`. C'est l'appel du tirage à l'écran titre : le client compare chaque emplacement (`meta` : `save_serial` puis `saved_unix_ms`, D-232) avant de télécharger quoi que ce soit.

### 5.2 Lire une ligne

`GET /api/clearance/saves/{slot}/{kind}/{day}` → `200` objet du manifeste **+ `"payload": {…}`** ; `404 not_found` si absente.

### 5.3 Écrire (créer ou remplacer)

`PUT /api/clearance/saves/{slot}/{kind}/{day}`

```json
{
  "payload": { "version": 6, "current_day": 12, "…": "…" },
  "game_version": "1.1.0",
  "save_serial": 12,
  "saved_unix_ms": 1793498425123,
  "device": "Deck",
  "if_rev": 7
}
```

→ `201` (créée) ou `200` (remplacée) : objet du manifeste (sans `payload`), avec le nouveau `rev`.

- `if_rev` (facultatif) — **écriture conditionnelle** :
  - absent ou `null` : écrase sans condition ;
  - `0` : n'écrit que si la ligne **n'existe pas** ;
  - `n > 0` : n'écrit que si le `rev` distant vaut `n`.
  - Sinon `409 rev_conflict`, `data.current` = l'objet du manifeste distant (ou `null` s'il n'existe pas). Le client tire alors la version distante et applique la règle de conflit D-232 (copie `slot_N/conflict_<horodatage>/`, choix à l'écran Charger).
- Le client envoie un emplacement dans cet ordre : `snapshot` du jour, `current`, puis `meta` **en dernier** (la méta sert de témoin : si elle est à jour, l'emplacement l'est). Les instantanés postérieurs supprimés localement sont supprimés à distance (§5.4).
- `400 invalid_field` (cohérence `slot`/`kind`/`day`, champ hors bornes, `payload` absent ou non objet), `413 payload_too_large`, `403 quota_exceeded`, `429 rate_limited`.

### 5.4 Supprimer

- `DELETE /api/clearance/saves/{slot}/{kind}/{day}` → `200 {"deleted": 0|1}` (idempotent).
- `DELETE /api/clearance/saves/{slot}?family=game` → `200 {"deleted": n}` : toutes les lignes de l'emplacement dans la famille (`slot = 0` : le profil). Utilisé quand le joueur supprime ou écrase un emplacement.
- **Quota** : 240 lignes par compte (2 familles × (3 emplacements × (2 + 31) + 1) = 200, plus de la marge). Au-delà : `403 quota_exceeded` (le client doit supprimer les instantanés distants obsolètes).

### 5.5 Profil

Le profil (`slot 0`, `kind profile`) se synchronise par les mêmes routes. **Fusion côté client** (union, D-232) : tirer → fusionner localement → réécrire avec `if_rev` = `rev` tiré ; sur `409`, recommencer (au plus 3 fois). Le serveur ne fusionne pas.

---

## 6. Garde de nuit — classement (D-233)

### 6.1 Envoyer un score

`POST /api/clearance/garde/scores` (auth), à la fin d'une garde (ou plus tard, hors ligne d'abord) :

```json
{
  "seed_code": "NUIT-2026-11-01",
  "garde_version": 2,
  "score": 57,
  "errors": 3,
  "tier_max": 2,
  "passengers": 58,
  "directives": 11,
  "duration_s": 1430,
  "first_try": true,
  "end_reason": "errors",
  "game_version": "1.1.0"
}
```

Correspondance avec `GardeRun.to_record()` : `score`, `seed_code`, `garde_version`, `passengers`, `directives`, `end_reason` identiques ; `duration_sec` → `duration_s` ; `palier` → `tier_max` ; `errors` = **nombre** d'éléments du tableau `errors` ; `first_try` = résultat de `ProfileService.record_garde` (`first_try`).

→ `200`

```json
{
  "improved": true,
  "best": { "seed_code": "NUIT-2026-11-01", "garde_version": 2, "score": 57, "errors": 3, "tier_max": 2,
            "passengers": 58, "duration_s": 1430, "first_try": true, "attempts": 2, "updated": "…" },
  "rank": 4,
  "total": 131
}
```

- **Meilleur essai** par (`user`, `seed_code`, `garde_version`) : un essai remplace le meilleur s'il a un **score plus haut** ; à score égal, **moins d'erreurs** ; puis **durée plus courte**. Sinon `improved: false` et `best` = l'ancien meilleur (l'envoi compte quand même dans `attempts`).
- `seed_code` : le serveur accepte la casse, les espaces et l'absence de tiret d'un code libre, puis le canonise. Une graine du jour **dans le futur** (date > aujourd'hui UTC + 1 jour) ou antérieure au 2026-01-01 est refusée (`400 invalid_field`, `seed_code`). Une graine du jour passée est acceptée (envoi différé hors ligne).
- `rank`/`total` : rang (compétition « 1224 », au score seul) et nombre de joueurs du classement de cette graine et version.

### 6.2 Plausibilité (amicale, sans anti-triche cryptographique)

Le serveur refuse (`422 score_implausible`, `data.reasons` = liste) un envoi qui viole l'une de ces bornes, paramétrées par `garde_version` (table `GARDE_RULES` de `server/pb_hooks/clearance_lib.js` ; version inconnue ⇒ dernière table connue) :

| Raison | Règle (version 2) |
|---|---|
| `errors_above_max` | `errors ≤ 3` (`GardeDef.max_errors`) |
| `errors_above_passengers` | `errors ≤ passengers` |
| `passengers_above_max` | `passengers ≤ 400` (file maximale) |
| `score_below_correct` | `score ≥ passengers − errors` (chaque verdict juste rapporte au moins 1) |
| `score_above_max` | `score ≤ 2 × (passengers − errors)` (au plus +1 de bonus par verdict juste pendant une inspection EV-04) |
| `too_fast` | `duration_s ≥ 2 × passengers` (au moins 2 s par passager) |
| `tier_above_passengers` | `tier_max ≤` palier du passager `passengers + 1` (paliers à 1, 21, 41, 61, 101) |
| `directives_above_passengers` | `directives ≤ floor(passengers / 5)` |

**Fréquence** (par compte) : au plus **1 envoi toutes les 15 s** et **30 par heure** → `429 rate_limited` (`data.retry_after_s`). Le client garde l'envoi en file et le réessaie plus tard.

### 6.3 Classement

`GET /api/clearance/leaderboard?seed=NUIT-2026-11-01&version=2&limit=10` — public ; si l'en-tête `Authorization` est présent et valide, la réponse inclut le joueur.

- `seed` : requis (même normalisation qu'en §6.1). `version` : facultatif (défaut : la plus haute `garde_version` ayant des scores pour cette graine ; le client envoie **toujours** sa `GardeDef.version`). `limit` : 1–50, défaut 10.

```json
{
  "seed_code": "NUIT-2026-11-01",
  "garde_version": 2,
  "total": 131,
  "entries": [
    { "rank": 1, "pseudo": "Nadia", "tag": "B8C0", "score": 112, "errors": 2, "tier_max": 4, "passengers": 110,
      "duration_s": 3020, "first_try": false, "is_me": false },
    { "rank": 2, "pseudo": "", "tag": "7QK2", "score": 98, "errors": 3, "tier_max": 3, "passengers": 99,
      "duration_s": 2711, "first_try": true, "is_me": true }
  ],
  "me": { "rank": 2, "pseudo": "", "tag": "7QK2", "score": 98, "errors": 3, "tier_max": 3, "passengers": 99,
          "duration_s": 2711, "first_try": true, "is_me": true }
}
```

- Ordre : score décroissant, puis erreurs croissantes, durée croissante, ancienneté. Rang = 1 + nombre de joueurs au **score strictement supérieur** (ex aequo = même rang).
- `me` : `null` si non connecté ou sans score sur cette graine/version ; présent même hors du top N.
- Graine sans aucun score : `200` avec `total: 0`, `entries: []`.
- Jamais d'e-mail ni d'`id` utilisateur dans la réponse.

---

## 7. Statistiques des fins (D-234)

### 7.1 Envoyer une fin obtenue

`POST /api/clearance/endings` (auth), à l'obtention d'une fin F1–F10 (et, en rattrapage, pour chaque fin du profil local jamais envoyée) :

```json
{ "ending_id": "f5_air", "variant": "b", "act": 3, "difficulty": "hard", "game_version": "1.1.0" }
```

→ `201 {"created": true}` la première fois, `200 {"created": false}` ensuite (idempotent par (`user`, `ending_id`, `variant`)).

- `400 invalid_field` : fin inconnue, variante mal formée, `act` hors 1–3, `difficulty` inconnue. Fréquence : 60 envois par heure et par compte (`429`).

### 7.2 Agrégats publics

`GET /api/clearance/endings` (public) ou `GET /api/clearance/endings?ids=f1_arrested,f5_air` (seulement ces fins : le client peut ne demander que les fins **déjà vues** — aucun spoiler) →

```json
{
  "players": 1284,
  "generated_unix_ms": 1793498425123,
  "max_age_s": 300,
  "endings": {
    "f1_arrested": { "players": 211, "percent": 16.4, "variants": { "audit": { "players": 80, "percent": 6.2 }, "double": { "players": 140, "percent": 10.9 } } },
    "f5_air": { "players": 402, "percent": 31.3, "variants": { "b": { "players": 97, "percent": 7.6 } } }
  }
}
```

- `players` = nombre de comptes ayant au moins un événement de fin (« agents ayant terminé au moins une partie ») ; `percent` = joueurs ayant cette fin (toutes variantes) ÷ `players` × 100, arrondi à 0,1. Une fin sans joueur apparaît avec `players: 0, percent: 0` si elle est demandée par `ids` (sinon absente).
- **Cache serveur** de 300 s (`max_age_s`) ; en-tête `Cache-Control: public, max-age=300`. Le client garde aussi un cache local et n'affiche « X % des agents » **que pour les fins vues** (D-234).

---

## 8. Limites

| Limite | Valeur | Réponse |
|---|---|---|
| `payload` d'une sauvegarde | 256 Kio (262 144 octets, JSON sérialisé) | `413 payload_too_large` |
| Corps d'une requête `/api/clearance/*` | 320 Kio | `413` |
| Lignes de sauvegarde par compte | 240 | `403 quota_exceeded` |
| Écritures de sauvegarde (`PUT`/`DELETE`) | 120 par 10 min et par compte | `429 rate_limited` |
| Envois de score de Garde | 1 / 15 s et 30 / h par compte | `429 rate_limited` |
| Envois de fin | 60 / h par compte | `429 rate_limited` |
| Demandes de code OTP | 5 / 10 min par IP (`CLEARANCE_OTP_PER_10MIN`) | `429` (PocketBase) |
| Échanges de code OTP | 10 / 10 min par IP ; 5 échecs par `otpId` | `429` (PocketBase) / `429 otp_locked` |
| Toutes routes `/api/` | 300 / 10 s par IP | `429` (PocketBase) |
| `pseudo` | 20 caractères | `400` |

Les limites par IP reposent sur l'IP réelle transmise par le proxy (`CLEARANCE_TRUSTED_PROXY_HEADERS`, défaut `CF-Connecting-IP,X-Forwarded-For`, voir `server/README.md`).

---

## 9. Données personnelles (résumé, texte complet dans `server/README.md`)

Données conservées : adresse e-mail (connexion uniquement, jamais publiée), pseudo et tag (publics au classement), sauvegardes, scores de Garde, fins obtenues (agrégées anonymement). Pas de télémétrie, pas de publicité, pas de tiers hormis l'envoi des e-mails (SMTP). Journaux techniques du serveur : 7 jours. Suppression complète et immédiate depuis le jeu (§2.6).

---

## 10. Développement et tests

- `tools/online_dev_server.sh` : PocketBase local (`http://127.0.0.1:8090`), migrations et crochets du dépôt, superadmin de test `dev@clearance.local` avec mot de passe aléatoire (`CLEARANCE_DEV_SUPERUSER_PASSWORD` ou `<data>/.dev_superuser`, local uniquement), SMTP désactivé, **mode dev OTP** (`CLEARANCE_DEV_OTP=1`).
- **Mode dev OTP** (jamais en production : le crochet `server/dev_hooks/dev_otp.pb.js` n'est pas dans l'image Docker et exige en plus la variable) :
  - aucun e-mail n'est envoyé ; le code est écrit dans le journal du serveur (`[dev-otp] <otpId> <code>`) ;
  - `GET /api/clearance/dev/otp?otpId=<otpId>` → `200 {"otpId": "…", "code": "042317"}` (404 hors mode dev) : utilisé par les tests d'intégration du lot C contre un PocketBase local.
- `tools/test_online_server.sh` : lance le serveur local et vérifie tout le contrat (OTP, règles d'accès, sauvegardes, plausibilité, classement, fins, suppression, CORS/en-têtes).

---

## 11. Récapitulatif des routes

| Méthode | Chemin | Auth | Section |
|---|---|---|---|
| GET | `/api/health` | — | 1.3 |
| GET | `/api/clearance/status` | — | 1.3 |
| POST | `/api/collections/users/request-otp` | — | 2.1 |
| POST | `/api/collections/users/auth-with-otp` | — | 2.2 |
| POST | `/api/collections/users/auth-refresh` | ✔ | 2.3 |
| GET | `/api/clearance/me` | ✔ | 2.4 |
| PATCH | `/api/collections/users/records/{id}` | ✔ (soi) | 2.4 |
| POST | `/api/clearance/logout-all` | ✔ | 2.5 |
| DELETE | `/api/collections/users/records/{id}` | ✔ (soi) | 2.6 |
| GET | `/api/clearance/saves` | ✔ | 5.1 |
| GET | `/api/clearance/saves/{slot}/{kind}/{day}` | ✔ | 5.2 |
| PUT | `/api/clearance/saves/{slot}/{kind}/{day}` | ✔ | 5.3 |
| DELETE | `/api/clearance/saves/{slot}/{kind}/{day}` | ✔ | 5.4 |
| DELETE | `/api/clearance/saves/{slot}` | ✔ | 5.4 |
| POST | `/api/clearance/garde/scores` | ✔ | 6.1 |
| GET | `/api/clearance/leaderboard` | facultative | 6.3 |
| POST | `/api/clearance/endings` | ✔ | 7.1 |
| GET | `/api/clearance/endings` | — | 7.2 |
| GET | `/api/clearance/dev/otp` | — (dev seulement) | 10 |

Lecture standard de ses propres lignes (facultatif, le client n'en a pas besoin) : `GET /api/collections/{saves|garde_scores|ending_events}/records`.

---

## 12. Propositions de décisions (lot S → Orchestrateur, numéros à attribuer)

- **S-1** — PocketBase **0.40.6** figé (sha256 vérifié dans le `Dockerfile`) ; 0.40.6 annonce être la dernière version publiée sur GitHub : toute mise à jour future passe par une revue (nouvelle source de téléchargement, notes de version, tests `tools/test_online_server.sh`).
- **S-2** — Écritures uniquement par routes `/api/clearance/*` (validation centralisée, upsert, `rev` de concurrence optimiste) ; API standard PocketBase en lecture seule de ses propres lignes.
- **S-3** — Classement : meilleur essai par (joueur, graine, `garde_version`), départage score → erreurs → durée ; plausibilité par table versionnée ; classements séparés par `garde_version`.
- **S-4** — Compte créé à la première demande de code ; `tag` public de 4 caractères ; jetons de 30 jours ; « déconnecter tous les appareils » par rotation de la clé de jeton.
- **S-5** — Mode dev OTP hors de l'image de production (dossier `server/dev_hooks/`) et conditionné à `CLEARANCE_DEV_OTP=1`.
