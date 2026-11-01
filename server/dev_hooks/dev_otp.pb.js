/// <reference path="../pb_data/types.d.ts" />
// CLEARANCE — mode dev OTP (docs/ONLINE.md §10). JAMAIS en production :
// - ce dossier n'est pas copié dans l'image Docker (server/Dockerfile) ;
// - tools/online_dev_server.sh le copie à côté des crochets du dépôt ;
// - en plus, rien n'est actif sans CLEARANCE_DEV_OTP=1.
// Aucun e-mail n'est envoyé : le code est journalisé et lisible par
// GET /api/clearance/dev/otp?otpId=… (tests d'intégration).

onMailerRecordOTPSend((e) => {
  if ($os.getenv("CLEARANCE_DEV_OTP") !== "1") return e.next()
  const otpId = String(e.meta["otpId"] || "")
  const code = String(e.meta["password"] || "")
  $app.store().set("clearance:devotp:" + otpId, code)
  console.log("[dev-otp] " + otpId + " " + code)
  // Pas de e.next() : l'e-mail n'est pas envoyé.
})

routerAdd("GET", "/api/clearance/dev/otp", (e) => {
  if ($os.getenv("CLEARANCE_DEV_OTP") !== "1") {
    return e.json(404, { status: 404, code: "not_found", message: "Not found.", data: {} })
  }
  const otpId = String(e.request.url.query().get("otpId") || "")
  const code = $app.store().get("clearance:devotp:" + otpId)
  if (!code) return e.json(404, { status: 404, code: "not_found", message: "No code for this otpId.", data: {} })
  return e.json(200, { otpId: otpId, code: String(code) })
})
