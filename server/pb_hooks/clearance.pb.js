/// <reference path="../pb_data/types.d.ts" />
// CLEARANCE M16 (lot S) — crochets et routes. Contrat : docs/ONLINE.md.
// Chaque gestionnaire recharge la bibliothèque (`require`) : les contextes JSVM
// sont isolés (rien du niveau supérieur n'est visible dans un gestionnaire).

// =====================================================================================
// Réglages appliqués à chaque démarrage depuis l'environnement (Coolify = source de vérité)
// =====================================================================================
onBootstrap((e) => {
  e.next()
  const lib = require(`${__hooks}/clearance_lib.js`)
  const s = e.app.settings()

  s.meta.appName = lib.env("CLEARANCE_APP_NAME", "CLEARANCE")
  s.meta.appURL = lib.env("CLEARANCE_APP_URL", "https://clearance-api.cardormedia.com")
  s.meta.senderName = lib.env("SMTP_SENDER_NAME", "CLEARANCE")
  s.meta.senderAddress = lib.env("SMTP_SENDER_ADDRESS", "no-reply@cardormedia.com")
  s.meta.hideControls = lib.env("CLEARANCE_HIDE_CONTROLS", "1") === "1"

  const smtpHost = lib.env("SMTP_HOST", "")
  s.smtp.enabled = smtpHost !== ""
  if (smtpHost !== "") {
    s.smtp.host = smtpHost
    s.smtp.port = lib.envInt("SMTP_PORT", 587)
    s.smtp.username = lib.env("SMTP_USERNAME", "")
    s.smtp.password = lib.env("SMTP_PASSWORD", "")
    s.smtp.tls = lib.env("SMTP_TLS", s.smtp.port === 465 ? "1" : "0") === "1"
    s.smtp.authMethod = lib.env("SMTP_AUTH_METHOD", "PLAIN")
    s.smtp.localName = lib.env("SMTP_LOCAL_NAME", "")
  }

  const headers = lib.env("CLEARANCE_TRUSTED_PROXY_HEADERS", "CF-Connecting-IP,X-Forwarded-For")
  s.trustedProxy.headers = headers.split(",").map((h) => h.trim()).filter((h) => h !== "")
  s.trustedProxy.useLeftmostIP = false

  const otpPer10 = lib.envInt("CLEARANCE_OTP_PER_10MIN", 5)
  s.rateLimits.enabled = lib.env("CLEARANCE_RATE_LIMITS", "1") === "1"
  s.rateLimits.rules = [
    { label: "*:requestOTP", audience: "", duration: 600, maxRequests: otpPer10 },
    { label: "*:authWithOTP", audience: "", duration: 600, maxRequests: otpPer10 * 2 },
    { label: "*:auth", audience: "", duration: 3, maxRequests: 2 },
    { label: "*:create", audience: "", duration: 5, maxRequests: 20 },
    { label: "/api/batch", audience: "", duration: 1, maxRequests: 3 },
    { label: "/api/", audience: "", duration: 10, maxRequests: 300 },
  ]
  s.batch.enabled = false
  s.logs.maxDays = lib.envInt("CLEARANCE_LOG_DAYS", 7)
  s.logs.logIP = true
  s.logs.logAuthId = false
  const backupCron = lib.env("CLEARANCE_BACKUP_CRON", "0 3 * * *")
  s.backups.cron = backupCron === "off" ? "" : backupCron
  s.backups.cronMaxKeep = lib.envInt("CLEARANCE_BACKUP_KEEP", 7)
  e.app.save(s)
})

// =====================================================================================
// En-têtes : CORP cross-origin sur toutes les réponses (page /play/ en COEP require-corp)
// =====================================================================================
// Priorité très basse = exécuté avant le middleware CORS de PocketBase, qui
// répond lui-même aux pré-vols OPTIONS sans appeler la suite.
routerUse(new Middleware((e) => {
  e.response.header().set("Cross-Origin-Resource-Policy", "cross-origin")
  return e.next()
}, -1000000, "clearance_corp"))

