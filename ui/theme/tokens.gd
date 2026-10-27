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

const TEXT_ON_ACCENT := Color("#07080C") # texte sur fond jaune/cyan/vert/ambre plein
const SCRIM := Color("#07080CB8") # voile modal (72 %)
const DISABLED_FG := Color("#4E5868")
const DISABLED_BG := Color("#0E111880")

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
