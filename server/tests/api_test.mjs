// CLEARANCE M16 — tests d'intégration du serveur (docs/ONLINE.md).
// Lancé par tools/test_online_server.sh contre un PocketBase local en mode dev :
//   node server/tests/api_test.mjs http://127.0.0.1:PORT
// Variables attendues côté serveur : CLEARANCE_DEV_OTP=1, CLEARANCE_ENDINGS_CACHE_S=2,
// CLEARANCE_GARDE_MIN_INTERVAL_S=1, CLEARANCE_OTP_PER_10MIN=12.
// Aucune dépendance (Node ≥ 18 : fetch).

const BASE = process.argv[2] || "http://127.0.0.1:8090"
const SITE = "https://clearance.cardormedia.com"
const SUPERUSER = { identity: "dev@clearance.local", password: process.env.CLEARANCE_DEV_SUPERUSER_PASSWORD || "" }
if (!SUPERUSER.password) { console.error("CLEARANCE_DEV_SUPERUSER_PASSWORD manquant (lancer via tools/test_online_server.sh)"); process.exit(2) }

let passed = 0
let failed = 0
const failures = []

function check(cond, label, detail) {
  if (cond) {
    passed++
    console.log("  ok   " + label)
  } else {
    failed++
    failures.push(label)
    console.log("  FAIL " + label + (detail !== undefined ? "  → " + JSON.stringify(detail).slice(0, 400) : ""))
  }
}

function section(name) {
  console.log("\n# " + name)
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms))

async function api(method, path, { token, body, headers } = {}) {
  const h = Object.assign({}, headers || {})
  if (token) h["Authorization"] = token
  let payload
  if (body !== undefined) {
    h["Content-Type"] = "application/json"
    payload = typeof body === "string" ? body : JSON.stringify(body)
  }
  const res = await fetch(BASE + path, { method, headers: h, body: payload })
  const text = await res.text()
  let json = null
  try {
    json = text ? JSON.parse(text) : null
  } catch (_) {
    json = null
  }
  return { status: res.status, json, text, headers: res.headers }
}

async function otpCode(otpId) {
  for (let i = 0; i < 40; i++) {
    const r = await api("GET", "/api/clearance/dev/otp?otpId=" + encodeURIComponent(otpId))
    if (r.status === 200) return r.json.code
    await sleep(100)
  }
  return null
}

// Connexion OTP complète ; renvoie {token, id, record, email}.
async function login(email) {
  const req = await api("POST", "/api/collections/users/request-otp", { body: { email } })
  if (req.status !== 200) throw new Error("request-otp " + req.status + " " + req.text)
  const code = await otpCode(req.json.otpId)
  const auth = await api("POST", "/api/collections/users/auth-with-otp", { body: { otpId: req.json.otpId, password: code } })
  if (auth.status !== 200) throw new Error("auth-with-otp " + auth.status + " " + auth.text)
  return { token: auth.json.token, id: auth.json.record.id, record: auth.json.record, email }
}

async function superToken() {
  for (let i = 0; i < 5; i++) {
    const r = await api("POST", "/api/collections/_superusers/auth-with-password", { body: SUPERUSER })
    if (r.status === 200) return r.json.token
    await sleep(1600)
  }
  throw new Error("superuser auth failed")
}

const run = (over = {}) => Object.assign({
  seed_code: "NUIT-2026-10-30", garde_version: 2, score: 40, errors: 1, tier_max: 2, passengers: 40,
  directives: 8, duration_s: 900, first_try: true, end_reason: "quit", game_version: "1.1.0",
}, over)