// =====================================================================================
// OTP : verrouillage d'un otpId après 5 échecs (ONLINE §2.2)
// =====================================================================================
routerUse((e) => {
  if (e.request.method !== "POST" || e.request.url.path !== "/api/collections/users/auth-with-otp") {
    return e.next()
  }
  const lib = require(`${__hooks}/clearance_lib.js`)
  const b = lib.body(e)
  const otpId = b && typeof b.otpId === "string" ? b.otpId : ""
  const key = "clearance:otpfail:" + otpId
  const store = $app.store()
  if (otpId !== "" && Number(store.get(key) || 0) >= lib.OTP_MAX_FAILURES) {
    return lib.fail(e, 429, "otp_locked", "Too many failed attempts for this code; request a new one.", {})
  }
  try {
    e.next()
    if (otpId !== "") store.remove(key)
  } catch (err) {
    if (otpId !== "") store.set(key, Number(store.get(key) || 0) + 1)
    throw err
  }
})

// =====================================================================================
// Comptes
// =====================================================================================

// Compte créé à la première demande de code (aucune inscription séparée).
onRecordRequestOTPRequest((e) => {
  if (!e.record) {
    const lib = require(`${__hooks}/clearance_lib.js`)
    const b = lib.body(e) || {}
    const email = String(b.email || "").trim().toLowerCase()
    const rec = new Record(e.collection)
    rec.setEmail(email)
    rec.setEmailVisibility(false)
    rec.setPassword($security.randomString(48))
    rec.set("tag", lib.randomTag())
    e.app.save(rec)
    e.record = rec
  }
  return e.next()
}, "users")

// Tag public fixé à la création (aussi pour un compte créé depuis la console).
onRecordCreate((e) => {
  if (e.record.getString("tag") === "") {
    const lib = require(`${__hooks}/clearance_lib.js`)
    e.record.set("tag", lib.randomTag())
  }
  return e.next()
}, "users")

// Première connexion par code : adresse vérifiée.
onRecordAuthWithOTPRequest((e) => {
  if (e.record && !e.record.verified()) {
    e.record.setVerified(true)
    e.app.save(e.record)
  }
  return e.next()
}, "users")

// Seul `pseudo` est modifiable par le joueur.
onRecordUpdateRequest((e) => {
  if (e.hasSuperuserAuth()) return e.next()
  const lib = require(`${__hooks}/clearance_lib.js`)
  const b = lib.body(e) || {}
  const data = {}
  for (const key of Object.keys(b)) {
    if (key !== "pseudo") data[key] = new ValidationError("not_editable", "This field cannot be changed.")
  }
  if (Object.keys(data).length > 0) throw new BadRequestError("Only pseudo can be changed.", data)
  e.record.set("pseudo", String(b.pseudo === undefined || b.pseudo === null ? e.record.getString("pseudo") : b.pseudo).trim())
  return e.next()
}, "users")

// Suppression du compte : nettoyage des lignes restantes, caches, limiteurs.
onRecordAfterDeleteSuccess((e) => {
  const lib = require(`${__hooks}/clearance_lib.js`)
  const id = e.record.id
  for (const table of ["saves", "garde_scores", "ending_events"]) {
    e.app.db().newQuery("DELETE FROM `" + table + "` WHERE user = {:u}").bind({ u: id }).execute()
  }
  lib.clearUserState(id)
  return e.next()
}, "users")

routerAdd("GET", "/api/clearance/status", (e) => {
  const lib = require(`${__hooks}/clearance_lib.js`)
  const users = $app.findCollectionByNameOrId("users")
  return e.json(200, {
    api_version: lib.API_VERSION,
    server: "clearance-pb",
    time_unix_ms: lib.nowMs(),
    limits: lib.LIMITS,
    garde_versions: Object.keys(lib.GARDE_RULES).map((k) => parseInt(k, 10)),
    otp: { length: users.otp.length, duration_s: users.otp.duration },
    token_duration_s: users.authToken.duration,
  })
})

routerAdd("GET", "/api/clearance/me", (e) => {
  const lib = require(`${__hooks}/clearance_lib.js`)
  const user = lib.authUser(e)
  if (!user) return lib.fail(e, 401, "unauthorized", "Authentication required.")
  const counts = {}
  for (const table of ["saves", "garde_scores", "ending_events"]) {
    const row = new DynamicModel({ n: 0 })
    $app.db().newQuery("SELECT COUNT(*) AS n FROM `" + table + "` WHERE user = {:u}").bind({ u: user.id }).one(row)
    counts[table] = row.n
  }
  const out = lib.publicUser(user)
  out.counts = counts
  return e.json(200, out)
})

