// CLEARANCE — bibliothèque partagée des crochets PocketBase (M16, lot S).
// Contrat : docs/ONLINE.md. Chargée par `require()` DANS chaque gestionnaire
// (les gestionnaires JSVM s'exécutent dans des contextes isolés : rien de ce
// qui est déclaré au niveau supérieur d'un *.pb.js n'y est visible).
// Ce fichier ne finit pas par `.pb.js` : PocketBase ne l'exécute pas seul.

const API_VERSION = 1

const LIMITS = {
  payload_max_bytes: 262144, // 256 Kio
  body_max_bytes: 327680, // 320 Kio
  save_rows_max: 240,
  pseudo_max_chars: 20,
}

// Fréquences par compte (fenêtres glissantes, mémoire du processus).
const RATES = {
  save_write: [{ max: 120, window_s: 600 }],
  // CLEARANCE_GARDE_MIN_INTERVAL_S : réglable pour les tests (défaut 15 s).
  garde_submit: [{ max: 1, window_s: envInt("CLEARANCE_GARDE_MIN_INTERVAL_S", 15) }, { max: 30, window_s: 3600 }],
  ending_submit: [{ max: 60, window_s: 3600 }],
}

const OTP_MAX_FAILURES = 5

// Sauvegardes : familles et cohérence slot/kind/day (ONLINE §3.2).
const BASE_KINDS = ["current", "meta", "snapshot", "profile"]
const DEMO_PREFIX = "demo_"
const SAVE_KINDS = BASE_KINDS.concat(BASE_KINDS.map((k) => DEMO_PREFIX + k))
const SLOT_MAX = 3
const SNAPSHOT_DAY_MAX = 31

// Fins (EndingService.ALL_ENDINGS).
const ENDING_IDS = [
  "f1_arrested", "f2_reassigned", "f3_family_lost", "f4_glory", "f5_air",
  "f6_drift", "f7_reopens", "f8_registre", "f9_strike", "f10_pont",
]
const DIFFICULTIES = ["hard", "story"]
const ENDINGS_CACHE_KEY = "clearance:endings_cache"

// Garde de nuit : bornes de plausibilité par `garde_version` (ONLINE §6.2).
// Valeurs tirées de data/garde/garde.tres (max_errors, paliers, file) et de
// data/events/ev_04.tres (score_per_correct +1 pendant une inspection).
const GARDE_RULES = {
  1: { max_errors: 3, max_passengers: 400, max_points_per_correct: 2, min_seconds_per_passenger: 2, tier_from: [1, 21, 41, 61, 101], directive_every: 5 },
  2: { max_errors: 3, max_passengers: 400, max_points_per_correct: 2, min_seconds_per_passenger: 2, tier_from: [1, 21, 41, 61, 101], directive_every: 5 },
}
const GARDE_VERSION_MAX = 1000
const ID_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const DAILY_PREFIX = "NUIT-"
const DAILY_MIN = "2026-01-01"

// --- Réponses ----------------------------------------------------------------------

function fail(e, status, code, message, data) {
  return e.json(status, { status: status, code: code, message: message, data: data || {} })
}

function fieldError(e, field, code, message) {
  const data = {}
  data[field] = { code: code, message: message || code }
  return fail(e, 400, "invalid_field", "Invalid field: " + field, data)
}

// Utilisateur authentifié de la collection `users`, sinon null.
function authUser(e) {
  const auth = e.auth
  if (!auth) return null
  try {
    if (auth.collection().name !== "users") return null
  } catch (_) {
    return null
  }
  return auth
}

function env(name, fallback) {
  const value = $os.getenv(name)
  return value === "" ? fallback : value
}

function envInt(name, fallback) {
  const value = parseInt($os.getenv(name), 10)
  return isNaN(value) ? fallback : value
}

function nowMs() {
  return Date.now()
}

// Taille UTF-8 d'une chaîne (octets).
function utf8Bytes(text) {
  let bytes = 0
  for (let i = 0; i < text.length; i++) {
    const c = text.charCodeAt(i)
    if (c < 0x80) bytes += 1
    else if (c < 0x800) bytes += 2
    else if (c >= 0xd800 && c <= 0xdbff) { bytes += 4; i++ }
    else bytes += 3
  }
  return bytes
}

