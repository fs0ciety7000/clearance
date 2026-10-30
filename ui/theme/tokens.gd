## CLEARANCE — Design tokens (source de vérité code).
## Miroir de DESIGN_SYSTEM.md. Constantes uniquement : aucune logique.
## Toute modification passe par la gouvernance (DESIGN_SYSTEM.md §12).
## Les valeurs de base (couleurs, familles de police) sont fixées par le contrat
## d'Orchestration ; seules les variantes dérivées peuvent évoluer ici.
class_name DS
extends RefCounted

# ---------------------------------------------------------------------------
# COULEURS — base (contrat, ne pas modifier)
# ---------------------------------------------------------------------------
const BG_VOID := Color("#07080C")
const BG_PANEL := Color("#0E1118")
const BG_ELEVATED := Color("#161B26")
const LINE_SUBTLE := Color("#232A38")

const TEXT_PRIMARY := Color("#E8F1F5")
const TEXT_SECONDARY := Color("#8A97A8")
const TEXT_MUTED := Color("#4E5868")

const ACCENT_CYAN := Color("#00E5FF")
const ACCENT_YELLOW := Color("#FFE600")
const ACCENT_MAGENTA := Color("#FF2E88")

const STATE_AMBER := Color("#FFA31A")
const STATE_RED := Color("#FF3B3B")
const STATE_GREEN := Color("#2EFF9A")

# ---------------------------------------------------------------------------
# COULEURS — dérivées (alpha). Suffixe = opacité en %.
# 08 = voile, 12 = fond sélection, 24 = fond actif/hover fort,
# 40 = bordure hologramme, 60 = glow, 80 = trait fort
# ---------------------------------------------------------------------------
const CYAN_08 := Color("#00E5FF14")
const CYAN_12 := Color("#00E5FF1F")
const CYAN_24 := Color("#00E5FF3D")
const CYAN_40 := Color("#00E5FF66")
const CYAN_60 := Color("#00E5FF99")
const CYAN_80 := Color("#00E5FFCC")

const YELLOW_12 := Color("#FFE6001F")
const YELLOW_24 := Color("#FFE6003D")
const YELLOW_60 := Color("#FFE60099")

const MAGENTA_12 := Color("#FF2E881F")
const MAGENTA_24 := Color("#FF2E883D")
const MAGENTA_60 := Color("#FF2E8899")

const AMBER_12 := Color("#FFA31A1F")
const AMBER_24 := Color("#FFA31A3D")
const AMBER_60 := Color("#FFA31A99")

const RED_12 := Color("#FF3B3B1F")
const RED_24 := Color("#FF3B3B3D")
const RED_60 := Color("#FF3B3B99")

const GREEN_12 := Color("#2EFF9A1F")
const GREEN_24 := Color("#2EFF9A3D")
const GREEN_60 := Color("#2EFF9A99")

# 0.3 — voix de l'Acte II (BriefingScreen, sous-titres) : teintes hors des
# familles sémantiques (ni état, ni marque) pour rester distinctes des voix
# existantes (Consortium jaune, Inspection ambre, Lucioles magenta, famille gris).
const VOICE_COMMISSION := Color("#8E9CFF") # bleu de registre : Commission de Rééquilibrage
const VOICE_COMMISSION_12 := Color("#8E9CFF1F")
const VOICE_BRULANTS := Color("#D9663F") # braise éteinte : Brûlants (encre noire)
const VOICE_BRULANTS_12 := Color("#D9663F1F")
const TEXT_ON_ACCENT := Color("#07080C") # texte sur fond jaune/cyan/vert/ambre plein
const SCRIM := Color("#07080CB8") # voile modal (72 %)
const DISABLED_FG := Color("#4E5868")
const DISABLED_BG := Color("#0E111880")
# 0.2 — surfaces posées sur la vue 3D (DS §5 règle 5 : voile ≥ 85 % derrière le texte)
const PANEL_VEIL := Color("#0E1118F2") # bg.panel 95 % : bulle, compteurs, toasts sur la vitre
const SUBTITLE_BG := Color("#07080CD9") # bg.void 85 % : sous-titres (UI_FLOW §4.8)
const INSPECTION_VEIL := Color("#07080C14") # bg.void 8 % : voile de la vue 3D en Mode Inspection

# ---------------------------------------------------------------------------
# TYPOGRAPHIE — familles (chemins prévus) et tailles en px @1080p
# ---------------------------------------------------------------------------
const FONT_DISPLAY_PATH := "res://assets/fonts/ChakraPetch-SemiBold.ttf"
const FONT_DISPLAY_BOLD_PATH := "res://assets/fonts/ChakraPetch-Bold.ttf"
const FONT_UI_PATH := "res://assets/fonts/Inter-Variable.ttf"
const FONT_MONO_PATH := "res://assets/fonts/JetBrainsMono-Variable.ttf"