routerAdd("POST", "/api/clearance/logout-all", (e) => {
  const lib = require(`${__hooks}/clearance_lib.js`)
  const user = lib.authUser(e)
  if (!user) return lib.fail(e, 401, "unauthorized", "Authentication required.")
  const rec = $app.findRecordById("users", user.id)
  rec.refreshTokenKey()
  $app.save(rec)
  return e.noContent(204)
})

// =====================================================================================
// Sauvegardes (ONLINE §5)
// =====================================================================================

routerAdd("GET", "/api/clearance/saves", (e) => {
  const lib = require(`${__hooks}/clearance_lib.js`)
  const user = lib.authUser(e)
  if (!user) return lib.fail(e, 401, "unauthorized", "Authentication required.")
  const family = lib.query(e, "family") || "game"
  if (["game", "demo", "all"].indexOf(family) < 0) return lib.fieldError(e, "family", "bad_value")
  const records = $app.findRecordsByFilter("saves", "user = {:u}", "slot,kind,day", 0, 0, { u: user.id })
  const items = []
  for (const rec of records) {
    if (family !== "all" && lib.kindFamily(rec.getString("kind")) !== family) continue
    items.push(lib.saveMeta(rec))
  }
  return e.json(200, { items: items, rows: records.length, rows_max: lib.LIMITS.save_rows_max })
})

routerAdd("GET", "/api/clearance/saves/{slot}/{kind}/{day}", (e) => {
  const lib = require(`${__hooks}/clearance_lib.js`)
  const user = lib.authUser(e)
  if (!user) return lib.fail(e, 401, "unauthorized", "Authentication required.")
  const key = lib.saveKey(e.request.pathValue("slot"), e.request.pathValue("kind"), e.request.pathValue("day"))
  if (!key.ok) return lib.fieldError(e, key.field, key.code)
  const rec = lib.findSave($app, user.id, key)
  if (!rec) return lib.fail(e, 404, "not_found", "No such save.")
  const out = lib.saveMeta(rec)
  out.payload = JSON.parse(rec.getString("payload"))
  return e.json(200, out)
})

routerAdd("PUT", "/api/clearance/saves/{slot}/{kind}/{day}", (e) => {
  const lib = require(`${__hooks}/clearance_lib.js`)
  const user = lib.authUser(e)
  if (!user) return lib.fail(e, 401, "unauthorized", "Authentication required.")
  const key = lib.saveKey(e.request.pathValue("slot"), e.request.pathValue("kind"), e.request.pathValue("day"))
  if (!key.ok) return lib.fieldError(e, key.field, key.code)
  const b = lib.body(e)
  if (!b) return lib.fail(e, 400, "bad_request", "JSON object body expected.")
  if (!lib.isPlainObject(b.payload)) return lib.fieldError(e, "payload", b.payload === undefined ? "required" : "bad_format")
  const text = JSON.stringify(b.payload)
  const size = lib.utf8Bytes(text)
  if (size > lib.LIMITS.payload_max_bytes) {
    return lib.fail(e, 413, "payload_too_large", "Payload too large.", { size: size, max: lib.LIMITS.payload_max_bytes })
  }
  for (const field of ["save_serial", "saved_unix_ms"]) {
    if (b[field] !== undefined && b[field] !== null && !lib.nonNegInt(b[field])) return lib.fieldError(e, field, "bad_format")
  }
  const ifRev = b.if_rev
  if (ifRev !== undefined && ifRev !== null && !lib.nonNegInt(ifRev)) return lib.fieldError(e, "if_rev", "bad_format")
  const retry = lib.rateCheck("save_write", user.id)
  if (retry > 0) return lib.rateLimited(e, retry)

  let status = 200
  let result = null
  let conflict = null
  let quota = false
  $app.runInTransaction((tx) => {
    let rec = lib.findSave(tx, user.id, key)
    if (ifRev !== undefined && ifRev !== null) {
      const current = rec ? rec.getInt("rev") : 0
      if (current !== ifRev) {
        conflict = { current: rec ? lib.saveMeta(rec) : null }
        return
      }
    }
    if (!rec) {
      if (lib.countSaves(tx, user.id) >= lib.LIMITS.save_rows_max) {
        quota = true
        return
      }
      rec = new Record(tx.findCollectionByNameOrId("saves"))
      rec.set("user", user.id)
      rec.set("slot", key.slot)
      rec.set("kind", key.kind)
      rec.set("day", key.day)
      rec.set("rev", 1)
      status = 201
    } else {
      rec.set("rev", rec.getInt("rev") + 1)
    }
    rec.set("payload", b.payload)
    rec.set("size", size)
    rec.set("game_version", lib.cleanText(b.game_version, 32))
    rec.set("device", lib.cleanText(b.device, 32))
    rec.set("save_serial", b.save_serial || 0)
    rec.set("saved_unix_ms", b.saved_unix_ms || 0)
    tx.save(rec)
    result = lib.saveMeta(rec)
  })
  if (conflict) return lib.fail(e, 409, "rev_conflict", "Remote save changed.", conflict)
  if (quota) return lib.fail(e, 403, "quota_exceeded", "Too many save rows.", { rows_max: lib.LIMITS.save_rows_max })
  return e.json(status, result)
}, $apis.bodyLimit(327680))