function isInt(v) {
  return typeof v === "number" && isFinite(v) && Math.floor(v) === v
}

function isPlainObject(v) {
  return v !== null && typeof v === "object" && !Array.isArray(v)
}

// Corps JSON de la requête (objet), ou null.
function body(e) {
  try {
    const b = e.requestInfo().body
    return isPlainObject(b) ? b : null
  } catch (_) {
    return null
  }
}

function query(e, name) {
  return String(e.request.url.query().get(name) || "")
}

// --- Limiteur de fréquence par compte ---------------------------------------------
// Renvoie 0 si autorisé (et compte l'appel), sinon le délai d'attente en secondes.
function rateCheck(bucket, userId) {
  const rules = RATES[bucket]
  const key = "clearance:rl:" + bucket + ":" + userId
  const store = $app.store()
  const now = nowMs()
  const maxWindow = Math.max.apply(null, rules.map((r) => r.window_s)) * 1000
  const raw = store.get(key)
  const hits = []
  if (raw) {
    for (let i = 0; i < raw.length; i++) {
      const t = Number(raw[i])
      if (now - t < maxWindow) hits.push(t)
    }
  }
  let retry = 0
  for (const rule of rules) {
    const windowMs = rule.window_s * 1000
    const inWindow = hits.filter((t) => now - t < windowMs).sort((a, b) => a - b)
    if (inWindow.length >= rule.max) {
      const oldest = inWindow[inWindow.length - rule.max]
      retry = Math.max(retry, Math.ceil((oldest + windowMs - now) / 1000))
    }
  }
  if (retry > 0) {
    store.set(key, hits)
    return retry
  }
  hits.push(now)
  store.set(key, hits)
  return 0
}

function rateLimited(e, retry) {
  return fail(e, 429, "rate_limited", "Too many requests.", { retry_after_s: retry })
}

function clearUserState(userId) {
  const store = $app.store()
  for (const bucket of Object.keys(RATES)) store.remove("clearance:rl:" + bucket + ":" + userId)
  store.remove(ENDINGS_CACHE_KEY)
}

// --- Comptes ---------------------------------------------------------------------------

function randomTag() {
  return $security.randomStringWithAlphabet(4, ID_ALPHABET)
}

function publicUser(rec) {
  return {
    id: rec.id,
    pseudo: rec.getString("pseudo"),
    tag: rec.getString("tag"),
    created: rec.getString("created"),
  }
}

// --- Sauvegardes -------------------------------------------------------------------------

function kindFamily(kind) {
  return kind.indexOf(DEMO_PREFIX) === 0 ? "demo" : "game"
}

function baseKind(kind) {
  return kind.indexOf(DEMO_PREFIX) === 0 ? kind.substring(DEMO_PREFIX.length) : kind
}

// Valide la clé (slot, kind, day) ; renvoie {ok, slot, kind, day, field, code}.
function saveKey(slotText, kind, dayText) {
  const slot = /^\d{1,2}$/.test(slotText) ? parseInt(slotText, 10) : -1
  const day = /^\d{1,2}$/.test(dayText) ? parseInt(dayText, 10) : -1
  if (SAVE_KINDS.indexOf(kind) < 0) return { ok: false, field: "kind", code: "bad_value" }
  if (slot < 0 || slot > SLOT_MAX) return { ok: false, field: "slot", code: "out_of_range" }
  if (day < 0 || day > SNAPSHOT_DAY_MAX) return { ok: false, field: "day", code: "out_of_range" }
  const base = baseKind(kind)
  if (base === "profile") {
    if (slot !== 0) return { ok: false, field: "slot", code: "bad_value" }
    if (day !== 0) return { ok: false, field: "day", code: "bad_value" }
  } else {
    if (slot < 1) return { ok: false, field: "slot", code: "out_of_range" }
    if (base === "snapshot" && day < 1) return { ok: false, field: "day", code: "out_of_range" }
    if (base !== "snapshot" && day !== 0) return { ok: false, field: "day", code: "bad_value" }
  }
  return { ok: true, slot: slot, kind: kind, day: day }
}

function dateMs(text) {
  // PocketBase : "2026-11-01 02:00:25.123Z"
  const ms = Date.parse(String(text).replace(" ", "T"))
  return isNaN(ms) ? 0 : ms
}