async function main() {
  // ---------------------------------------------------------------------------------------
  section("Statut, en-têtes, CORS")
  {
    const r = await api("GET", "/api/clearance/status")
    check(r.status === 200 && r.json.api_version === 1, "status 200, api_version 1", r.json)
    check(r.json && r.json.otp.length === 6 && r.json.otp.duration_s === 600, "OTP 6 chiffres, 10 min", r.json && r.json.otp)
    check(r.json && r.json.token_duration_s === 2592000, "jeton 30 jours")
    check(r.headers.get("cross-origin-resource-policy") === "cross-origin", "CORP cross-origin sur /status")
    const h = await api("GET", "/api/health")
    check(h.status === 200 && h.headers.get("cross-origin-resource-policy") === "cross-origin", "CORP sur /api/health")
    const nf = await api("GET", "/api/clearance/saves")
    check(nf.status === 401 && nf.json.code === "unauthorized", "401 unauthorized sans jeton", nf.json)
    check(nf.headers.get("cross-origin-resource-policy") === "cross-origin", "CORP aussi sur une erreur")

    const pre = await fetch(BASE + "/api/clearance/saves", {
      method: "OPTIONS",
      headers: { Origin: SITE, "Access-Control-Request-Method": "PUT", "Access-Control-Request-Headers": "authorization,content-type" },
    })
    check(pre.status === 204 || pre.status === 200, "pré-vol OPTIONS accepté", pre.status)
    check(pre.headers.get("access-control-allow-origin") === SITE, "ACAO = origine du site", pre.headers.get("access-control-allow-origin"))
    const allowH = (pre.headers.get("access-control-allow-headers") || "").toLowerCase()
    check(allowH.includes("authorization") && allowH.includes("content-type"), "Allow-Headers inclut Authorization et Content-Type", allowH)
    check(pre.headers.get("cross-origin-resource-policy") === "cross-origin", "CORP sur le pré-vol")

    const g = await api("GET", "/api/clearance/status", { headers: { Origin: SITE } })
    check(g.headers.get("access-control-allow-origin") === SITE, "GET avec Origin du site : ACAO")
    const evil = await api("GET", "/api/clearance/status", { headers: { Origin: "https://evil.example" } })
    check(!evil.headers.get("access-control-allow-origin"), "origine inconnue : pas d'ACAO", evil.headers.get("access-control-allow-origin"))
    check(evil.status === 200, "client natif / origine inconnue : la requête elle-même aboutit")
  }

  // ---------------------------------------------------------------------------------------
  section("OTP de bout en bout")
  const emailA = "agent.a." + Date.now() + "@example.org"
  let A
  {
    const bad = await api("POST", "/api/collections/users/request-otp", { body: { email: "pas-une-adresse" } })
    check(bad.status === 400, "request-otp : adresse invalide → 400", bad.json)

    const req = await api("POST", "/api/collections/users/request-otp", { body: { email: emailA } })
    check(req.status === 200 && typeof req.json.otpId === "string", "request-otp (nouvelle adresse) → otpId", req.json)
    const code = await otpCode(req.json.otpId)
    check(/^\d{6}$/.test(code || ""), "mode dev : code à 6 chiffres lisible", code)
    const wrong = await api("POST", "/api/collections/users/auth-with-otp", {
      body: { otpId: req.json.otpId, password: code === "000000" ? "111111" : "000000" },
    })
    check(wrong.status === 400, "code faux → 400", wrong.json)
    const ok = await api("POST", "/api/collections/users/auth-with-otp", { body: { otpId: req.json.otpId, password: code } })
    check(ok.status === 200 && typeof ok.json.token === "string", "auth-with-otp → jeton", ok.json)
    const rec = ok.json.record
    check(rec && /^[A-Z2-9]{4}$/.test(rec.tag) && rec.pseudo === "", "record : tag 4 car., pseudo vide", rec)
    check(rec && rec.verified === true, "adresse vérifiée après connexion")
    check(rec && rec.name === undefined && rec.avatar === undefined, "pas de champs name/avatar")
    A = { token: ok.json.token, id: rec.id, record: rec, email: emailA }

    const reused = await api("POST", "/api/collections/users/auth-with-otp", { body: { otpId: req.json.otpId, password: code } })
    check(reused.status === 400, "code déjà utilisé → 400", reused.status)

    const refresh = await api("POST", "/api/collections/users/auth-refresh", { token: A.token })
    check(refresh.status === 200 && refresh.json.token && refresh.json.record.id === A.id, "auth-refresh → nouveau jeton")
    A.token = refresh.json.token
    const bearer = await api("GET", "/api/clearance/me", { token: "Bearer " + A.token })
    check(bearer.status === 200 && bearer.json.id === A.id, "préfixe Bearer accepté")

    const again = await login(emailA)
    check(again.id === A.id, "nouvelle connexion avec la même adresse → même compte")

    const pw = await api("POST", "/api/collections/users/auth-with-password", { body: { identity: emailA, password: "x".repeat(12) } })
    check(pw.status === 400 || pw.status === 403 || pw.status === 404, "authentification par mot de passe désactivée", pw.status)
    const signup = await api("POST", "/api/collections/users/records", {
      body: { email: "direct@example.org", password: "abcdefgh12", passwordConfirm: "abcdefgh12" },
    })
    check(signup.status === 400 || signup.status === 403, "inscription directe refusée", signup.status)
  }

  section("OTP : verrouillage après 5 échecs")
  {
    const emailL = "agent.lock." + Date.now() + "@example.org"
    const req = await api("POST", "/api/collections/users/request-otp", { body: { email: emailL } })
    const code = await otpCode(req.json.otpId)
    const wrongCode = code === "000000" ? "111111" : "000000"
    const statuses = []
    for (let i = 0; i < 5; i++) {
      const w = await api("POST", "/api/collections/users/auth-with-otp", { body: { otpId: req.json.otpId, password: wrongCode } })
      statuses.push(w.status)
    }
    check(statuses.every((s) => s === 400), "5 échecs → 400", statuses)
    const locked = await api("POST", "/api/collections/users/auth-with-otp", { body: { otpId: req.json.otpId, password: code } })
    check(locked.status === 429 && locked.json && locked.json.code === "otp_locked", "6e essai (même bon) → 429 otp_locked", locked.json)
  }

  // ---------------------------------------------------------------------------------------
  section("Compte : pseudo et champs protégés")
  const B = await login("agent.b." + Date.now() + "@example.org")
  {
    const p = await api("PATCH", "/api/collections/users/records/" + A.id, { token: A.token, body: { pseudo: "  Nadia Ç.  " } })
    check(p.status === 200 && p.json.pseudo === "Nadia Ç.", "pseudo modifié (espaces retirés, accents)", p.json)
    const long = await api("PATCH", "/api/collections/users/records/" + A.id, { token: A.token, body: { pseudo: "x".repeat(21) } })
    check(long.status === 400, "pseudo > 20 → 400", long.status)
    const html = await api("PATCH", "/api/collections/users/records/" + A.id, { token: A.token, body: { pseudo: "<b>x</b>" } })
    check(html.status === 400, "pseudo avec < > → 400", html.status)
    const mail = await api("PATCH", "/api/collections/users/records/" + A.id, { token: A.token, body: { email: "x@example.org" } })
    check(mail.status === 400 && mail.json.data.email && mail.json.data.email.code === "not_editable", "email non modifiable", mail.json)
    const tag = await api("PATCH", "/api/collections/users/records/" + A.id, { token: A.token, body: { tag: "ZZZZ" } })
    check(tag.status === 400, "tag non modifiable", tag.status)
    const ver = await api("PATCH", "/api/collections/users/records/" + A.id, { token: A.token, body: { verified: false } })
    check(ver.status === 400, "verified non modifiable", ver.status)
    const other = await api("PATCH", "/api/collections/users/records/" + A.id, { token: B.token, body: { pseudo: "pirate" } })
    check(other.status === 404 || other.status === 403, "modifier le compte d'un autre → refusé", other.status)
    const list = await api("GET", "/api/collections/users/records", { token: B.token })
    check(list.status === 200 && list.json.items.length === 1 && list.json.items[0].id === B.id, "liste des users : soi seulement", list.json)
    const anon = await api("GET", "/api/collections/users/records")
    check(anon.status === 200 && anon.json.items.length === 0, "liste des users anonyme : vide")
    const me = await api("GET", "/api/clearance/me", { token: A.token })
    check(me.status === 200 && me.json.pseudo === "Nadia Ç." && me.json.counts.saves === 0 && me.json.email === undefined, "/me : pseudo, compteurs, sans e-mail", me.json)
  }

  // ---------------------------------------------------------------------------------------
  section("Sauvegardes : écriture, remplacement, concurrence")
  const meta1 = { version: 6, current_day: 5, save_serial: 3, saved_unix_ms: 1793498425123, campaign_seed: 9007199254740991 }
  {
    const put = await api("PUT", "/api/clearance/saves/1/meta/0", {
      token: A.token, body: { payload: meta1, game_version: "1.1.0", save_serial: 3, saved_unix_ms: 1793498425123, device: "Deck" },
    })
    check(put.status === 201 && put.json.rev === 1 && put.json.slot === 1 && put.json.kind === "meta", "PUT création → 201 rev 1", put.json)
    check(put.json.size === Buffer.byteLength(JSON.stringify(meta1)), "size = octets du payload", put.json.size)
    const get = await api("GET", "/api/clearance/saves/1/meta/0", { token: A.token })
    check(get.status === 200 && get.json.payload.current_day === 5 && get.json.payload.campaign_seed === 9007199254740991, "GET → payload exact (entier 53 bits)", get.json)
    check(get.json.device === "Deck" && get.json.save_serial === 3 && get.json.saved_unix_ms === 1793498425123, "métadonnées relues")
    check(typeof get.json.updated_unix_ms === "number" && get.json.updated_unix_ms > 0, "updated_unix_ms")

    const meta2 = Object.assign({}, meta1, { current_day: 6, save_serial: 4 })
    const rep = await api("PUT", "/api/clearance/saves/1/meta/0", { token: A.token, body: { payload: meta2, save_serial: 4, if_rev: 1 } })
    check(rep.status === 200 && rep.json.rev === 2, "PUT remplacement (if_rev 1) → 200 rev 2", rep.json)
    const conflict = await api("PUT", "/api/clearance/saves/1/meta/0", { token: A.token, body: { payload: meta1, if_rev: 1 } })
    check(conflict.status === 409 && conflict.json.code === "rev_conflict" && conflict.json.data.current.rev === 2, "if_rev périmé → 409 rev_conflict + méta distante", conflict.json)
    const mustNotExist = await api("PUT", "/api/clearance/saves/1/meta/0", { token: A.token, body: { payload: meta1, if_rev: 0 } })
    check(mustNotExist.status === 409 && mustNotExist.json.data.current.rev === 2, "if_rev 0 sur ligne existante → 409")
    const fresh = await api("PUT", "/api/clearance/saves/1/current/0", { token: A.token, body: { payload: { version: 6, current_day: 6 }, if_rev: 0 } })
    check(fresh.status === 201, "if_rev 0 sur ligne absente → 201", fresh.json)
    const after = await api("GET", "/api/clearance/saves/1/meta/0", { token: A.token })
    check(after.json.payload.current_day === 6 && after.json.rev === 2, "le conflit n'a rien écrasé")

    for (const day of [5, 6]) {
      await api("PUT", "/api/clearance/saves/1/snapshot/" + day, { token: A.token, body: { payload: { version: 6, current_day: day } } })
    }
    await api("PUT", "/api/clearance/saves/0/profile/0", { token: A.token, body: { payload: { version: 3, endings_seen: [] } } })
    await api("PUT", "/api/clearance/saves/2/demo_meta/0", { token: A.token, body: { payload: { version: 6, current_day: 2 } } })

    const man = await api("GET", "/api/clearance/saves", { token: A.token })
    const keys = man.json.items.map((i) => i.slot + "/" + i.kind + "/" + i.day)
    check(man.status === 200 && man.json.items.every((i) => i.payload === undefined), "manifeste sans payload")
    check(JSON.stringify(keys) === JSON.stringify(["0/profile/0", "1/current/0", "1/meta/0", "1/snapshot/5", "1/snapshot/6"]), "manifeste (famille game) trié", keys)
    check(man.json.rows === 6 && man.json.rows_max === 240, "rows / rows_max", man.json)
    const demo = await api("GET", "/api/clearance/saves?family=demo", { token: A.token })
    check(demo.json.items.length === 1 && demo.json.items[0].kind === "demo_meta", "famille demo séparée", demo.json.items)

    const cases = [
      ["/api/clearance/saves/1/profile/0", "slot", "profil hors slot 0"],
      ["/api/clearance/saves/0/meta/0", "slot", "meta en slot 0"],
      ["/api/clearance/saves/1/snapshot/0", "day", "instantané jour 0"],
      ["/api/clearance/saves/1/snapshot/32", "day", "instantané jour 32"],
      ["/api/clearance/saves/1/meta/3", "day", "meta avec jour"],
      ["/api/clearance/saves/4/meta/0", "slot", "slot 4"],
      ["/api/clearance/saves/1/settings/0", "kind", "kind inconnu"],
    ]
    for (const [path, field, label] of cases) {
      const r = await api("PUT", path, { token: A.token, body: { payload: { a: 1 } } })
      check(r.status === 400 && r.json.code === "invalid_field" && r.json.data[field], "cohérence : " + label + " → 400 " + field, r.json)
    }
    const arr = await api("PUT", "/api/clearance/saves/2/meta/0", { token: A.token, body: { payload: [1, 2] } })
    check(arr.status === 400 && arr.json.data.payload, "payload tableau → 400", arr.json)
    const none = await api("PUT", "/api/clearance/saves/2/meta/0", { token: A.token, body: { device: "PC" } })
    check(none.status === 400 && none.json.data.payload.code === "required", "payload absent → 400 required", none.json)
    const big = await api("PUT", "/api/clearance/saves/2/meta/0", { token: A.token, body: { payload: { blob: "é".repeat(140000) } } })
    check(big.status === 413 && big.json.code === "payload_too_large", "payload 280 Kio (UTF-8) → 413", big.status)
    const huge = await api("PUT", "/api/clearance/saves/2/meta/0", { token: A.token, body: { payload: { blob: "x".repeat(400000) } } })
    check(huge.status === 413, "corps > 320 Kio → 413", huge.status)
    const ok256 = await api("PUT", "/api/clearance/saves/2/meta/0", { token: A.token, body: { payload: { blob: "x".repeat(250000) } } })
    check(ok256.status === 201, "payload 250 Ko accepté", ok256.status)
    await api("DELETE", "/api/clearance/saves/2/meta/0", { token: A.token })
  }

  section("Sauvegardes : isolement entre comptes et API standard")
  {
    const bman = await api("GET", "/api/clearance/saves", { token: B.token })
    check(bman.status === 200 && bman.json.items.length === 0, "B ne voit aucune sauvegarde de A (manifeste)", bman.json)
    const bget = await api("GET", "/api/clearance/saves/1/meta/0", { token: B.token })
    check(bget.status === 404, "B : GET 1/meta/0 → 404 (espace propre)", bget.status)
    const stdB = await api("GET", "/api/collections/saves/records", { token: B.token })
    check(stdB.status === 200 && stdB.json.items.length === 0, "API standard : B liste 0 ligne", stdB.json)
    const stdA = await api("GET", "/api/collections/saves/records?fields=id,slot,kind,day", { token: A.token })
    check(stdA.status === 200 && stdA.json.totalItems === 6, "API standard : A liste ses 6 lignes", stdA.json && stdA.json.totalItems)
    const anyId = stdA.json.items[0].id
    const view = await api("GET", "/api/collections/saves/records/" + anyId, { token: B.token })
    check(view.status === 404, "API standard : B ne lit pas une ligne de A par id", view.status)
    const anon = await api("GET", "/api/collections/saves/records")
    check(anon.status === 200 && anon.json.items.length === 0, "API standard anonyme : rien")
    const create = await api("POST", "/api/collections/saves/records", { token: B.token, body: { user: B.id, slot: 1, kind: "meta", day: 0, payload: { a: 1 } } })
    check(create.status === 403 || create.status === 400, "API standard : création refusée", create.status)
    const upd = await api("PATCH", "/api/collections/saves/records/" + anyId, { token: A.token, body: { payload: { hacked: true } } })
    check(upd.status === 403 || upd.status === 404, "API standard : modification refusée (même propriétaire)", upd.status)
    const del = await api("DELETE", "/api/collections/saves/records/" + anyId, { token: B.token })
    check(del.status === 403 || del.status === 404, "API standard : suppression d'autrui refusée", del.status)
    const bdel = await api("DELETE", "/api/clearance/saves/1", { token: B.token })
    check(bdel.status === 200 && bdel.json.deleted === 0, "B supprime « son » slot 1 : rien chez A")
    const still = await api("GET", "/api/clearance/saves", { token: A.token })
    check(still.json.items.length === 5, "les lignes de A sont intactes")
  }

  section("Sauvegardes : suppression")
  {
    const d1 = await api("DELETE", "/api/clearance/saves/1/snapshot/6", { token: A.token })
    check(d1.status === 200 && d1.json.deleted === 1, "DELETE d'une ligne → deleted 1")
    const d2 = await api("DELETE", "/api/clearance/saves/1/snapshot/6", { token: A.token })
    check(d2.status === 200 && d2.json.deleted === 0, "DELETE idempotent → deleted 0")
    await api("PUT", "/api/clearance/saves/1/demo_current/0", { token: A.token, body: { payload: { v: 1 } } })
    const d3 = await api("DELETE", "/api/clearance/saves/1?family=game", { token: A.token })
    check(d3.status === 200 && d3.json.deleted === 3, "DELETE slot 1 (game) → 3 lignes", d3.json)
    const man = await api("GET", "/api/clearance/saves?family=all", { token: A.token })
    const keys = man.json.items.map((i) => i.slot + "/" + i.kind)
    check(keys.includes("1/demo_current") && keys.includes("0/profile") && !keys.includes("1/meta"), "la famille demo et le profil restent", keys)
    // Remet un emplacement pour le test de suppression du compte.
    await api("PUT", "/api/clearance/saves/1/meta/0", { token: A.token, body: { payload: meta1 } })
  }

  // ---------------------------------------------------------------------------------------
  section("Garde : envoi, meilleur score, plausibilité, fréquence")
  const C = await login("agent.c." + Date.now() + "@example.org")
  const D = await login("agent.d." + Date.now() + "@example.org")
  const SEED = "NUIT-2026-10-30"
  {
    const s1 = await api("POST", "/api/clearance/garde/scores", { token: A.token, body: run({ score: 40, errors: 1, passengers: 40 }) })
    check(s1.status === 200 && s1.json.improved === true && s1.json.rank === 1 && s1.json.total === 1, "1er envoi → improved, rang 1/1", s1.json)
    check(s1.json.best && s1.json.best.attempts === 1 && s1.json.best.first_try === true, "best.attempts 1, first_try", s1.json.best)

    const fast = await api("POST", "/api/clearance/garde/scores", { token: A.token, body: run({ score: 30, passengers: 31, errors: 1, directives: 6, tier_max: 1 }) })
    check(fast.status === 429 && fast.json.code === "rate_limited" && fast.json.data.retry_after_s >= 1, "envoi immédiat → 429 rate_limited", fast.json)
    await sleep(1100)
    const worse = await api("POST", "/api/clearance/garde/scores", { token: A.token, body: run({ score: 30, passengers: 31, errors: 1, directives: 6, tier_max: 1, first_try: false }) })
    check(worse.status === 200 && worse.json.improved === false && worse.json.best.score === 40 && worse.json.best.attempts === 2, "envoi moins bon → improved false, meilleur gardé, attempts 2", worse.json)
    await sleep(1100)
    const tieBetter = await api("POST", "/api/clearance/garde/scores", { token: A.token, body: run({ score: 40, errors: 0, passengers: 40, first_try: false }) })
    check(tieBetter.json.improved === true && tieBetter.json.best.errors === 0, "même score, moins d'erreurs → improved", tieBetter.json)
    await sleep(1100)
    const better = await api("POST", "/api/clearance/garde/scores", { token: A.token, body: run({ score: 55, errors: 2, passengers: 50, directives: 10, duration_s: 1500, tier_max: 2, first_try: false }) })
    check(better.json.improved === true && better.json.best.score === 55 && better.json.best.attempts === 4, "meilleur score → remplacé, attempts 4", better.json)

    const own = await api("GET", "/api/collections/garde_scores/records", { token: A.token })
    check(own.json.totalItems === 1, "une seule ligne par (user, graine, version)", own.json.totalItems)
    await sleep(1100)
    const v3 = await api("POST", "/api/clearance/garde/scores", { token: A.token, body: run({ garde_version: 3, score: 10, errors: 0, passengers: 10, directives: 2, tier_max: 0 }) })
    check(v3.status === 200 && v3.json.total === 1 && v3.json.best.garde_version === 3, "autre garde_version → classement séparé", v3.json)

    const implausible = [
      [{ score: 81, passengers: 41, errors: 1 }, "score_above_max"],
      [{ score: 30, passengers: 41, errors: 1 }, "score_below_correct"],
      [{ errors: 4, passengers: 40, score: 36 }, "errors_above_max"],
      [{ errors: 2, passengers: 1, score: 0, directives: 0, tier_max: 0 }, "errors_above_passengers"],
      [{ duration_s: 60, passengers: 40, score: 40, errors: 0 }, "too_fast"],
      [{ tier_max: 3, passengers: 40, score: 40, errors: 0 }, "tier_above_passengers"],
      [{ directives: 9, passengers: 40, score: 40, errors: 0 }, "directives_above_passengers"],
      [{ passengers: 401, score: 401, errors: 0, duration_s: 5000, tier_max: 4, directives: 80 }, "passengers_above_max"],
    ]
    for (const [over, reason] of implausible) {
      const r = await api("POST", "/api/clearance/garde/scores", { token: C.token, body: run(over) })
      check(r.status === 422 && r.json.code === "score_implausible" && r.json.data.reasons.includes(reason), "rejet : " + reason, r.json)
    }
    const edge = await api("POST", "/api/clearance/garde/scores", { token: C.token, body: run({ score: 80, passengers: 41, errors: 1, tier_max: 2, duration_s: 82, directives: 8 }) })
    check(edge.status === 200, "bornes exactes (score = 2×justes, 2 s/passager, palier du 42e) acceptées", edge.json)

    const future = await api("POST", "/api/clearance/garde/scores", { token: D.token, body: run({ seed_code: "NUIT-2099-01-01" }) })
    check(future.status === 400 && future.json.data.seed_code, "graine du jour future → 400", future.json)
    const badDate = await api("POST", "/api/clearance/garde/scores", { token: D.token, body: run({ seed_code: "NUIT-2026-02-30" }) })
    check(badDate.status === 400, "date impossible → 400", badDate.status)
    const badChar = await api("POST", "/api/clearance/garde/scores", { token: D.token, body: run({ seed_code: "K2Q-9T0" }) })
    check(badChar.status === 400, "code libre avec 0 → 400", badChar.status)
    const missing = await api("POST", "/api/clearance/garde/scores", { token: D.token, body: { seed_code: SEED } })
    check(missing.status === 400 && missing.json.code === "invalid_field", "champs manquants → 400", missing.json)
    const free = await api("POST", "/api/clearance/garde/scores", { token: D.token, body: run({ seed_code: " k2q9tx " }) })
    check(free.status === 200 && free.json.best.seed_code === "K2Q-9TX", "code libre canonisé (casse, tiret)", free.json)
    const anon = await api("POST", "/api/clearance/garde/scores", { body: run() })
    check(anon.status === 401, "envoi anonyme → 401")
  }

  section("Classement : top N, ex aequo, rang du joueur")
  {
    await api("PATCH", "/api/collections/users/records/" + C.id, { token: C.token, body: { pseudo: "Cyd" } })
    await sleep(1100)
    // C : 80 ; A : 55 (2 erreurs) ; D : 55 (3 erreurs) ; B : 20.
    const d = await api("POST", "/api/clearance/garde/scores", { token: D.token, body: run({ score: 55, errors: 3, passengers: 50, directives: 10, duration_s: 1400, tier_max: 2 }) })
    check(d.status === 200 && d.json.rank === 2, "ex aequo au score avec A → même rang 2", d.json)
    const b = await api("POST", "/api/clearance/garde/scores", { token: B.token, body: run({ score: 20, errors: 0, passengers: 20, directives: 4, duration_s: 600, tier_max: 1 }) })
    check(b.json.rank === 4 && b.json.total === 4, "B : rang 4/4", b.json)

    const pub = await api("GET", "/api/clearance/leaderboard?seed=nuit-2026-10-30&version=2&limit=10")
    check(pub.status === 200 && pub.json.seed_code === SEED && pub.json.garde_version === 2 && pub.json.total === 4, "classement public", pub.json)
    const ranks = pub.json.entries.map((e) => e.rank + ":" + e.score + ":" + e.errors)
    check(JSON.stringify(ranks) === JSON.stringify(["1:80:1", "2:55:2", "2:55:3", "4:20:0"]), "rangs 1, 2, 2, 4 (ex aequo, départage erreurs)", ranks)
    check(pub.json.entries[0].pseudo === "Cyd" && /^[A-Z2-9]{4}$/.test(pub.json.entries[0].tag), "pseudo + tag publics")
    check(pub.json.me === null && pub.json.entries.every((e) => e.is_me === false), "sans jeton : me null")
    check(!pub.text.includes("@example.org") && !pub.text.includes(A.id) && !pub.text.includes('"user"'), "ni e-mail ni id utilisateur dans la réponse")

    const top1 = await api("GET", "/api/clearance/leaderboard?seed=" + SEED + "&version=2&limit=1", { token: B.token })
    check(top1.json.entries.length === 1 && top1.json.me && top1.json.me.rank === 4 && top1.json.me.is_me === true && top1.json.me.score === 20, "me hors du top N avec son rang", top1.json)
    const mine = await api("GET", "/api/clearance/leaderboard?seed=" + SEED + "&limit=10", { token: C.token })
    check(mine.json.garde_version === 3 && mine.json.total === 1, "version absente → plus haute version présente", mine.json)
    const empty = await api("GET", "/api/clearance/leaderboard?seed=NUIT-2026-01-02")
    check(empty.status === 200 && empty.json.total === 0 && empty.json.entries.length === 0, "graine sans score → vide")
    const badLimit = await api("GET", "/api/clearance/leaderboard?seed=" + SEED + "&limit=99")
    check(badLimit.status === 400, "limit 99 → 400")
    const noSeed = await api("GET", "/api/clearance/leaderboard")
    check(noSeed.status === 400, "seed manquant → 400")
  }

  // ---------------------------------------------------------------------------------------
  section("Fins : envoi idempotent et agrégats")
  {
    const e1 = await api("POST", "/api/clearance/endings", { token: A.token, body: { ending_id: "f5_air", variant: "b", act: 3, difficulty: "hard", game_version: "1.1.0" } })
    check(e1.status === 201 && e1.json.created === true, "1er envoi → 201 created", e1.json)
    const e2 = await api("POST", "/api/clearance/endings", { token: A.token, body: { ending_id: "f5_air", variant: "b", act: 3, difficulty: "hard" } })
    check(e2.status === 200 && e2.json.created === false, "même fin/variante → 200 created false", e2.json)
    await api("POST", "/api/clearance/endings", { token: A.token, body: { ending_id: "f5_air", variant: "", act: 2 } })
    await api("POST", "/api/clearance/endings", { token: B.token, body: { ending_id: "f1_arrested", variant: "audit", act: 1, difficulty: "story" } })
    await api("POST", "/api/clearance/endings", { token: C.token, body: { ending_id: "f5_air", variant: "s", act: 3 } })
    const bad = await api("POST", "/api/clearance/endings", { token: A.token, body: { ending_id: "f11_secret", variant: "", act: 3 } })
    check(bad.status === 400 && bad.json.data.ending_id, "fin inconnue → 400", bad.json)
    const badAct = await api("POST", "/api/clearance/endings", { token: A.token, body: { ending_id: "f2_reassigned", act: 4 } })
    check(badAct.status === 400 && badAct.json.data.act, "acte 4 → 400")
    const badVar = await api("POST", "/api/clearance/endings", { token: A.token, body: { ending_id: "f2_reassigned", act: 1, variant: "B!" } })
    check(badVar.status === 400 && badVar.json.data.variant, "variante mal formée → 400")
    const badDiff = await api("POST", "/api/clearance/endings", { token: A.token, body: { ending_id: "f2_reassigned", act: 1, difficulty: "easy" } })
    check(badDiff.status === 400 && badDiff.json.data.difficulty, "difficulté inconnue → 400")
    const anon = await api("POST", "/api/clearance/endings", { body: { ending_id: "f2_reassigned", act: 1 } })
    check(anon.status === 401, "envoi anonyme → 401")

    await sleep(2100) // cache serveur (CLEARANCE_ENDINGS_CACHE_S=2)
    const agg = await api("GET", "/api/clearance/endings")
    check(agg.status === 200 && agg.json.players === 3, "agrégats : 3 joueurs ayant une fin", agg.json)
    const f5 = agg.json.endings.f5_air
    check(f5 && f5.players === 2 && f5.percent === 66.7, "f5_air : 2 joueurs (variantes confondues), 66,7 %", f5)
    check(f5 && f5.variants.b.players === 1 && f5.variants.s.percent === 33.3 && f5.variants[""].players === 1, "détail par variante", f5 && f5.variants)
    check(agg.json.endings.f1_arrested.percent === 33.3 && agg.json.endings.f4_glory === undefined, "fin jamais obtenue absente sans ids")
    check((agg.headers.get("cache-control") || "").includes("max-age=2"), "Cache-Control max-age", agg.headers.get("cache-control"))
    check(!agg.text.includes("@") && !agg.text.includes(A.id), "agrégats anonymes")
    const ids = await api("GET", "/api/clearance/endings?ids=f1_arrested,f4_glory")
    check(Object.keys(ids.json.endings).join(",") === "f1_arrested,f4_glory" && ids.json.endings.f4_glory.players === 0, "filtre ids (fin non obtenue → 0)", ids.json)
    const badIds = await api("GET", "/api/clearance/endings?ids=zzz")
    check(badIds.status === 400, "ids inconnu → 400")

    await api("POST", "/api/clearance/endings", { token: D.token, body: { ending_id: "f4_glory", act: 2 } })
    const cached = await api("GET", "/api/clearance/endings")
    check(cached.json.players === 3 && cached.json.generated_unix_ms === agg.json.generated_unix_ms, "cache : réponse inchangée avant expiration")
    await sleep(2100)
    const refreshed = await api("GET", "/api/clearance/endings")
    check(refreshed.json.players === 4 && refreshed.json.endings.f4_glory.players === 1, "cache expiré : nouvelles valeurs", refreshed.json.players)
  }

  // ---------------------------------------------------------------------------------------
  section("Déconnexion de tous les appareils")
  {
    const E = await login("agent.e." + Date.now() + "@example.org")
    const before = await api("GET", "/api/clearance/me", { token: E.token })
    check(before.status === 200, "jeton valide avant")
    const out = await api("POST", "/api/clearance/logout-all", { token: E.token })
    check(out.status === 204, "logout-all → 204", out.status)
    const after = await api("GET", "/api/clearance/me", { token: E.token })
    check(after.status === 401, "ancien jeton → 401 après logout-all", after.status)
    const refresh = await api("POST", "/api/collections/users/auth-refresh", { token: E.token })
    check(refresh.status === 401, "auth-refresh avec l'ancien jeton → 401", refresh.status)
  }

  // ---------------------------------------------------------------------------------------
  section("Suppression du compte et de toutes ses données")
  {
    const su = await superToken()
    const count = async (coll, uid) => (await api("GET", `/api/collections/${coll}/records?filter=${encodeURIComponent(`user="${uid}"`)}`, { token: su })).json.totalItems
    check((await count("saves", A.id)) > 0 && (await count("garde_scores", A.id)) > 0 && (await count("ending_events", A.id)) > 0, "A a des données (vu par le superadmin)")
    const aggBefore = await api("GET", "/api/clearance/endings")

    const byOther = await api("DELETE", "/api/collections/users/records/" + A.id, { token: B.token })
    check(byOther.status === 404 || byOther.status === 403, "B ne peut pas supprimer A", byOther.status)
    const del = await api("DELETE", "/api/collections/users/records/" + A.id, { token: A.token })
    check(del.status === 204, "A supprime son compte → 204", del.status)
    check((await count("saves", A.id)) === 0, "sauvegardes de A supprimées")
    check((await count("garde_scores", A.id)) === 0, "scores de A supprimés")
    check((await count("ending_events", A.id)) === 0, "fins de A supprimées")
    const users = await api("GET", `/api/collections/users/records?filter=${encodeURIComponent(`id="${A.id}"`)}`, { token: su })
    check(users.json.totalItems === 0, "compte A supprimé")
    const otps = await api("GET", `/api/collections/_otps/records?filter=${encodeURIComponent(`recordRef="${A.id}"`)}`, { token: su })
    check(otps.status !== 200 || otps.json.totalItems === 0, "codes OTP de A supprimés", otps.json)
    const me = await api("GET", "/api/clearance/me", { token: A.token })
    check(me.status === 401, "jeton de A → 401")
    const board = await api("GET", "/api/clearance/leaderboard?seed=" + SEED + "&version=2")
    check(board.json.total === 3 && !board.json.entries.some((e) => e.score === 55 && e.errors === 2), "A retiré du classement", board.json)
    const aggAfter = await api("GET", "/api/clearance/endings")
    check(aggAfter.json.players === aggBefore.json.players - 1, "agrégats recalculés aussitôt (cache invalidé)", [aggBefore.json.players, aggAfter.json.players])
    check((await count("saves", B.id)) === 0 && (await count("garde_scores", B.id)) === 1, "données des autres intactes")
  }

  // ---------------------------------------------------------------------------------------
  section("Limite de fréquence des demandes de code (par IP)")
  {
    let limited = null
    for (let i = 0; i < 30; i++) {
      const r = await api("POST", "/api/collections/users/request-otp", { body: { email: "spam" + i + "@example.org" } })
      if (r.status === 429) {
        limited = i
        break
      }
    }
    check(limited !== null, "request-otp finit par répondre 429", limited)
  }

  console.log(`\n${passed} réussis, ${failed} échoués`)
  if (failed > 0) {
    console.log("Échecs :\n - " + failures.join("\n - "))
    process.exit(1)
  }
}

main().catch((err) => {
  console.error("Erreur fatale :", err)
  process.exit(2)
})