routerAdd("DELETE", "/api/clearance/saves/{slot}/{kind}/{day}", (e) => {
  const lib = require(`${__hooks}/clearance_lib.js`)
  const user = lib.authUser(e)
  if (!user) return lib.fail(e, 401, "unauthorized", "Authentication required.")
  const key = lib.saveKey(e.request.pathValue("slot"), e.request.pathValue("kind"), e.request.pathValue("day"))
  if (!key.ok) return lib.fieldError(e, key.field, key.code)
  const retry = lib.rateCheck("save_write", user.id)
  if (retry > 0) return lib.rateLimited(e, retry)
  const rec = lib.findSave($app, user.id, key)
  if (rec) $app.delete(rec)
  return e.json(200, { deleted: rec ? 1 : 0 })
})

routerAdd("DELETE", "/api/clearance/saves/{slot}", (e) => {
  const lib = require(`${__hooks}/clearance_lib.js`)
  const user = lib.authUser(e)
  if (!user) return lib.fail(e, 401, "unauthorized", "Authentication required.")
  const slotText = e.request.pathValue("slot")
  const slot = /^\d$/.test(slotText) ? parseInt(slotText, 10) : -1
  if (slot < 0 || slot > 3) return lib.fieldError(e, "slot", "out_of_range")
  const family = lib.query(e, "family") || "game"
  if (["game", "demo"].indexOf(family) < 0) return lib.fieldError(e, "family", "bad_value")
  const retry = lib.rateCheck("save_write", user.id)
  if (retry > 0) return lib.rateLimited(e, retry)
  const records = $app.findRecordsByFilter("saves", "user = {:u} && slot = {:s}", "", 0, 0, { u: user.id, s: slot })
  let deleted = 0
  $app.runInTransaction((tx) => {
    for (const rec of records) {
      if (lib.kindFamily(rec.getString("kind")) !== family) continue
      tx.delete(rec)
      deleted++
    }
  })
  return e.json(200, { deleted: deleted })
})

// =====================================================================================
// Garde de nuit (ONLINE §6)
// =====================================================================================