function saveMeta(rec) {
  return {
    id: rec.id,
    slot: rec.getInt("slot"),
    kind: rec.getString("kind"),
    day: rec.getInt("day"),
    rev: rec.getInt("rev"),
    save_serial: rec.getInt("save_serial"),
    saved_unix_ms: rec.getInt("saved_unix_ms"),
    game_version: rec.getString("game_version"),
    device: rec.getString("device"),
    size: rec.getInt("size"),
    updated: rec.getString("updated"),
    updated_unix_ms: dateMs(rec.getString("updated")),
  }
}

function findSave(app, userId, key) {
  try {
    return app.findFirstRecordByFilter("saves",
      "user = {:u} && slot = {:s} && kind = {:k} && day = {:d}",
      { u: userId, s: key.slot, k: key.kind, d: key.day })
  } catch (_) {
    return null
  }
}

function countSaves(app, userId) {
  const row = new DynamicModel({ n: 0 })
  app.db().newQuery("SELECT COUNT(*) AS n FROM saves WHERE user = {:u}").bind({ u: userId }).one(row)
  return row.n
}

function cleanText(v, max) {
  if (v === undefined || v === null) return ""
  return String(v).trim().substring(0, max)
}

function nonNegInt(v) {
  return isInt(v) && v >= 0
}

// --- Garde de nuit -------------------------------------------------------------------------

function daysInMonth(y, m) {
  if (m === 2) return (y % 4 === 0 && y % 100 !== 0) || y % 400 === 0 ? 29 : 28
  return [4, 6, 9, 11].indexOf(m) >= 0 ? 30 : 31
}

// Code canonique (GardeService.normalize_code) : {ok, code, kind, reason}.
function normalizeSeed(text, nowMsValue) {
  const raw = String(text || "").trim().toUpperCase()
  if (raw.indexOf(DAILY_PREFIX) === 0) {
    const m = /^(\d{4})-(\d{1,2})-(\d{1,2})$/.exec(raw.substring(DAILY_PREFIX.length))
    if (!m) return { ok: false, reason: "date" }
    const y = parseInt(m[1], 10), mo = parseInt(m[2], 10), d = parseInt(m[3], 10)
    if (y < 2000 || mo < 1 || mo > 12 || d < 1 || d > daysInMonth(y, mo)) return { ok: false, reason: "date" }
    const iso = y + "-" + String(mo).padStart(2, "0") + "-" + String(d).padStart(2, "0")
    if (iso < DAILY_MIN) return { ok: false, reason: "too_old" }
    const tomorrow = new Date((nowMsValue || nowMs()) + 86400000).toISOString().substring(0, 10)
    if (iso > tomorrow) return { ok: false, reason: "future" }
    return { ok: true, code: DAILY_PREFIX + iso, kind: "daily" }
  }
  const compact = raw.replace(/[-\s]/g, "")
  if (compact.length !== 6) return { ok: false, reason: "length" }
  for (let i = 0; i < compact.length; i++) {
    if (ID_ALPHABET.indexOf(compact[i]) < 0) return { ok: false, reason: "char" }
  }
  return { ok: true, code: compact.substring(0, 3) + "-" + compact.substring(3), kind: "free" }
}

function gardeRules(version) {
  if (GARDE_RULES[version]) return GARDE_RULES[version]
  const known = Object.keys(GARDE_RULES).map((k) => parseInt(k, 10)).sort((a, b) => a - b)
  return GARDE_RULES[known[known.length - 1]]
}

function tierFor(rules, passenger) {
  let tier = 0
  for (let i = 0; i < rules.tier_from.length; i++) {
    if (rules.tier_from[i] <= passenger) tier = i
  }
  return tier
}

// Raisons de rejet (vide = plausible).
function gardeImplausible(run) {
  const r = gardeRules(run.garde_version)
  const reasons = []
  const correct = run.passengers - run.errors
  if (run.errors > r.max_errors) reasons.push("errors_above_max")
  if (run.errors > run.passengers) reasons.push("errors_above_passengers")
  if (run.passengers > r.max_passengers) reasons.push("passengers_above_max")
  if (correct >= 0 && run.score < correct) reasons.push("score_below_correct")
  if (run.score > r.max_points_per_correct * Math.max(correct, 0)) reasons.push("score_above_max")
  if (run.duration_s < r.min_seconds_per_passenger * run.passengers) reasons.push("too_fast")
  if (run.tier_max > tierFor(r, run.passengers + 1)) reasons.push("tier_above_passengers")
  if (run.directives > Math.floor(run.passengers / r.directive_every)) reasons.push("directives_above_passengers")
  return reasons
}