const FS_DISPLAY_XL := 56 # écran titre, verdict de fin de journée
const FS_DISPLAY_L := 40 # titre d'écran, tampon
const FS_DISPLAY_M := 28 # titre de document holographique
const FS_TITLE := 20 # titre de panneau / RuleCard
const FS_BODY := 16 # texte courant UI, dialogues
const FS_BODY_S := 14 # texte secondaire, descriptions
const FS_LABEL := 12 # labels de champs (CAPITALES, tracking +8 %)
const FS_DATA := 16 # valeurs de champs (mono)
const FS_DATA_S := 14 # données denses (mono)
const FS_TIMER := 44 # horloge de service (mono)
const FS_CAPTION := 12 # mentions, légendes (taille minimale absolue)
const FS_SUBTITLE := 18 # sous-titres des barks (UI_FLOW §4.8) — 0.2
const FS_TIMER_COMPACT := 28 # horloge de la barre d'état 56 px (UI_FLOW §2.2) — 0.2
# M11 (D-085 rév.) — valeurs des documents posés sur le plan de travail : le
# plan les réduit (`Workbench.fit_scale` ≈ 0,75–0,95), elles partent donc plus
# grandes que `FS_DATA` et gardent un plancher physique propre au petit écran.
const FS_DATA_DOC := 18 # valeur d'un DocField de document (mono) @1080p
const DOC_VALUE_MIN_PHYSICAL := 13 # px physiques visés à l'échelle 1 (Steam Deck : 20 px logiques)

const LINE_HEIGHT_TIGHT := 1.1 # display
const LINE_HEIGHT_UI := 1.4 # UI / labels
const LINE_HEIGHT_READ := 1.5 # dialogues, règles

const TRACKING_DISPLAY := 0.02 # em
const TRACKING_LABEL := 0.08 # em, labels en capitales
const TRACKING_DATA := 0.0 # em

# ---------------------------------------------------------------------------
# ESPACEMENT — grille 4 px
# ---------------------------------------------------------------------------
const SPACE_0 := 0
const SPACE_1 := 4
const SPACE_2 := 8
const SPACE_3 := 12
const SPACE_4 := 16
const SPACE_5 := 20
const SPACE_6 := 24
const SPACE_8 := 32
const SPACE_10 := 40
const SPACE_12 := 48
const SPACE_16 := 64

# ---------------------------------------------------------------------------
# FORMES — chanfreins (angles coupés), bordures, cibles
# Le chanfrein est simulé dans StyleBoxFlat via corner_detail = 1.
# ---------------------------------------------------------------------------
const CHAMFER_S := 4 # champs, chips, boutons compacts
const CHAMFER_M := 8 # boutons, cartes
const CHAMFER_L := 16 # HoloDocument, panneaux majeurs
const CORNER_DETAIL_CHAMFER := 1

const BORDER_HAIRLINE := 1
const BORDER_DEFAULT := 1
const BORDER_STRONG := 2
const FOCUS_RING_WIDTH := 2
const FOCUS_RING_OFFSET := 2

const ICON_GRID := 24
const ICON_STROKE := 1.5
const ICON_S := 16
const ICON_M := 24
const ICON_L := 32

const HIT_TARGET_MIN := 40 # zone cliquable minimale @1080p

# ---------------------------------------------------------------------------
# ÉLÉVATION — glow (shadow_size de StyleBoxFlat), px
# ---------------------------------------------------------------------------
const GLOW_0 := 0
const GLOW_1 := 4 # hover
const GLOW_2 := 8 # focus / sélection
const GLOW_3 := 16 # alerte active, tampon à l'impact

# ---------------------------------------------------------------------------
# EFFETS HOLOGRAPHIQUES — intensités max (0..1) ; multipliées par le
# réglage d'accessibilité "Effets visuels" (100 % / 50 % / 0 %).
# ---------------------------------------------------------------------------
const FX_SCANLINE_ALPHA_MAX := 0.08
const FX_SCANLINE_PERIOD_PX := 3
const FX_FLICKER_AMPLITUDE_MAX := 0.06
const FX_FLICKER_HZ_MAX := 2.0 # jamais > 3 Hz (photosensibilité)
const FX_CHROMA_OFFSET_PX_MAX := 1.5
const FX_CHROMA_OFFSET_PX_GLITCH := 4.0 # pic bref (≤ 120 ms)
const FX_NOISE_ALPHA_MAX := 0.04
const FX_GLITCH_MAX_PER_MIN := 2