routerAdd("POST", "/api/clearance/garde/scores", (e) => {
  const lib = require(`${__hooks}/clearance_lib.js`)
  const user = lib.authUser(e)
  if (!user) return lib.fail(e, 401, "unauthorized", "Authentication required.")
  const b = lib.body(e)
  if (!b) return lib.fail(e, 400, "bad_request", "JSON object body expected.")
  const seed = lib.normalizeSeed(b.seed_code)
  if (!seed.ok) return lib.fieldError(e, "seed_code", "bad_value", seed.reason)
  const run = { seed_code: seed.code, kind: seed.kind }
  const ints = {
    garde_version: [1, lib.GARDE_VERSION_MAX], score: [0, 1e9], errors: [0, 1e9], tier_max: [0, 1e9],
    passengers: [0, 1e9], directives: [0, 1e9], duration_s: [0, 86400],
  }
  for (const field of Object.keys(ints)) {
    let v = b[field]
    if (field === "directives" && (v === undefined || v === null)) v = 0
    if (!lib.isInt(v)) return lib.fieldError(e, field, v === undefined ? "required" : "bad_format")
    if (v < ints[field][0] || v > ints[field][1]) return lib.fieldError(e, field, "out_of_range")
    run[field] = v
  }
  run.first_try = b.first_try === true
  run.end_reason = ["errors", "quit"].indexOf(b.end_reason) >= 0 ? b.end_reason : ""
  run.game_version = lib.cleanText(b.game_version, 32)

  const reasons = lib.gardeImplausible(run)
  if (reasons.length > 0) return lib.fail(e, 422, "score_implausible", "Implausible score.", { reasons: reasons })
  const retry = lib.rateCheck("garde_submit", user.id)
  if (retry > 0) return lib.rateLimited(e, retry)

  let improved = false
  let best = null
  $app.runInTransaction((tx) => {
    let rec = null
    try {
      rec = tx.findFirstRecordByFilter("garde_scores", "user = {:u} && seed_code = {:s} && garde_version = {:v}",
        { u: user.id, s: run.seed_code, v: run.garde_version })
    } catch (_) {
      rec = null
    }
    if (!rec) {
      rec = new Record(tx.findCollectionByNameOrId("garde_scores"))
      rec.set("user", user.id)
      rec.set("seed_code", run.seed_code)
      rec.set("garde_version", run.garde_version)
      rec.set("attempts", 0)
      improved = true
    } else {
      improved = lib.gardeBetter(run, lib.gardeRow(rec))
    }
    if (improved) {
      for (const field of ["kind", "score", "errors", "tier_max", "passengers", "directives", "duration_s",
        "first_try", "end_reason", "game_version"]) {
        rec.set(field, run[field])
      }
    }
    rec.set("attempts", rec.getInt("attempts") + 1)
    tx.save(rec)
    best = lib.gardeRow(rec)
  })
  return e.json(200, {
    improved: improved,
    best: best,
    rank: lib.gardeRank($app, best.seed_code, best.garde_version, best.score),
    total: lib.gardeTotal($app, best.seed_code, best.garde_version),
  })
}, $apis.bodyLimit(16384))

routerAdd("GET", "/api/clearance/leaderboard", (e) => {
  const lib = require(`${__hooks}/clearance_lib.js`)
  const seed = lib.normalizeSeed(lib.query(e, "seed"))
  if (!seed.ok) return lib.fieldError(e, "seed", "bad_value", seed.reason)
  let limit = 10
  const limitText = lib.query(e, "limit")
  if (limitText !== "") {
    limit = /^\d{1,3}$/.test(limitText) ? parseInt(limitText, 10) : -1
    if (limit < 1 || limit > 50) return lib.fieldError(e, "limit", "out_of_range")
  }
  let version = 0
  const versionText = lib.query(e, "version")
  if (versionText !== "") {
    version = /^\d{1,4}$/.test(versionText) ? parseInt(versionText, 10) : -1
    if (version < 1 || version > lib.GARDE_VERSION_MAX) return lib.fieldError(e, "version", "out_of_range")
  } else {
    const row = new DynamicModel({ v: 0 })
    $app.db().newQuery("SELECT COALESCE(MAX(garde_version), 0) AS v FROM garde_scores WHERE seed_code = {:s}")
      .bind({ s: seed.code }).one(row)
    version = row.v
  }
  const user = lib.authUser(e)
  const meId = user ? user.id : ""
  const rows = arrayOf(new DynamicModel({
    user: "", pseudo: "", tag: "", score: 0, errors: 0, tier_max: 0, passengers: 0, duration_s: 0, first_try: false,
  }))
  $app.db().newQuery(
    "SELECT g.user AS user, u.pseudo AS pseudo, u.tag AS tag, g.score AS score, g.errors AS errors, " +
    "g.tier_max AS tier_max, g.passengers AS passengers, g.duration_s AS duration_s, g.first_try AS first_try " +
    "FROM garde_scores g JOIN users u ON u.id = g.user " +
    "WHERE g.seed_code = {:s} AND g.garde_version = {:v} " +
    "ORDER BY g.score DESC, g.errors ASC, g.duration_s ASC, g.updated ASC, g.id ASC LIMIT {:l}")
    .bind({ s: seed.code, v: version, l: limit }).all(rows)
  const entry = (row, rank) => ({
    rank: rank, pseudo: row.pseudo, tag: row.tag, score: row.score, errors: row.errors, tier_max: row.tier_max,
    passengers: row.passengers, duration_s: row.duration_s, first_try: !!row.first_try, is_me: meId !== "" && row.user === meId,
  })
  const entries = []
  let rank = 0
  let previous = null
  for (let i = 0; i < rows.length; i++) {
    if (previous === null || rows[i].score !== previous) rank = i + 1
    previous = rows[i].score
    entries.push(entry(rows[i], rank))
  }
  let me = null
  if (meId !== "") {
    try {
      const rec = $app.findFirstRecordByFilter("garde_scores", "user = {:u} && seed_code = {:s} && garde_version = {:v}",
        { u: meId, s: seed.code, v: version })
      me = entry({
        user: meId, pseudo: user.getString("pseudo"), tag: user.getString("tag"), score: rec.getInt("score"),
        errors: rec.getInt("errors"), tier_max: rec.getInt("tier_max"), passengers: rec.getInt("passengers"),
        duration_s: rec.getInt("duration_s"), first_try: rec.getBool("first_try"),
      }, lib.gardeRank($app, seed.code, version, rec.getInt("score")))
    } catch (_) {
      me = null
    }
  }
  return e.json(200, {
    seed_code: seed.code,
    garde_version: version,
    total: version > 0 ? lib.gardeTotal($app, seed.code, version) : 0,
    entries: entries,
    me: me,
  })
})

