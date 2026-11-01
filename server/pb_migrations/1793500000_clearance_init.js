/// <reference path="../pb_data/types.d.ts" />
// CLEARANCE M16 (lot S) — schéma initial. Contrat : docs/ONLINE.md §3.
// - `users` : OTP par e-mail seulement (mot de passe et OAuth désactivés),
//   champs `pseudo` (public, facultatif) et `tag` (public, fixé à la création),
//   création réservée à la demande de code (crochet), lecture/écriture de soi.
// - `saves`, `garde_scores`, `ending_events` : lecture de ses propres lignes
//   seulement ; aucune écriture par l'API standard (routes /api/clearance/*).

const OWN = "user = @request.auth.id"
const ID_PATTERN_TAG = "^[A-Z2-9]{4}$"

migrate((app) => {
  // --- users ---------------------------------------------------------------------------
  const users = app.findCollectionByNameOrId("users")
  for (const name of ["name", "avatar"]) {
    if (users.fields.getByName(name)) users.fields.removeByName(name)
  }
  users.fields.add(new TextField({
    name: "pseudo", max: 20, pattern: "^[\\p{L}\\p{N} _.'-]*$", required: false,
  }))
  users.fields.add(new TextField({
    name: "tag", max: 4, pattern: ID_PATTERN_TAG, required: false,
  }))
  users.listRule = "id = @request.auth.id"
  users.viewRule = "id = @request.auth.id"
  users.createRule = null
  users.updateRule = "id = @request.auth.id"
  users.deleteRule = "id = @request.auth.id"
  users.manageRule = null
  users.passwordAuth.enabled = false
  users.oauth2.enabled = false
  users.mfa.enabled = false
  users.authAlert.enabled = false
  users.otp.enabled = true
  users.otp.length = 6
  users.otp.duration = 600
  users.otp.emailTemplate.subject = "CLEARANCE — code {OTP}"
  users.otp.emailTemplate.body = [
    "<p>Code de connexion / Sign-in code :</p>",
    "<p style=\"font-size:24px;letter-spacing:4px\"><strong>{OTP}</strong></p>",
    "<p>Valable 10 minutes. Si vous n'avez rien demandé, ignorez ce message.<br/>",
    "Valid for 10 minutes. If you did not ask for it, ignore this message.</p>",
    "<p>— {APP_NAME}</p>",
  ].join("\n")
  users.authToken.duration = 30 * 24 * 3600
  app.save(users)

  // --- saves -------------------------------------------------------------------------------
  const saves = new Collection({
    type: "base",
    name: "saves",
    listRule: OWN,
    viewRule: OWN,
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [
      { type: "relation", name: "user", required: true, collectionId: users.id, cascadeDelete: true, maxSelect: 1 },
      { type: "number", name: "slot", min: 0, max: 3, onlyInt: true },
      { type: "text", name: "kind", required: true, max: 24, pattern: "^(demo_)?(current|meta|snapshot|profile)$" },
      { type: "number", name: "day", min: 0, max: 31, onlyInt: true },
      { type: "json", name: "payload", required: true, maxSize: 262144 },
      { type: "text", name: "game_version", max: 32 },
      { type: "number", name: "save_serial", min: 0, onlyInt: true },
      { type: "number", name: "saved_unix_ms", min: 0, onlyInt: true },
      { type: "text", name: "device", max: 32 },
      { type: "number", name: "rev", min: 0, onlyInt: true },
      { type: "number", name: "size", min: 0, onlyInt: true },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true },
    ],
    indexes: [
      "CREATE UNIQUE INDEX `idx_saves_key` ON `saves` (`user`, `slot`, `kind`, `day`)",
    ],
  })
  app.save(saves)

  // --- garde_scores --------------------------------------------------------------------------
  const garde = new Collection({
    type: "base",
    name: "garde_scores",
    listRule: OWN,
    viewRule: OWN,
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [
      { type: "relation", name: "user", required: true, collectionId: users.id, cascadeDelete: true, maxSelect: 1 },
      { type: "text", name: "seed_code", required: true, max: 15, pattern: "^(NUIT-\\d{4}-\\d{2}-\\d{2}|[A-HJ-NP-Z2-9]{3}-[A-HJ-NP-Z2-9]{3})$" },
      { type: "text", name: "kind", max: 8, pattern: "^(daily|free)$" },
      { type: "number", name: "garde_version", min: 1, max: 1000, onlyInt: true, required: true },
      { type: "number", name: "score", min: 0, onlyInt: true },
      { type: "number", name: "errors", min: 0, max: 3, onlyInt: true },
      { type: "number", name: "tier_max", min: 0, max: 4, onlyInt: true },
      { type: "number", name: "passengers", min: 0, max: 400, onlyInt: true },
      { type: "number", name: "directives", min: 0, onlyInt: true },
      { type: "number", name: "duration_s", min: 0, max: 86400, onlyInt: true },
      { type: "bool", name: "first_try" },
      { type: "text", name: "end_reason", max: 16 },
      { type: "text", name: "game_version", max: 32 },
      { type: "number", name: "attempts", min: 0, onlyInt: true },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
      { type: "autodate", name: "updated", onCreate: true, onUpdate: true },
    ],
    indexes: [
      "CREATE UNIQUE INDEX `idx_garde_best` ON `garde_scores` (`user`, `seed_code`, `garde_version`)",
      "CREATE INDEX `idx_garde_board` ON `garde_scores` (`seed_code`, `garde_version`, `score`)",
    ],
  })
  app.save(garde)

  // --- ending_events -----------------------------------------------------------------------------
  const endings = new Collection({
    type: "base",
    name: "ending_events",
    listRule: OWN,
    viewRule: OWN,
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [
      { type: "relation", name: "user", required: true, collectionId: users.id, cascadeDelete: true, maxSelect: 1 },
      { type: "text", name: "ending_id", required: true, max: 24, pattern: "^f(10|[1-9])_[a-z]+$" },
      { type: "text", name: "variant", max: 16, pattern: "^[a-z0-9_]*$" },
      { type: "number", name: "act", min: 1, max: 3, onlyInt: true, required: true },
      { type: "text", name: "difficulty", max: 8, pattern: "^(hard|story)$" },
      { type: "text", name: "game_version", max: 32 },
      { type: "autodate", name: "created", onCreate: true, onUpdate: false },
    ],
    indexes: [
      "CREATE UNIQUE INDEX `idx_ending_once` ON `ending_events` (`user`, `ending_id`, `variant`)",
      "CREATE INDEX `idx_ending_id` ON `ending_events` (`ending_id`)",
    ],
  })
  app.save(endings)
}, (app) => {
  for (const name of ["ending_events", "garde_scores", "saves"]) {
    try {
      app.delete(app.findCollectionByNameOrId(name))
    } catch (_) {}
  }
  const users = app.findCollectionByNameOrId("users")
  for (const name of ["pseudo", "tag"]) {
    if (users.fields.getByName(name)) users.fields.removeByName(name)
  }
  users.otp.enabled = false
  users.passwordAuth.enabled = true
  users.createRule = ""
  app.save(users)
})