// Vrai si l'essai `a` bat l'essai `b` (score, puis erreurs, puis durée).
function gardeBetter(a, b) {
  if (a.score !== b.score) return a.score > b.score
  if (a.errors !== b.errors) return a.errors < b.errors
  return a.duration_s < b.duration_s
}

function gardeRow(rec) {
  return {
    seed_code: rec.getString("seed_code"),
    garde_version: rec.getInt("garde_version"),
    score: rec.getInt("score"),
    errors: rec.getInt("errors"),
    tier_max: rec.getInt("tier_max"),
    passengers: rec.getInt("passengers"),
    duration_s: rec.getInt("duration_s"),
    first_try: rec.getBool("first_try"),
    attempts: rec.getInt("attempts"),
    updated: rec.getString("updated"),
  }
}

function gardeRank(app, seed, version, score) {
  const row = new DynamicModel({ n: 0 })
  app.db().newQuery("SELECT COUNT(*) AS n FROM garde_scores WHERE seed_code = {:s} AND garde_version = {:v} AND score > {:sc}")
    .bind({ s: seed, v: version, sc: score }).one(row)
  return row.n + 1
}

function gardeTotal(app, seed, version) {
  const row = new DynamicModel({ n: 0 })
  app.db().newQuery("SELECT COUNT(*) AS n FROM garde_scores WHERE seed_code = {:s} AND garde_version = {:v}")
    .bind({ s: seed, v: version }).one(row)
  return row.n
}

// --- Fins -----------------------------------------------------------------------------------

function round1(x) {
  return Math.round(x * 10) / 10
}

function endingsAggregate(app) {
  const ttl = envInt("CLEARANCE_ENDINGS_CACHE_S", 300)
  const store = app.store()
  const cached = store.get(ENDINGS_CACHE_KEY)
  const now = nowMs()
  if (cached && ttl > 0 && now - Number(cached.at) < ttl * 1000) return cached.data

  const total = new DynamicModel({ n: 0 })
  app.db().newQuery("SELECT COUNT(DISTINCT user) AS n FROM ending_events").one(total)
  const perEnding = arrayOf(new DynamicModel({ ending_id: "", n: 0 }))
  app.db().newQuery("SELECT ending_id, COUNT(DISTINCT user) AS n FROM ending_events GROUP BY ending_id").all(perEnding)
  const perVariant = arrayOf(new DynamicModel({ ending_id: "", variant: "", n: 0 }))
  app.db().newQuery("SELECT ending_id, variant, COUNT(DISTINCT user) AS n FROM ending_events GROUP BY ending_id, variant").all(perVariant)

  const players = total.n
  const pct = (n) => (players > 0 ? round1((n * 100) / players) : 0)
  const endings = {}
  for (const row of perEnding) {
    endings[row.ending_id] = { players: row.n, percent: pct(row.n), variants: {} }
  }
  for (const row of perVariant) {
    if (!endings[row.ending_id]) continue
    endings[row.ending_id].variants[row.variant] = { players: row.n, percent: pct(row.n) }
  }
  const data = { players: players, generated_unix_ms: now, max_age_s: ttl, endings: endings }
  store.set(ENDINGS_CACHE_KEY, { at: now, data: data })
  return data
}

module.exports = {
  API_VERSION, LIMITS, RATES, OTP_MAX_FAILURES, SAVE_KINDS, ENDING_IDS, DIFFICULTIES, GARDE_RULES,
  GARDE_VERSION_MAX, ENDINGS_CACHE_KEY,
  fail, fieldError, authUser, env, envInt, nowMs, utf8Bytes, isInt, isPlainObject, body, query,
  rateCheck, rateLimited, clearUserState, randomTag, publicUser,
  kindFamily, saveKey, saveMeta, findSave, countSaves, cleanText, nonNegInt, dateMs,
  normalizeSeed, gardeRules, gardeImplausible, gardeBetter, gardeRow, gardeRank, gardeTotal,
  endingsAggregate,
}