// =====================================================================================
// Fins (ONLINE §7)
// =====================================================================================

routerAdd("POST", "/api/clearance/endings", (e) => {
  const lib = require(`${__hooks}/clearance_lib.js`)
  const user = lib.authUser(e)
  if (!user) return lib.fail(e, 401, "unauthorized", "Authentication required.")
  const b = lib.body(e)
  if (!b) return lib.fail(e, 400, "bad_request", "JSON object body expected.")
  const endingId = String(b.ending_id || "")
  if (lib.ENDING_IDS.indexOf(endingId) < 0) return lib.fieldError(e, "ending_id", b.ending_id === undefined ? "required" : "bad_value")
  const variant = b.variant === undefined || b.variant === null ? "" : String(b.variant)
  if (!/^[a-z0-9_]{0,16}$/.test(variant)) return lib.fieldError(e, "variant", "bad_format")
  if (!lib.isInt(b.act) || b.act < 1 || b.act > 3) return lib.fieldError(e, "act", b.act === undefined ? "required" : "out_of_range")
  const difficulty = b.difficulty === undefined || b.difficulty === null || b.difficulty === "" ? "hard" : String(b.difficulty)
  if (lib.DIFFICULTIES.indexOf(difficulty) < 0) return lib.fieldError(e, "difficulty", "bad_value")
  const retry = lib.rateCheck("ending_submit", user.id)
  if (retry > 0) return lib.rateLimited(e, retry)
  let created = false
  $app.runInTransaction((tx) => {
    try {
      tx.findFirstRecordByFilter("ending_events", "user = {:u} && ending_id = {:i} && variant = {:v}",
        { u: user.id, i: endingId, v: variant })
      return
    } catch (_) {}
    const rec = new Record(tx.findCollectionByNameOrId("ending_events"))
    rec.set("user", user.id)
    rec.set("ending_id", endingId)
    rec.set("variant", variant)
    rec.set("act", b.act)
    rec.set("difficulty", difficulty)
    rec.set("game_version", lib.cleanText(b.game_version, 32))
    tx.save(rec)
    created = true
  })
  return e.json(created ? 201 : 200, { created: created })
}, $apis.bodyLimit(4096))

routerAdd("GET", "/api/clearance/endings", (e) => {
  const lib = require(`${__hooks}/clearance_lib.js`)
  const agg = lib.endingsAggregate($app)
  const idsText = lib.query(e, "ids")
  let endings = agg.endings
  if (idsText !== "") {
    endings = {}
    for (const id of idsText.split(",").map((s) => s.trim()).filter((s) => s !== "")) {
      if (lib.ENDING_IDS.indexOf(id) < 0) return lib.fieldError(e, "ids", "bad_value", id)
      const row = agg.endings[id]
      endings[id] = row ? row : { players: 0, percent: 0, variants: {} }
    }
  }
  e.response.header().set("Cache-Control", "public, max-age=" + agg.max_age_s)
  return e.json(200, {
    players: agg.players, generated_unix_ms: agg.generated_unix_ms, max_age_s: agg.max_age_s, endings: endings,
  })
})