# ---------------------------------------------------------------------------
# MOTION — durées en secondes (Tween) et délais
# ---------------------------------------------------------------------------
const DUR_INSTANT := 0.08
const DUR_FAST := 0.16
const DUR_BASE := 0.24
const DUR_SLOW := 0.40
const DUR_DRAMATIC := 0.64 # verdict, fin de journée — rare
const STAGGER := 0.03 # décalage entre champs à l'apparition
const TOAST_HOLD := 4.0
const TIMER_WARN_SECONDS := 60
const TIMER_CRITICAL_SECONDS := 15
# 0.2 — rythmes du Mode Inspection et du poste (UI_FLOW §3.2, §3.5, §4.3, §4.10)
const STAMP_HOLD := 0.4 # maintien d'un tampon avant verdict
const DOC_STAGGER := 0.12 # décalage d'arrivée des documents par la fente
const CONCORDANT_HOLD := 1.2 # fil « CONCORDANT » avant dissolution
const INCOMPARABLE_HOLD := 0.6 # fil « INCOMPARABLE » avant rétraction
const NEXT_DEBOUNCE := 0.5 # anti-rebond du bouton « Suivant »
const PROMPT_INACTIVE_ALPHA := 0.3 # glyphe d'invite qui ne vaut pas en ce moment (Ⓐ de SUIVANT quand le focus est ailleurs)
const SKIP_HOLD := 1.0 # maintien de VUE (manette) qui passe une étape du tutoriel (QA-042)
const SUBTITLE_MIN_HOLD := 1.5 # durée mini d'un sous-titre
const SUBTITLE_PER_CHAR := 0.06 # + 60 ms par caractère
const DOC_ZOOM := 1.5 # zoom de lecture d'un document
const STAMP_TILT_MAX_DEG := 4.0 # rotation aléatoire de l'empreinte
const FX_LINK_DASH_SPEED := 20.0 # px/s, défilement des pointillés (≤ 20 px/s, DS §5)
# ---------------------------------------------------------------------------
# M12 « Rejouabilité » (DESIGN_SYSTEM 0.6) — rythmes et repères du Dossier
# ---------------------------------------------------------------------------
const DIRECTIVE_HOLD := 4.0 # carte « DIRECTIVE DE GARDE N° n » : au plus 4 s (M12 §2.2), passable
const EPILOGUE_OFFER_DELAY := 3.0 # écran de fin : « UN AN PLUS TARD » 3 s après le récit (M12 §1.10)
const GARDE_CODE_LENGTH := 6 # code libre de Garde (alphabet des N° ID, D-127) : largeur de saisie
# Couleurs d'origine du Dossier (initiales des personnages, M12 §5.1, Q16) :
# repères décoratifs, toujours doublés du code d'origine en texte (jamais la
# couleur seule) ; hors des familles d'état et de marque.
const FACTION_HAL := Color("#C9B98A") # Halcyon : laiton
const FACTION_TYC := Color("#C08A5E") # Tycho : rouille
const FACTION_TER := Color("#7FA7D6") # Terre : bleu
const FACTION_CER := Color("#8DBB9A") # Cérès : sauge
const FACTION_THR := Color("#C795C0") # Tharsis : mauve
const FACTION_DRV := Color("#8FB3B5") # Dérive : gris d'eau
const FACTION_NONE := Color("#8A97A8") # origine inconnue (= text.secondary)
# ---------------------------------------------------------------------------
# M13 « Gameplay » (DESIGN_SYSTEM 0.7) — journal à puces, portique, Économat
# ---------------------------------------------------------------------------
const JOURNAL_MAX_LINES := 8 # répliques gardées au journal de dialogue d'un cas (M13 §1.7)
const JOURNAL_VIEW_H := 196 # hauteur visible du journal (bulle du passager, bande B) @1080p ; défile au-delà
const STATEMENT_GLYPH := "»" # glyphe de déclaration devant une puce (jamais la couleur seule, D-107)
const SEARCH_PANEL_WIDTH := 640 # panneau du portique (bande B, à la place de la File ; le visage reste libre)
const SEARCH_SILHOUETTE_W := 120 # silhouette filaire des zones Z1–Z5
const BUSY_REDUCED_STEP := 0.25 # « Réduire les animations » : la barre d'attente avance par quarts, sans balayage
const HELP_CARD_WIDTH := 760 # carte d'aide M13 (déclarations J4, fouille J8), posée sur le plan de travail
