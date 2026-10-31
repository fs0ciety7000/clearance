# BOOTH_SCENE — Mise en scène du guichet et du passager

> Auteur : 3D Designer / Asset Lead · Statut : **proposition v0.1, à valider** (client, Orchestrateur, Godot Architect, UI/UX, Design System) · **M9 : décor définitif livré, voir §17** (les §6, §13 et §14 décrivent l'intention et le greybox ; §17 fait foi pour l'état réel).
> Périmètre : contenu visuel de `res://scenes/booth/booth.tscn` et de `res://scenes/passenger/passenger_actor.tscn` (rig, modèle, anims, visage, apparence). Le **code** de l'acteur et du guichet appartient au Godot Architect ; ce document fixe ce que le code doit piloter.
> Documents liés : [`DESIGN_SYSTEM.md`](../DESIGN_SYSTEM.md) (palette, §5 effets, §11 assets) · [`ARCHITECTURE.md`](ARCHITECTURE.md) (§3, §7 signaux) · [`UI_FLOW.md`](UI_FLOW.md) (§2 layout, §4 passager/vitre) · [`ASSETS.md`](ASSETS.md) (sources, pipeline, registre).
> Rappel D-007 : documents et Rulebook = **surcouche 2D**. Tout ce qui suit (vitre comprise) ne concerne que la **vue 3D, zone B** (y 56–432 px à 1080p).

---

## 0. Conventions

- Unités : **1 unité = 1 m**. Axe Y vers le haut.
- **Origine O** = centre de la vitre, au niveau du sol. **Côté agent : Z > 0** (caméra). **Côté passager : Z < 0** (hall, file, navettes). X vers la droite *vu par l'agent*.
- Orientation des personnages : convention Godot `MODEL_FRONT = +Z`. Un `Marker3D` à rotation nulle fait donc **face à la caméra**. `DeskMark` a une rotation nulle.
- Toutes les positions ci-dessous sont des **valeurs de départ à caler en greybox** ; seuls les **noms de nœuds** sont contractuels.

---

## 1. Résumé des choix

| Sujet | Choix | Pourquoi |
|---|---|---|
| Rendu 3D | `SubViewport` **1920×376** (zone B) sous la surcouche 2D | Les pixels 3D cachés par le plan de travail ne sont jamais calculés (~65 % d'économie). La vitre et le glow n'atteignent jamais l'UI. |
| Caméra | Fixe derrière l'agent, **FOV vertical 14°** (téléobjectif léger), à 2,6 m du passager | Cadrage buste à la Papers, Please, peu de déformation sur un format 5,1:1, tête ≈ 140 px (UI_FLOW §4.4 vise ~136 px). |
| Entrée du passager | Il **sort de derrière le pilier « HALCYON »** (à gauche du cadre) | Le changement « silhouette de file → acteur animé » se fait hors de vue, sans pop. |
| Sorties | Approuvé : à droite vers la porte de la station (sort du cadre en ~1,5 s). Refusé : demi-tour vers la file, derrière le pilier. | Lecture spatiale immédiate du verdict, rythme court. |
| Visage | **Plaque visage** (mesh fin sur l'os `Head`) + **atlas d'expressions par type de visage**, shader de dithering en espace UV | Moins cher que des blendshapes, pas de scintillement, cohérent avec la DA holo, compatible avec le rendu du portrait. |
| Regard | `LookAtModifier3D` (Godot 4.4+, cible 4.7.2) sur `Neck` (30 %) + `Head` (100 %), angles limités, + décalage des pupilles dans l'atlas | Présence forte pour un coût quasi nul. |
| Apparence | **Système modulaire combinatoire** (`PassengerAppearance`, slots du catalogue) piloté par `appearance_seed` + traits issus du gameplay (implants, âge) ; anti-répétition sur 15 passagers ; sosies/familles intentionnels (§12) | Demande client : chaque passager différent, ressemblances utiles au gameplay. |
| Portrait des documents | **Rendu `SubViewport` du même modèle 3D** par `PortraitRenderer` (option A, **acceptée**) | Comparaison Visage ↔ Photo juste par construction (§12.6). |
| Vitre | Shader unique `booth_glass.gdshader` : teinte, faux reflet, gouttes, salissures, condensation, **zone dégagée autour du visage** | Lisibilité garantie du visage, coût maîtrisé (pas de SSR sur transparents dans Godot). |

---

## 2. Plan vu de dessus

```
 Z (m)        X →   -3        -2        -1         0         +1        +2        +3
  -9.0   ┄┄┄┄┄┄┄┄┄┄┄┄┄┄ QUAI DES NAVETTES (fond, sous la pluie, au-delà de l'auvent) ┄┄┄┄┄┄┄┄┄┄┄┄┄┄
          ░ pluie ░  ░ pluie ░  ░ pluie ░   [écran départs]   ░ pluie ░   ░ pluie ░
  -7.0      F6 ·                                   ┌────────────┐
  -6.4   F5 ·      ╎ poteaux                       │ enseigne   │
  -5.6        F4 ·  ╎ à sangle (zigzag)             │ HALCYON    │ (grand néon jaune, fond)
  -4.8   F3 ·      ╎                               └────────────┘
  -4.2        F2 ·  ╎
  -3.3          Q ●╎ ← tête de file : début ArrivalPath, CACHÉ derrière le pilier
  -2.6   ExitRefused◄─[P]  pilier « HALCYON » (enseigne verticale jaune, 0,5 m)
              (fin, cachée)╲
  -2.0                    ╲ a1 (-0.9,-2.0)
  -1.4               r1 ◄──╲─ (-0.45,-1.4)
  -1.15             ✕ ClearMark (refusé) (-0.25,-1.15)
  -1.05                     ╲ a2 (-0.35,-1.05)
  -0.6                       ◎ DeskMark (0,-0.6) ──► ✕ e1 (0.7,-0.85) = ClearMark (approuvé) ──► e2 (1.5,-0.7) ──► [PORTE STATION] (2.3,-0.4)
                                                                                            │ e3 (2.8,+0.3) fin
   0.0   ════════[cadre]════════ VITRE x∈[-1.2;+1.2], y∈[1.0;2.4] ════════[cadre]═══════   ║ mur
                  (H) hygiaphone (-0.40, h 1.38)      ▣ fente (0, h 1.02)                  ║
                  LookTargetPlane (0, h 1.40, z 0)                                          ║
  +0.6           ▓▓▓▓▓▓▓▓ comptoir agent (h 0.95, hors champ) ▓▓▓▓▓▓▓▓                     ║
  +2.0                            [CAM] Camera3D (0, h 1.55)                               ║
```

| Nœud (contrat) | Type | Position (x, y, z) | Notes |
|---|---|---|---|
| `ArrivalPath` | `Path3D` | Q (-1.27, 0, -3.3) → a1 (-0.9, 0, -2.0) → a2 (-0.35, 0, -1.05) → (0, 0, -0.6) | ≈ 3,0 m. Q est **aligné caméra–pilier** : invisible depuis la caméra. Courbe douce (tangentes Bézier) pour éviter les pivots secs. |
| `DeskMark` | `Marker3D` | (0, 0, -0.6), rotation nulle (face +Z) | Pointe des pieds à 0,6 m de la vitre : le passager peut se pencher vers la fente sans traverser la vitre. |
| `ExitApprovedPath` | `Path3D` | (0, 0, -0.6) → e1 (0.7, 0, -0.85) → e2 (1.5, 0, -0.7) → porte (2.3, 0, -0.4) → e3 (2.8, 0, +0.3) | ≈ 3,3 m. Sort de la fenêtre utile à e1+0,3 m (~1,3 s après le départ). La porte de la station est dans le mur à droite du guichet, côté passager. |
| `ExitRefusedPath` | `Path3D` | (0, 0, -0.6) → r1 (-0.45, 0, -1.4) → (-1.0, 0, -2.4) → (-1.55, 0, -3.1) → (-2.6, 0, -4.5) | ≈ 4,4 m. **Demi-tour** (180°) puis retour vers la file/les navettes ; occulté par le pilier à ~2,8 m. |
| `ClearMark` (×2, enfant de chaque `Exit*Path`) | `Marker3D` | approuvé : e1 (0.7, 0, -0.85) ; refusé : (-0.25, 0, -1.15) | Point où le sortant **libère le guichet** (≈ 1 s après le début de `leave`) : `passenger_departed` y est émis, le suivant peut s'avancer ; le sortant finit sa sortie sans regard souris ni expressions. Placé pour que le sortant soit déjà hors de l'axe caméra–visage du `DeskMark`. |
| `LookTargetPlane` | `Marker3D` | (0, 1.40, 0) | Son plan XY local = plan de la vitre. ARCHITECTURE §8 bis.1 fixe « −Z local = normale vers l'agent » : avec notre repère (agent en +Z monde), le marqueur est donc **tourné de 180° autour de Y** (sans effet sur l'intersection rayon/plan). Rectangle de projection : ARCHITECTURE §8 bis.4 (±0,6 × ±0,4 m) ; proposition d'étendre le bas jusqu'au comptoir (§9.1). |
| *(proposé)* `QueueRoot` | `Node3D` | (-1.9, 0, -4.2) | Parent des silhouettes de file (MultiMesh). |
| *(proposé)* `CameraRig` | `Node3D` | (0, 1.55, 2.0) | Porte `Camera3D` ; parallax et travelling visage agissent sur le rig. |

---

## 3. Caméra

### 3.1 Valeurs

| Paramètre | Valeur | Commentaire |
|---|---|---|
| Position | (0, 1.55, 2.0) | Agent assis sur un tabouret haut derrière le comptoir. |
| Rotation | pitch 0°, yaw 0° | Visée quasi horizontale : met la tête au ~40 % supérieur de la bande. |
| Projection | Perspective, `keep_aspect = KEEP_HEIGHT` | Le FOV vertical reste constant si la bande change de hauteur (échelle UI). |
| `fov` | **14°** (vertical) | → FOV horizontal ≈ 64° sur 1920×376. |
| `near` / `far` | 0.05 / 40 | |
| Couverture au `DeskMark` (d = 2,6 m) | **0,64 m vertical** (y ≈ 1,23 → 1,87) × 3,26 m horizontal | Buste : de mi-poitrine au-dessus de la tête. |
| Couverture à la vitre (d = 2,0 m) | 0,49 m × 2,5 m | La vitre remplit tout le cadre ; ses montants tombent derrière les panneaux UI latéraux. |

### 3.2 Projections de contrôle (bande 1920×376, origine en haut de la bande)

| Point monde | Écran (x, y bande) | y écran 1080p | Lecture |
|---|---|---|---|
| Tête au DeskMark (0, 1.62, -0.6) | (960, 147) | ≈ 203 | Centre du visage — conforme à la maquette (≈ 205). |
| Hauteur de tête à l'écran | ≈ 140 px | | Plus grande que la photo d'identité (UI_FLOW §4.4). |
| Pilier HALCYON (-1.1, 2.0, -2.6) | x ≈ 511–677 | | Derrière la limite gauche de la fenêtre utile — conforme à la maquette (enseigne à x ≈ 600). |
| Hygiaphone (-0.40, 1.38, 0) | (654, ≈ 318) | ≈ 374 | En bas à gauche du visage, jamais devant. |
| Fente (0, 1.02, 0) | hors champ (sous la bande) | | La main du passager sort du cadre par le bas : le plan de travail 2D *est* le comptoir. |

**Fenêtre utile** (non couverte par la bulle à gauche et le panneau file à droite, cf. maquette) : **x 504–1416 × y 56–432**. Tout ce qui compte (visage, gestes, réactions) s'y trouve. Le reste de la bande montre du décor qui peut être masqué sans perte.

### 3.3 Cadreur automatique (tailles variables)
Les silhouettes vont de 1,55 m à 1,85 m (échelle §12.2). La caméra **tilte doucement** vers la tête du passager pendant la marche : `pitch_cible = atan((y_tête − 1,55) / 2,6)`, borné à **±2,5°**, interpolé sur 0,6 s (`ease.inout`). Hors marche, la caméra ne bouge pas. Désactivé avec « Réduire les animations » (pitch calé directement).

### 3.4 Travelling visage (UI_FLOW §4.9)
Sélection du champ « Visage » : **le FOV passe de 14° à 6,5°** en 0,4 s (`ease.snap`) + avance du rig de 0,3 m, visée recentrée sur l'os `Head`. Résultat : visage ≈ 300 px de haut. Sortie : retour en 0,3 s (`ease.out`). On ne traverse jamais la vitre (z rig ≥ 1,2). « Réduire les animations » : coupe franche.

### 3.5 Parallax souris (optionnel, recommandé en version très légère)
Décalage du `CameraRig` : **±2 cm en X, ±1 cm en Y** selon la souris normalisée, la caméra restant visée sur le point (0, 1.62, -0.6) ; lissage 0,5 s. **Amplitude divisée par 2 en Mode Inspection**, **0** en effets « Réduits/Désactivés » ou « Réduire les animations ». Effet visé : la vitre (reflets, gouttes) glisse légèrement par rapport au passager → profondeur.

---

## 4. La vitre

### 4.1 Ordre des calques (arrière → avant), conforme UI_FLOW §4.5
Ville, pluie, néons → file → **passager** → **vitre** (`booth_glass.gdshader`) → **cadre métal** (rivets, hygiaphone, fente) → UI 2D.

### 4.2 Matériau `booth_glass.gdshader` (spatial, `blend_mix`, `cull_disabled`, `depth_draw_never`, sans ombre)

| Couche | Réglage par défaut | Max | Règle |
|---|---|---|---|
| Teinte de base | `#8A97A8` α 0,04 | 0,06 | Presque invisible ; elle « pose » la vitre. |
| Faux reflet | texture `tex_glass_reflect_e` (intérieur du guichet flouté : lampe, lueur du plan holo, **silhouette de l'agent**) α 0,10, décalée par la parallax × 0,5 | 0,15 | Pas de SSR (Godot ne l'applique pas aux transparents) ; une texture peinte est plus contrôlable. Diagonale légère, couleurs désaturées. |
| Fresnel | bord +0,05 α | | Lisibilité de la matière quand la caméra bouge. |
| Gouttes / ruissellement | normal map `tex_glass_drops_n` (2 couches, l'une statique, l'autre qui glisse à 2 cm/s) → réfraction via `hint_screen_texture`, décalage ≤ 3 px | 4 px | **Exclues de la zone visage.** |
| Salissures / traces de doigts | `tex_glass_grime_m` α 0,08 ; densifiée autour de l'hygiaphone et de la fente | 0,12 | Récit : la vitre est un objet d'usage. |
| Condensation | dégradé du tiers bas, bruit lent | α 0,15 | Uniquement le tiers bas (sous le menton). |
| Scanlines | α 0,02, période 3 px | 0,03 | DS §5 (≤ 0,08) ; ici beaucoup plus bas car c'est une vitre, pas un hologramme. |

**Zone dégagée du visage** (règle absolue) : le script du guichet calcule chaque frame l'intersection du segment caméra → os `Head` avec le plan de la vitre et la passe en uniform `clear_point` (coordonnées locales de la vitre). Dans le shader : `m = smoothstep(0.12, 0.22, distance(uv_local, clear_point))` ; gouttes, salissures, condensation, reflet et scanlines sont multipliés par `mix(0.2, 1.0, m)`. Le visage est donc vu à travers ≤ 20 % des effets, la vitre reste perceptible autour.

**Effets réduits** (`fx_intensity` global du DS) : 0,5 → gouttes figées, réfraction ÷ 2 ; 0 → teinte + reflet α 0,05 uniquement.

### 4.3 Hygiaphone et fente (cadre métal, maillages opaques)
- **Hygiaphone** : disque perforé Ø 18 cm à (-0.40, 1.38, 0), alpha-scissor pour les trous, anneau LED : **cyan quand le passager parle**, **ambre quand l'intercom de l'agent est ouvert** (UI_FLOW §4.5). LED fixe (pas de clignotement) ; intensité émissive ≤ 1,5 pour ne pas déclencher le glow sur le visage.
- **Fente à documents** : tiroir métal sous la vitre (0, 1.02, 0), **hors champ** ; sa lueur cyan (aller et retour des documents) déborde dans le bas de la bande via une `OmniLight3D` courte portée (0,6 m) allumée 400 ms — visible sur le menton/les mains du passager penché.

---

## 5. Éclairage et « palette monde »

### 5.1 Conflit à arbitrer avec le Design System
Le DS (§1 principes 2 et 6) réserve **le cyan à l'information** et **le magenta à l'anomalie/la rébellion** ; UI_FLOW §2.3 demande une ambiance **désaturée, jamais au premier plan**. La demande « rim light cyan-magenta » et la maquette (enseigne TRANSIT·7 magenta) entrent donc en tension avec le DS.
**Proposition acceptée par l'Orchestrateur — ⚠ à valider Design System (DS-Proposal)** : une palette monde dérivée, désaturée, hors tokens sémantiques, réservée à la 3D :

| Token proposé | Hex | Usage 3D |
|---|---|---|
| `world.key` | `#E8F1F5` (= `text.primary`) | Lampe de guichet sur le visage |
| `world.teal.dim` | `#2B6E78` | Rim gauche, néons d'ambiance froids |
| `world.rose.dim` | `#7E3A5C` | Rim droit, néons d'ambiance chauds |
| `world.steel` | `#3A4556` | Fill, plafonniers du hall |
| `world.rain` | `#4E5868` (= `text.muted`) | Pluie, brume |
| `world.fog` | `#0E1118` (= `bg.panel`) | Brouillard de profondeur, fond |

**Les hex sémantiques purs ne sont autorisés en 3D que pour un sens** : jaune `#FFE600` = marque Consortium (enseignes HALCYON, uniformes du personnel) ; cyan = information (implants visibles — ce sont des données comparables avec le bio-scan —, LED hygiaphone, fente) ; vert/rouge = verdict (lumière de la porte au tampon) ; magenta = intrusion narrative (glitch rebelle sur un écran). L'enseigne « TRANSIT·7 » de la maquette passe en `world.rose.dim`.

### 5.2 Plan de feux

| Lumière | Type | Position / cible | Couleur | Énergie (départ) | Ombres |
|---|---|---|---|---|---|
| `KeyLight` (« lampe de guichet ») | `SpotLight3D` | (0.25, 2.3, 0.4) → tête au DeskMark, angle 22° | `world.key` | 3,0 | **Oui (seule lumière ombrée)** |
| `RimLeft` | `OmniLight3D` | (-0.9, 2.0, -1.8), portée 2,5 | `world.teal.dim` | 1,2 | Non |
| `RimRight` | `OmniLight3D` | (0.9, 2.0, -1.8), portée 2,5 | `world.rose.dim` | 1,2 | Non |
| `Fill` | `OmniLight3D` | (-1.5, 1.8, -1.0), portée 3 | `world.steel` | 0,4 | Non |
| `HalcyonSpill` | `OmniLight3D` | contre le pilier, portée 1,5 | jaune, saturation réduite | 0,5 | Non — éclaire le passager quand il sort de derrière le pilier |
| `SlotGlow` | `OmniLight3D` | (0, 1.05, -0.1), portée 0,6 | cyan | 0 → 0,8 pendant 400 ms | Non |
| `GateLight` | `OmniLight3D` | porte station, portée 2 | vert / rouge au verdict | impulsion 600 ms | Non — seul son débordement au sol est visible |

`WorldEnvironment` : fond `bg.void`, lumière ambiante `#161B26` × 0,3, **glow** activé (seuil HDR 1,0 : seuls les émissifs > 1 fleurissent), brouillard de profondeur `world.fog` (densité faible) pour détacher le passager du fond, tonemap AgX ou ACES (à tester), SSAO/SSR/SDFGI/volumétrique **désactivés**. Le shader personnage ajoute un rim de Fresnel bicolore (teal à gauche, rose à droite, cf. ASSETS §7) pour garantir la silhouette sur fond sombre même si les omni sont trop faibles.

**Règle de lisibilité du visage** : la `KeyLight` produit un rapport de luminance ≥ 3:1 entre le visage et le fond immédiat ; aucun émissif > 1,5 à moins de 25 cm du visage (implants compris) ; flicker des néons ≤ 2 Hz et **jamais dans la fenêtre utile**.

---

## 6. Décor

> État réel (M9) : §17 — la baie donne sur la ville de l'Anneau (pas de quai sous la pluie : la « pluie » est la condensation des conduites de recyclage, LORE §3) ; pas de `ReflectionProbe` ni de kit `.glb` importé, décor fusionné par outil.

| Élément | Position | Contenu | Coût |
|---|---|---|---|
| Hall de contrôle | Z ∈ [-9 ; 0] | Sol béton mouillé (roughness variable, flaques), plafond bas avec plafonniers `world.steel`, murs modulaires | Kit modulaire (ASSETS §2), 1 `ReflectionProbe` mise à jour une seule fois pour le sol |
| Pilier « HALCYON » | (-1.1, *, -2.6) | Enseigne verticale jaune Consortium (lettres émissives), affiches usées | Occulteur de la tête de file |
| File d'attente | zigzag de poteaux à sangle, X ∈ [-3 ; -1.3], Z ∈ [-7.2 ; -3.3] | 5–6 silhouettes « imposteurs » (§11), respirations désynchronisées | MultiMesh |
| Grand néon HALCYON + écran des départs | fond, Z ≈ -8 | Néon jaune (marque), écran des navettes en `world.teal.dim` (désaturé : décor, pas information) | Émissifs, pas de lumière réelle |
| Pluie | au-delà de l'auvent, Z < -7 | 3 nappes `rain_sheet.gdshader` (quads à streaks défilants, vitesses différentes) couleur `world.rain` | 3 draws |
| Porte de la station | (2.3, *, -0.4) | Portique / tourniquet, `GateLight` | Hors fenêtre utile |
| Côté agent (visible en reflet uniquement) | Z > 0 | Lampe, plan holo, silhouette de l'agent : **peints dans `tex_glass_reflect_e`**, pas modélisés | 0 |

---

## 7. Chorégraphie d'un cas

### 7.1 Signaux
Contrat ARCHITECTURE rév. 2 §7 / D-014. Le guichet (`BoothDirector`) est le seul nœud 3D qui parle à l'EventBus ; l'acteur n'émet que des signaux locaux (`arrived`, `anim_event`, `departed`…).

| Signal | Émis par | Moment dans la mise en scène |
|---|---|---|
| `case_presented(case)` | DayController | Appel du passager suivant |
| `day_phase_changed(phase, case_id)` | DayController | À chaque changement de phase (ARRIVING, INSPECTING, DEPARTING…) : pilote tampons et « Suivant » côté UI |
| `passenger_arrived(case_id)` | BoothDirector | Acteur calé sur `DeskMark` |
| `documents_presented(case_id)` | BoothDirector | Repère **`documents_slot`** à 0,75 s de `present_documents` ; **l'échelonnement de 120 ms entre documents est fait par l'UI** |
| `passenger_reaction_triggered(reaction: PassengerReaction.Kind)` | InspectionSession / dialogue | Réaction à jouer (`NERVOUS`, `ANGRY`, `SHRUG`, `RELIEVED`) |
| `case_resolved(id, result)` | DayController | Tampon → départ |
| `passenger_departed(case_id)` | BoothDirector | Acteur sorti de la fenêtre utile (§7.2) |

Note : nom unique `documents_slot`, repris dans ARCHITECTURE §8 bis.6.

### 7.2 Timeline nominale (t en secondes depuis l'appel « Suivant »)

| t | Événement | Passager | Scène / caméra | UI (pour info) |
|---|---|---|---|---|
| 0,00 | `case_presented(case)` + `day_phase_changed(ARRIVING)` | Acteur libre du pool (2 instances), apparence appliquée (`AppearanceApplier`, §12), posé sur `ArrivalPath` offset 0 (**caché derrière le pilier**), `idle` | Carillon intercom ; l'imposteur de tête est masqué, la file avance d'un cran (1,2 s, `ease.inout`) | Bark sous-titré, LED hygiaphone cyan |
| 0,00–0,20 | | Fondu `idle → walk` 0,2 s | | |
| 0,20–2,75 | ARRIVING | `walk` le long d'`ArrivalPath` (3,0 m à **1,15 m/s**, `speed_scale` = v / v_ref du clip) ; regard droit devant (regard souris inactif pendant la marche, ARCHITECTURE §8 bis.4) | Cadreur : tilt vers la tête (§3.3) | « EN APPROCHE » |
| ≈ 0,90 | | Émerge du pilier, entre dans la fenêtre utile, éclairé par `HalcyonSpill` | | |
| 2,75–3,10 | | Décélération, calage sur `DeskMark` (position + orientation, 0,2–0,3 s), fondu `walk → idle` 0,25 s | | |
| 3,10 | **`passenger_arrived(case_id)`** + `day_phase_changed(INSPECTING)` | `idle`, **contact visuel** avec l'agent (regard caméra), expression d'entrée | | |
| 3,40–4,60 | PRESENTING | `present_documents` (1,2 s) : 0,00–0,40 main dans la veste ; 0,40–0,75 se penche, la main sort du cadre par le bas ; **0,75 = repère `documents_slot`** ; 0,75–1,20 retrait | À **t = 4,15** : `SlotGlow` cyan 400 ms, son « clac » du tiroir | — |
| **4,15** | **`documents_presented(case_id)`** | (le clip continue) | `HoloEmitter` | Les documents émergent du haut du plan de travail, **échelonnés de 120 ms par l'UI** ; tampons et Inspection déverrouillés |
| 4,60 → V | INSPECTING | Retour en `idle` ; idle vivant (§8), regard souris (§9), `talk` pendant les répliques, réactions sur `passenger_reaction_triggered` (§10) | | |
| V + 0,00 | `case_resolved` + `day_phase_changed(DEPARTING)` | Réaction de verdict reçue via `passenger_reaction_triggered` (≤ 1,2 s, interruptible) : `ANGRY`/`NERVOUS`/`SHRUG` → clip ; `RELIEVED` → expression *soulagé* + hochement procédural (0,5 s) + voix (D-014) | Impulsion `GateLight` vert/rouge ; `SlotGlow` (documents rendus) | Tampon |
| V + 1,0–1,8 | DEPARTING | `leave` (one-shot ≈ 0,8 s : quart de tour à droite si approuvé, **demi-tour** si refusé, + premiers pas) puis `walk` sur `ExitApprovedPath` (1,2 m/s, `speed_scale` 1,1) ou `ExitRefusedPath` (1,0 m/s, `speed_scale` 0,9, tête basse) | | |
| ≈ V + 2,0 | **`passenger_departed(case_id)`** au **`ClearMark`** | Le sortant libère le guichet (≈ 1 s après le début de `leave`) ; il **finit sa sortie en parallèle, sans regard souris ni expressions** (regard influence 0, visage neutre figé) | | « Suivant » réactivé |
| V + 2,0 → fin | | **Chevauchement** : si le joueur appelle aussitôt, le 2ᵉ acteur du pool sort du pilier pendant que le sortant quitte le cadre (approuvé : hors fenêtre utile vers V + 2,6 ; refusé : caché par le pilier vers V + 4,1, sur une trajectoire qui ne croise pas `ArrivalPath` avant le pilier). En fin de path : acteur masqué et rendu au pool | | |

**Rythme visé** : de « Suivant » aux documents sur le plan **≈ 4,2 s** (marche 2,75 s ≤ 3–4 s du brief) ; du tampon à « Suivant » réactivé **≈ 2,0 s** (UI_FLOW).
**« Réduire les animations »** (valeurs ARCHITECTURE §8 bis.7) : vitesse de marche × 2,5, départ à 70 % d'`ArrivalPath` (arrivée ≤ 1,5 s), sortie coupée après 1 s (fondu), réactions réduites à l'expression ; `present_documents` conservé (lien diégétique), sans penchée de caméra.

### 7.3 Repères dans les clips (méthodes appelées par piste « Call Method »)
| Clip | Repère | Temps | Usage |
|---|---|---|---|
| `present_documents` | `documents_slot` | 0,75 s | → `documents_presented(case_id)` (verrouillé une fois par cas) |
| `walk`, `leave` | `footstep_l`, `footstep_r` | contacts des pieds | Sons de pas sur sol mouillé |
| `react_angry` | `glass_hit` (si le geste frappe la vitre/comptoir) | ≈ 0,45 s | Son sourd + micro-vibration de la vitre (désactivable) |

Garde-fous : watchdogs de BoothDirector et DayController (ARCHITECTURE §8 bis.6) ; si `documents_slot` manque, `documents_presented` est émis quand même. **Le gameplay n'attend jamais la 3D.**

---

## 8. Idle vivant et impatience

### 8.1 Couches toujours actives
- **Respiration** : incluse dans le clip `idle` (6–8 s, poitrine/épaules ±1 cm, transfert d'appui léger au milieu du cycle).
- **Clignements** : cellule « yeux fermés » de l'atlas pendant 120 ms, intervalle aléatoire 2–6 s (seedé).
- **Saccades** : micro-mouvements des pupilles ±1 texel toutes les 0,5–1,5 s quand le regard est stable.
- **Désynchronisation** : chaque acteur démarre `idle` à une phase aléatoire (seedée) et à `speed_scale` 0,95–1,05.

### 8.2 Paliers d'impatience (temps depuis `documents_presented`)
Purement **cosmétique** : n'influence jamais le score, n'est **pas** un timer par passager (UI_FLOW §1 : anti-stress), et **ne dépend jamais de la culpabilité** (UI_FLOW §4.6).

| Palier | Seuil (défaut) | Comportement |
|---|---|---|
| 0 · calme | 0–40 s | Regard suit la souris ~70 % du temps, clignements 3–5 s |
| 1 · s'agite | 40–80 s | Coups d'œil vers la file / l'horloge (30 % du temps), clignements 2–3 s, brève expression *suspicieux* |
| 2 · s'impatiente | 80–140 s | Soupir (`shrug` joué à 50 % de poids, si l'AnimationTree le permet, sinon expression *triste* + expiration), changements d'appui plus fréquents |
| 3 · agacé | > 140 s | **Une seule fois**, joué localement par l'acteur (aucun signal EventBus) : `react_nervous` ou `react_angry` selon tempérament + bark optionnel (« C'est encore long ? ») fourni par le Scénariste |

Seuils à placer dans une ressource réglable par le Game Designer (pas en dur). Désactivés si le timer est désactivé dans les options.

### 8.3 Tempérament
`temperament ∈ {calme, nerveux, colérique, désinvolte}` tiré de `appearance_seed` (ou imposé par un cas scénarisé). **Purement cosmétique** : il module l'idle (fréquence des coups d'œil, palier 3 de l'impatience, état `AVOID` du regard) et l'intensité des expressions. Il ne choisit **jamais** la réaction logique : celle-ci arrive par `passenger_reaction_triggered(PassengerReaction.Kind)`, décidée par InspectionSession/dialogue (UI_FLOW §4.7). Un innocent peut être nerveux, un fraudeur calme.

---

## 9. Regard

### 9.1 Mécanique
- Deux `LookAtModifier3D` (Godot 4.4+, cible 4.7.2) enfants du `Skeleton3D` : `Neck` (influence 0,3) et `Head` (influence 1,0), cible commune = un `Marker3D` `LookTarget` déplacé par le script. Angles limités : **lacet ±40°, tangage −25° / +15°**, `duration` 0,25 s, transition `ease.out`. *(Noms exacts des propriétés à vérifier dans la doc 4.7 : `target_node`, `bone_name`, `forward_axis`, `use_angle_limitation`, `primary_limit_angle`, `secondary_limit_angle`, `duration`…)*
- **Pupilles** : décalage UV dans l'atlas (±2 texels) proportionnel à l'angle restant → les yeux « finissent » le mouvement que la tête ne fait pas.
- Projection de la souris (calculée par `BoothDirector`, ARCHITECTURE §8 bis.4) : rayon caméra → plan de `LookTargetPlane`. Une souris **sous la bande 3D** (plan de travail) donne un rayon qui tombe sous la vitre : on borne y à 0,85 m (comptoir) → le passager **baisse les yeux vers ses papiers**, exactement l'effet voulu par UI_FLOW §4.6. Souris sur le visage (ou champ « Visage » survolé) → **contact visuel** (cible = caméra).
- Manette : la cible suit le document ou le champ focalisé (position écran → même projection).

### 9.2 États
| État | Cible | Influence | Entrée |
|---|---|---|---|
| `FOLLOW` | souris projetée (retard 0,3 s) | 1,0 au guichet ; **0 pendant `walk`, `present_documents`, `leave`** (tween 0,2 s, ARCHITECTURE §8 bis.4) | défaut |
| `GLANCE` | point d'intérêt (file, horloge, tiroir à tampons si la souris s'en approche) | 1,0 pendant 0,4–0,8 s | aléatoire selon palier §8.2 |
| `AVOID` | latéral bas | 0,8 | souris fixée sur le visage > 3 s **et** tempérament nerveux (gêne), 1,5 s |
| `DOWN` | comptoir | 0,7 | Mode Inspection activé, document déplacé |
| `REACT` | — | 0,3 | pendant une réaction one-shot (l'anim gère la tête) |
| `OFF` | — | 0 | option « Regard du passager : fixe » ; **sortant après le `ClearMark`** (plus de regard souris ni d'expressions) |

---

## 10. Réactions et micro-expressions

### 10.1 Clips (AnimationLibrary `passenger`, noms exacts)
| Clip | Type | Durée cible | Pose de fin | Notes |
|---|---|---|---|---|
| `walk` | boucle | cycle ≈ 1,05 s | — | En place (pas de root motion), v_ref ≈ 1,15 m/s |
| `idle` | boucle | 6–8 s | = début | Respiration + transfert d'appui |
| `present_documents` | one-shot | 1,2 s | = `idle` | Repère `documents_slot` à 0,75 s |
| `leave` | one-shot | ≈ 0,8 s | = début de `walk` | Quart de tour / **demi-tour** + premiers pas, puis enchaînement automatique sur `walk` (ARCHITECTURE §8 bis.3). L'attitude de sortie (tête basse, pas plus lent si refusé) vient du `speed_scale`, du regard et de l'expression |
| `react_angry` | one-shot | 1,0–1,4 s | = `idle` | Buste en avant, mains sur le comptoir (UI_FLOW) |
| `react_nervous` | one-shot | 1,0–1,5 s | = `idle` | Regard fuyant, main à la nuque |
| `shrug` | one-shot | 0,8–1,0 s | = `idle` | |
| `talk` | boucle | 2–3 s | — | **Haut du corps uniquement** (filtre colonne + bras + tête dans l'`AnimationTree`), faible amplitude |

Fondus : `idle↔walk` 0,25 s · vers one-shot 0,10 s · retour 0,25 s. **RELIEVED** (D-014) : pas de clip au MVP → expression *soulagé* + hochement procédural (tête, 0,5 s) + voix. `react_relieved` reste une option post-MVP.

Correspondance `PassengerReaction.Kind` → rendu : `NERVOUS` → `react_nervous` + *nerveux* · `ANGRY` → `react_angry` + *colère* · `SHRUG` → `shrug` + *neutre* · `RELIEVED` → hochement procédural + *soulagé*.

### 10.2 Déclencheurs (rappel, la logique décide)
| Événement | Réaction corps | Expression | Garde-fou |
|---|---|---|---|
| Discordance confrontée en interrogatoire | selon le `Kind` reçu | *nerveux* / *colère* | cooldown 6 s entre deux one-shots ; reçu pendant la marche → mis en file (1 max) |
| Concordance (le joueur s'est trompé) | — | *suspicieux* 1,5 s | |
| Question absurde / déjà expliquée | `shrug` | *neutre* | |
| Réplique | `talk` (couche) | bouche synchronisée sur l'apparition des mots (40 ms/mot, DS §7.10) | |
| Verdict refusé | selon le `Kind` reçu (`ANGRY`/`NERVOUS`/`SHRUG`) | *colère* / *triste* | |
| Verdict approuvé | `RELIEVED` : hochement procédural | *soulagé* | |
| Contact rebelle scénarisé | — | **clin d'œil** | réservé au narratif, jamais aléatoire |

### 10.3 Atlas d'expressions (par type de visage)
Une texture `tex_face_<type>_atlas.png` **512×512**, grille 4×4 de cellules 128×128 (canaux : R = encre/luminance, G = masque iris, B = masque ombrage peau, A = alpha) :

| Ligne | Cellules |
|---|---|
| 0 — yeux + sourcils | neutre · nerveux (yeux écarquillés, sourcils relevés au centre) · colère (sourcils froncés) · soulagé (paupières mi-closes, arc doux) |
| 1 — yeux + sourcils | suspicieux (un sourcil levé, yeux plissés) · triste (sourcils en accent circonflexe) · clin d'œil · **fermés** (clignement) |
| 2 — bouches | neutre · serrée · ouverte A (parole) · ouverte O (parole) |
| 3 — bouches | sourire bref · grimace (nerveux) · moue (triste) · dents serrées (colère) |

Pupilles : petit sprite commun (zone réservée dans l'atlas « overlay », ASSETS §6) dessiné par-dessus avec décalage UV. Une **expression** = (cellule yeux, cellule bouche) :

| Expression | Id (`ExpressionController`, ARCHITECTURE §8 bis.5) | Yeux | Bouche |
|---|---|---|---|
| neutre | `neutral` | neutre | neutre |
| nerveux | `nervous` | nerveux | grimace (alternance serrée, < 3 Hz) |
| colère | `angry` | colère | dents serrées |
| soulagé | `relieved` | soulagé | sourire bref |
| suspicieux | `suspicious` | suspicieux | serrée |
| triste | `sad` | triste | moue |
| mépris (micro-expression) | `contempt` | suspicieux | sourire bref, moitié masquée (rictus asymétrique) |
| clin d'œil | `wink` *(à ajouter à la liste d'ARCHITECTURE)* | clin d'œil | sourire bref |
| clignement | `blink` | fermés | (inchangée) |
| parole | `talk_a` / `talk_b` | (inchangés) | ouverte A / ouverte O |

Rendu : shader `face_dither.gdshader` — **dithering ordonné Bayer 4×4 en espace UV** quantifié à 64×64 par cellule (stable quand la tête bouge, pas de scintillement écran), 3 tons teintés par la couleur de peau ; **transition entre expressions = fondu par seuil de dither en 120 ms**. « Réduire les animations » : transitions instantanées, pas d'alternance nerveuse (expression fixe, UI_FLOW).

---

## 11. Silhouettes de file (imposteurs)

- 5–6 instances, **1 `MultiMeshInstance3D` par silhouette** (≤ 4 draws), maillage = silhouette de base décimée **≤ 400 tris**, sans squelette.
- `impostor_silhouette.gdshader` : unlit, remplissage sombre (`bg.elevated` assombri) teinté par la couleur dominante de la tenue (`INSTANCE_CUSTOM`), rim `world.teal.dim`/`world.rose.dim`, balancement de vertex ±1 cm à 0,2 Hz, phase aléatoire par instance.
- Lisibilité : ce sont des **formes** (silhouette + capuche/visière en option), pas des personnes reconnaissables. Pas de visage.
- Avance de file : translation d'un cran le long du zigzag en 1,2 s quand le passager actif quitte la tête de file.

---

## 12. Système d'apparence modulaire

### 12.1 Principe (modèle ARCHITECTURE rév. 2 §5.3, §8 bis.5, §9.3)
- Une apparence est une **`PassengerAppearance`** : `traits` (slot → id d'option), `palette_id`, `height_step` (−2..+2, ±3 % d'échelle par pas), `age_band`. Elle ne contient **que des identifiants** ; les références visuelles (maillage, cellule d'atlas, matériau) sont dans les `AppearanceOptionDef` du catalogue `data/appearance/appearance_catalog.tres` (contenu fourni par l'Asset Lead, cf. ASSETS §6).
- Elle est produite par `AppearanceGenerator` (roster du jour, déterministe depuis `day_seed`), appliquée à l'acteur par **`AppearanceApplier`** (meshes par slot, échelle, palette en `instance uniform`) et rendue en photo par **`PortraitRenderer`** avec **le même `AppearanceApplier`** (§12.6).
- L'acteur affiche toujours l'apparence réelle (`case.passenger_presented.appearance`) ; seules les `PortraitValue` des documents peuvent différer (anomalies).
- Chaque slot porte deux drapeaux (`AppearanceSlotDef`) : **`identity`** (trait de la personne : stable, comparable, peut produire une DISCORDANCE) vs trait changeable (tenue, coiffe, accessoire : bruit volontaire, note grise de UI_FLOW §4.9), et **`visible_in_portrait`**. `FaceComparator` ne compare que les slots `identity && visible_in_portrait`.

### 12.2 Slots et options (MVP)

Slots définis par ARCHITECTURE : `silhouette, face, eyes, nose_mouth, hair, headwear, skin, outfit, accessory, palette` (+ champs `height_step`, `age_band`). Les lignes marquées **(proposé)** sont des slots supplémentaires soumis au Godot Architect.

| Slot | Options MVP | `identity` | Rendu (`AppearanceOptionDef`) |
|---|---|---|---|
| `silhouette` | 4 : **S1 trapu** · **S2 élancé** · **S3 moyen** · **S4 menu** | oui | maillage corps (sans tête) |
| `height_step` (champ) | −2..+2 → échelle 0,94–1,06 (1,55–1,85 m) | oui | échelle du `Visual` ; `speed_scale` de marche ∝ 1/échelle (pas de patinage) |
| `face` | 4 formes : rond · carré · ovale · anguleux — **chacune avec son atlas d'expressions** ; les oreilles (3 formes) sont des variantes de `face` (4 × 3 = 12 options) | oui | maillage tête + oreilles + atlas |
| `eyes` | 6 couleurs (brun, noisette, vert, bleu, gris, hétérochromie rare) | oui | teinte du masque iris de l'atlas |
| `nose_mouth` | 3 nez × 2 lèvres = 6 | oui | petit maillage nez + variante de cellule bouche |
| `skin` | 8 (rampe) | oui | uniform |
| `age_band` (champ) | 3 : jeune (18–30) · adulte (30–55) · âgé (55+) — cohérent avec la date de naissance | oui | calque rides de l'atlas overlay + gris dans les cheveux + `idle` à 0,9 pour âgé |
| `marks` **(proposé)** | 6 cicatrices/tatouages encre (+ aucun) | oui | décal atlas |
| `implants` **(proposé)** | 4 types visibles (oculaire, shunt temporal, plaque mandibulaire, port cervical) | oui | **imposé par les données de gameplay (bio-scan), jamais tiré au hasard** ; émissif cyan = donnée comparable avec le bio-scan |
| `hair` | 7 coupes (dont rasé) × 10 couleurs (6 naturelles + 4 teintures désaturées) | non | maillage + uniform |
| `facial_hair` **(proposé)** | 4 (aucune, courte, moustache, longue) | non | calque atlas overlay |
| `headwear` | 4 (aucune, capuche, casquette, bonnet) — masque `hair` | non | maillage (capuche = variante de tenue) |
| `outfit` | 2 par silhouette (8 maillages) | non | maillage corps habillé, zones par couleurs de sommets |
| `palette` | 12 palettes de 3 couleurs (haut, bas, accent), désaturées | non | `instance uniform` |
| `accessory` | visière (bandeau translucide, demi-visière — **≤ 40 % d'opacité**, yeux visibles) · masque respiratoire (au cou, filtre latéral — **jamais sur la bouche au guichet**) · tatouage holo (4, projeté donc amovible : « non biométrique ») · combinaisons ≤ 2 → ~20 options | non | maillages / décal émissif désaturé |

Les couleurs de tenue évitent les **teintes sémantiques saturées** (vert/rouge/ambre/cyan/magenta purs) ; le jaune Consortium est réservé aux uniformes du personnel (cas scénarisés).

### 12.3 Nombre de combinaisons (estimation)
- **Identité** : 4 silhouettes × 5 tailles × 12 visages/oreilles × 6 yeux × 6 nez/bouche × 8 peaux × 3 âges × 7 marques ≈ **1,5 × 10⁶** (hors implants, imposés par le gameplay).
- **Habillage changeable** : (70 coupes/couleurs + 3 coiffes) × 4 pilosités × 2 tenues × 12 palettes × ~20 accessoires ≈ **1,4 × 10⁵**.
- **Théorique** : ≈ **2 × 10¹¹**.
- **Perceptuellement distinctes au premier coup d'œil** (silhouette × tenue/palette × tête/coiffe × peau en 4 groupes × accessoire dominant) : 4 × 24 × ~30 × 4 × ~10 ≈ **10⁵**. Un shift fait 14–30 passagers, une partie quelques centaines : la marge est large, la vraie contrainte est l'anti-répétition **locale**.

### 12.4 Anti-répétition (fenêtre glissante)
Règle d'ARCHITECTURE §9.3 : roster calculé au `day_started` depuis `day_seed`, fenêtre `window_size` = **15**, rejet si `distance(candidat, précédent) < min_distance` (nombre de slots différents), 12 essais max puis le candidat le plus éloigné ; les `appearance_overrides` des cas scénarisés sont posés d'abord.

Recommandations d'Asset Lead (réglage du catalogue, à valider avec le Godot Architect) :
- **Calibrer `min_distance` sur la demande client** « ressemblances naturelles = 2–3 traits en commun » : avec ~12 slots, cela correspond à `min_distance ≈ 8–9`, et non 3 (qui laisse partager jusqu'à 7 traits sur 10).
- **Signature de premier coup d'œil** (silhouette, outfit, palette, headwear-ou-hair) jamais identique dans la fenêtre : c'est ce que le joueur remarque en premier.
- Le roster étant par jour, le 1ᵉʳ passager d'un jour peut ressembler au dernier de la veille : acceptable (nuit de sommeil entre les deux).

### 12.5 Ressemblances intentionnelles (anomalies d'ARCHITECTURE §9.3)
| Anomalie | Construction | Détectable par | Jour conseillé |
|---|---|---|---|
| `PORTRAIT_MISMATCH` | `PortraitValue.appearance` = apparence tirée à distance ≥ 3 du porteur | Visage ↔ Photo | dès l'introduction du champ Visage |
| `IMPOSTOR_LOOKALIKE` (sosie / usurpation) | `passenger.appearance.derive(...)` avec **1–2 slots d'identité visibles modifiés** (yeux, nez/bouche, oreilles via `face`, marque, implant) + éventuellement du bruit changeable (autre coupe) pour la vraisemblance | Visage ↔ Photo (discordance nommée sur le trait) | milieu de partie |
| `RELATIVE_DOCUMENTS` (papiers d'un parent, 🟡 optionnel MVP) | `derive()` « familial » : garde silhouette, peau et 1 trait de visage, change ≥ 2 traits d'identité, `age_band` ±2 | Visage ↔ Photo, Visage ↔ Né(e) le | milieu/fin de partie |
| Jumeaux **(proposition post-MVP)** | Identité identique sauf **1 marque ou 1 implant** | Visage ↔ Photo ou Implants déclarés | fin de partie, rare |
| Ressemblance naturelle (fausse piste) | Résultat du tirage | Rien : l'outil répond CONCORDANT (jamais de faux positif) | partout |

La comparaison s'appuie sur les **identifiants de traits** (`FaceComparator`), jamais sur des pixels : l'outil reste exact par construction.

### 12.6 Portrait des documents (option A, acceptée)
`PortraitRenderer` (scène `portrait_studio.tscn`, `SubViewport` **256×320**, `UPDATE_ONCE`) rend la `PortraitValue` d'un champ PORTRAIT avec **le même `AppearanceApplier`** que l'acteur. Exigences visuelles de l'Asset Lead :
- Caméra portrait : FOV vertical ≈ 18°, cadrage épaules → haut du crâne, **ligne des yeux à hauteur fixe** (alignement du comparateur UI_FLOW §4.9).
- Éclairage studio plat (une key douce de face + fill), fond uni, **pas de rim néon** ; expression `neutral`, sans accessoire `accessory` (règle de photo officielle) ; `headwear` retiré.
- `photo_seed` : léger angle (±3°), température d'éclairage, grain ; `years_before_issue` : bruit légitime (coupe différente, `age_band` −1 au plus) — jamais un slot d'identité.
- Filtre « photo » appliqué en 2D après rendu (holo/dither du DS), jamais dans le studio 3D.
- Coût : 1 rendu par document (~1–2 ms) pendant la marche ; shaders préchauffés à l'intro du jour ; cache par jour (ARCHITECTURE).

---

## 13. Budgets de performance

Cible proposée (à confirmer) : 1080p60 sur GPU d'entrée de gamme récent (classe GTX 1650 / Steam Deck en 800p).

| Poste | Budget |
|---|---|
| Passager actif (corps + tête + cheveux + accessoires + plaque visage) | **≤ 8 k triangles**, **≤ 5 matériaux** (corps toon, accessoires, visage, implants émissifs, cheveux) ; squelette humanoïde sans doigts (~25 os ; 65 max) |
| Acteurs animés simultanés | **2 au maximum** (pool de 2, accepté par l'Orchestrateur) : le sortant finit sa sortie après le `ClearMark` (sans regard ni expressions, `AnimationTree` seul) pendant que le suivant arrive ; le reste de la file en imposteurs |
| Acteur portrait | 1, instancié uniquement pendant le rendu |
| File | 5–6 imposteurs ≤ 400 tris, ≤ 4 draws |
| Guichet (vitre, cadre, hygiaphone) | ≤ 10 k tris, ≤ 6 draws |
| Hall + décor | ≤ 40 k tris, ≤ 20 draws (atlas de textures partagés) |
| Pluie | 3 quads, 1 matériau |
| **Total scène** | **≤ 70 k tris, ≤ 40 draws**, 1 lumière ombrée (atlas d'ombres 2048) + ≤ 6 omni — M9 : décor 7 draws / ≈ 31 k tris, 9 omni (§17.3) ; M10 : passager 4 draws (§18) |
| Textures 3D (VRAM) | ≤ 96 Mo |
| Temps GPU de la bande 3D | ≤ 3 ms |
| Post-process | glow + brouillard de profondeur ; MSAA 2× dans le SubViewport ; pas de SSAO/SSR/SDFGI/volumétrique/TAA |

---

## 14. Version greybox (jalon M4)

Objectif : **code définitif, contenu provisoire** — tous les noms de nœuds, de clips et de signaux sont déjà ceux du contrat.

| Élément | Greybox |
|---|---|
| `booth.tscn` | Paths et markers **aux positions finales** ; pilier, comptoir, cadre de vitre en `CSGBox3D` ; vitre = `StandardMaterial3D` transparent α 0,06 (pas de gouttes) ; `KeyLight` + `RimLeft` + `RimRight` ; `WorldEnvironment` minimal ; caméra aux valeurs finales (dont travelling visage) |
| `passenger_actor.tscn` | Personnage Kenney CC0 brut (une silhouette, skin d'origine) ; **les 8 clips existent** dans la bibliothèque `passenger` : `walk`/`idle` réels (sources CC0), les autres en clips simples faits dans Godot (penchée, secousse, haussement de 0,8 s) ; plaque visage avec atlas provisoire 2 tons (7 expressions + clignement) |
| Apparence | 2 teintes de peau × 3 palettes × 2 accessoires, pilotés par `appearance_seed` — suffit à tester le pipeline |
| Portrait | `PortraitRenderer` déjà branché (option A), studio minimal |
| File | 3 capsules immobiles |
| Regard | `LookAtModifier3D` sur la tête, état `FOLLOW` seulement |

**Terminé quand** : marche ≤ 3 s jusqu'au `DeskMark` ; le repère `documents_slot` déclenche l'arrivée des documents ; le regard suit la souris (et baisse les yeux sur le plan de travail) ; les deux sorties fonctionnent ; `passenger_departed` réactive « Suivant » ; 60 fps stables ; aucune UI ne recouvre le visage.

---

## 15. Arbitrages acquis et questions restantes

**Acquis (Orchestrateur)** : signaux ARCHITECTURE rév. 2 / D-014 (`document_handed` supprimé) · RELIEVED sans clip au MVP (D-014) · pool de 2 `PassengerActor` avec `ClearMark` · portrait option A via `PortraitRenderer` / `PortraitValue` / `PassengerAppearance` · animations Quaternius UAL (CC0) d'abord, Mixamo en complément.

**À valider** :
1. **Palette monde** (§5.1) : teintes 3D désaturées hors tokens sémantiques pour les rims et néons — proposition acceptée par l'Orchestrateur, **à valider Design System**.
2. **Repère `documents_slot`** : ✅ harmonisé dans ARCHITECTURE. `leave` en one-shot de transition (aligné sur ARCHITECTURE §8 bis.3) ; ajout de l'expression `wink`.
3. **Slots proposés** (§12.2) : `marks`, `implants`, `facial_hair` ; oreilles comme variantes de `face` ; implants et `age_band` imposés par les données de gameplay → Godot Architect / Gameplay Systems ; correspondance types d'implants ↔ classes du Lore (OPT, NX, MIL…) → Lore Master.
4. **`min_distance`** : ✅ arbitré à 5 sur 10 slots dans ARCHITECTURE (deux passagers proches partagent au plus la moitié des traits) ; à recalibrer si le catalogue passe aux 17 axes de §12 (≈ 8–9).
5. **`LookTargetPlane`** : orientation (−Z vers l'agent = rotation 180° dans notre repère) et extension du rectangle vers le comptoir pour le regard « baisse les yeux » (UI_FLOW §4.6).
6. **Durée de marche** : ✅ harmonisée : ≤ 3–4 s (≈ 2,75 s ici), ARCHITECTURE mis à jour.
7. **Plateforme cible** pour les budgets (§13) : PC entrée de gamme ? Steam Deck ?
8. Masques et visières **non couvrants** au guichet (visage toujours comparable) : OK client, ou geste « retire sa visière » (clip supplémentaire) ?

---

## 16. Implémenté en M6 — passager final (2026-10-27, 3D Designer / Godot Architect)

Captures réelles (xvfb, `opengl3`) : `docs/mockups/m6_walk.png`, `m6_desk.png`, `m6_visor_down.png`, `m6_visor_up.png`, `m6_react_angry.png`, `m6_leave_queue.png`, `m6_lineup.png` (8 passagers), `m6_portraits.png` (8 photos), `m6_day3_autoplay.png` (jeu complet). Scène de démo : `scenes/passenger/passenger_demo.tscn` (`-- --mode=booth|lineup|portraits --state=desk|visor_down|visor_up|react|nervous|shrug|leave|empty --shot=… --at=… --fps`).

| Sujet | Réalisé | Écart / remarque |
|---|---|---|
| Modèle | Kenney `characterMedium` (1 604 tris) **retargeté** (`SkeletonProfileHumanoid`), échelle 0,58, **tête réduite ×0,45 et cou raccourci ×0,55** (`HeadScaleModifier`, réappliqué chaque frame après l'animation) : ≈ 1,75 m, centre de tête ≈ 1,57–1,62 m au `DeskMark` | Pas de tête/tenue modélisées dans Blender (§6.1) : la variété vient des 8 skins Kenney converties en cartes de zones + pièces low-poly en code |
| Clips | 9 clips (ASSETS §5.4), UAL + couches procédurales, repères posés par outil | `idle` 2,5 s (pas 6–8 s) |
| Matériau | `chr_toon.gdshader` : zones (peau, haut, bas, accent « chrome usé », chaussures, cheveux) × détail de la skin d'origine (usure, imprimés), toon, rim Fresnel teal/rose désaturé | Palettes relevées en valeur (plafond de saturation 0,34) : la DS reste désaturée |
| Visage | Plaque d'atlas ditheré existante ancrée sur l'os `Head` (`HeadAttachment/Head`, repère en mètres) ; formes de visage = échelle de l'os `Head` ; oreilles, nez, lèvres, yeux par pièces/uniformes | Pas d'atlas par type de tête (un atlas commun) |
| Visière | Bandeau fixe + écran articulé : baissée = yeux masqués (lisible : écran noir + fente teal) ; relevée = écran à plat sur le crâne (−150°) au repère `visor_off` du geste `remove_visor` | — |
| Accessoires | Capuche, casquette, bonnet, coupes (longs, chignon, tresses, bouclés, crête, rasé = zone cheveux en chaume), demi-visière translucide, masque respiratoire **au cou**, écharpe, tatouages holo, col montant, liseré émissif (tenues « tech ») | Implants : pas de slot au catalogue (proposition §12.2 toujours en attente) |
| Regard | `NeckLook` (30 %) + `HeadLook` (100 %) = `LookAtModifier3D` (lacet ±40°, tangage ±25° en garde-fou) ; la cible est bornée en amont (−25°/+15°) par l'acteur ; influence fondue 0,2 s, **0 pendant marche / présentation / réactions / sortie** | Corrigé : le regard revient après `present_documents` (il restait coupé en M4) |
| Portrait | Même rig + `AppearanceApplier`, posé sur la 1ʳᵉ image d'`idle`, recul 1,75 m (épaules → crâne) | — |
| File | `imp_silhouette.res` : modèle posé en `idle`, simplifié à 400 tris, orienté vers la place suivante | — |
| Perf (llvmpipe, rendu logiciel, 1920×376) | Guichet vide 13,1 FPS / 56 draws ; avec passager 12,1 FPS / 74 draws (+18 dont ombres), ≈ +3,7 k primitives ; acteur ≈ 1,6 k tris corps + ≤ 2 k pièces (≤ 8 k) | **FPS GPU non mesurable ici** (pas de GPU) : à vérifier sur la config cible. Le décor greybox dépasse déjà le budget de 40 draws (56) |

---

## 17. Implémenté en M9 — décor définitif du guichet (2026-10-28, 3D Designer / Asset Lead, appui Godot Architect)

Générateur : `tools/build_booth.gd` (remplace `build_booth_greybox.gd`, supprimé). Sources CC0 : `bash tools/fetch_assets.sh` (AmbientCG ×5, Kenney City Kit Commercial). Ordre : `godot --headless --script res://tools/build_booth.gd -- --textures` → `godot --headless --import` → `godot --headless --script res://tools/build_booth.gd`.

### 17.1 Ce qu'on voit (cadre FOV 14°, bande 1920×376)
Le cadre ne montre qu'une **bande horizontale** du monde (à 12 m : y ≈ 0,1 → 3 m) : ni sol ni plafond ne sont visibles. Le décor est donc composé comme une suite de plans verticaux, du guichet vers la ville.

| Plan | Contenu | Remarques de lisibilité |
|---|---|---|
| Guichet (z 0) | Montants blindés (tôles rivetées AmbientCG, 2 × 30 rivets), liserés chromés usés, traverses ; **hygiaphone** : lunette chromée, grille perforée (tôle perforée AmbientCG), 4 vis, anneau sombre, LED cyan fixe (énergie 0,9 ≤ 1,5) ; fente et comptoir hors champ | Lampe intérieure `BoothInterior` sur le **calque 2** (cadre et hygiaphone seulement, jamais le passager) |
| Pilier HALCYON (−1,1 ; −2,6) | Béton (condensation qui ruisselle), collier riveté, cornières chromées, bande de danger au pied, enseigne verticale jaune (marque Consortium, lettres TextMesh), affiche « GLOIRE AU CONSORTIUM » | Occulte toujours la tête de file (contrat §2) |
| File (z −3,9 → −6,6) | Barrières **magnétiques** (LORE §3) : poteaux chromés, barre teal désaturée + champ additif ondulant ; silhouettes `QueueImpostors` inchangées | — |
| Colonnes | 4 colonnes aux **bords** du cadre (jamais devant une enseigne ni derrière le visage) : béton, collier, bande de danger, conduite de recyclage chromée ; écran « ANNEAU B › PORTE 2 » | — |
| Portique (z ≈ −8,8) | Néon HALCYON / GATE · ANNEAU A (jaune marque), écran des départs (teal désaturé, 4 lignes), TRANSIT·7 (rose monde, seul néon instable ≤ 2 Hz, hors fenêtre utile), **CONTRÔLE · GUICHET 04** déplacé à droite du passager (visible entre la bulle et le panneau de file, aussi en 1280×800), hologramme additif de l'« Œil » du Consortium (hexagone solaire) | Lettres en triangles (TextMesh cuits) : 0 draw supplémentaire, nettes au zoom visage |
| Mur du fond (z −10) | Soubassement béton, appui chromé (ligne d'horizon derrière les épaules), **grande baie** à meneaux tous les 3 m décalés (aucun ne « pousse » dans la tête), graffiti **luciole** magenta (3 traits + 1 point, LORE §7) — l'unique magenta du décor, discret, hors fenêtre utile | — |
| Ville de l'Anneau (z −44 → −90) | 26 tours Kenney City Kit (skyscrapers + low-detail) posées sur un sol qui **se relève vers les bords** (courbure de l'anneau habitable) ; silhouettes en aplats sombres non éclairés, vitrages = grille de fenêtres procédurale (allumées au hasard, moyennée au loin contre le moiré) ; halo additif teal / rose | Fond calme derrière le visage : tours sombres, fenêtres ≤ 0,75 d'énergie, brouillard |
| Pluie | 3 nappes additives entre z −7,4 et −9,6 (condensation des conduites) | — |

Palette : rims et néons d'ambiance en **palette monde désaturée** (D-051) ; jaune pur = marque Consortium seulement ; cyan = LED de l'hygiaphone, fente ; magenta = graffiti luciole seulement.

### 17.2 Maillages fusionnés (5 draw calls) et matériaux

| Nœud `Decor/…` | Fichier | Triangles | Matériau |
|---|---|---|---|
| `StaticNear` | `assets/models/booth/booth_static_near.res` | ≈ 2,4 k | `booth_decor.gdshader` (partagé) |
| `StaticFar` | `booth_static_far.res` | ≈ 1,5 k | idem |
| `Emissive` | `booth_emissive.res` | ≈ 28 k (dont 17,6 k vitrages + silhouettes de la ville) | `booth_emissive.gdshader` (non éclairé) |
| `Holo` | `booth_holo.res` | ≈ 0,3 k | `booth_holo.gdshader` (additif, sans brouillard) |
| `Rain` | `booth_rain.res` | 6 | `rain_sheet.gdshader` (additif) |
| + `BoothFront/Glass`, `QueueImpostors` | (sous-ressources de la scène) | 2 + 6 × 400 | `booth_glass`, `impostor_silhouette` |

- **`booth_decor.gdshader`** : 2 `Texture2DArray` (5 couches AmbientCG 512 px : chrome usé Metal050C, tôles rivetées MetalPlates001, béton Concrete044B, bandes de danger PaintedMetal016, tôle perforée SheetMetal001) ; par sommet : couche (UV2.x), mouillé (UV2.y), teinte + facteur métal (COLOR) ; UV = tuilage en mètres (continu entre pièces) ; filets de condensation animés sur les faces verticales ; **reflets analytiques** (plafonniers, néons, intérieur du guichet) en émission — pas de `Sky` (en Compatibilité un Sky posé pour les reflets s'affiche aussi en fond) ni de `ReflectionProbe`.
- **`booth_emissive.gdshader`** : énergie et mode par sommet (fixe, néon instable ≤ 2 Hz, écran holo, vitrages) ; `fx_intensity` 0 = tout fixe.
- **`booth_glass.gdshader`** enrichi : filets de condensation qui glissent (figés à fx 0,5), crasse des bords et autour de l'hygiaphone, rayures ; zone dégagée du visage inchangée (≤ 20 % des effets).
- Le décor ne projette **aucune ombre** ; seule la `KeyLight` est ombrée (passager). LOD et occlusion : inutiles (cadre fixe, tout est dans le champ ou culled par frustum).

### 17.3 Lumières et environnement
`KeyLight` (inchangée : lampe sur le visage, seule ombrée), `RimLeft`, `RimRight`, `Fill`, `HalcyonSpill`, `SlotGlow`, `GateLight` (contrat), **`BoothInterior`** (nouvelle, calque 2 : cadre + hygiaphone), `HallTeal` / `HallRose` (portée 4,5 m : n'atteignent pas le guichet — ≤ 8 lumières par objet en Compatibilité). `WorldEnvironment` : fond `bg.void`, ambiance couleur, AgX, glow léger (seuil 1), brouillard exponentiel 0,024 ; pas de SSR/SSAO/SSIL/SDFGI/volumétrique.

### 17.4 Performance (mesures réelles, xvfb + `opengl3`, `RenderingServer` / `viewport_get_render_info` du `SubViewport` du booth)

| Situation | Avant (greybox) | Après (M9) |
|---|---|---|
| Guichet vide (draws décor) | **56** | **7** |
| J1, passager au guichet (draws de la bande 3D) | 84 | 34 |
| J7, premier passager (bande 3D / image entière) | 71,5 / 382 | 22 / 333 |
| J7, détention + escorte (bande 3D) | 87 | 37 |
| Primitives, guichet vide | 24,8 k | 35,1 k |

Le reste des draws avec passager vient des acteurs (≈ 27 par passager : pièces attachées aux os) et de l'UI (≈ 300) : prochains leviers. **FPS logiciel non représentatif** (llvmpipe : le décor PBR coûte plus en rastérisation CPU — guichet vide ≈ 6 i/s en Moyen/Élevé, 13 en Bas, contre 10 pour le greybox) ; à mesurer sur GPU (Steam Deck, R27).

### 17.5 Qualité graphique (`Settings.graphics_quality`, Options › Accessibilité)

| Niveau | Ombre `KeyLight` | Glow | MSAA (SubViewport) | Pluie | Normal maps / ruissellement animé |
|---|---|---|---|---|---|
| Bas | ✗ | ✗ | off | 1 nappe | ✗ / figé |
| **Moyen** (défaut Steam Deck) | ✓ | ✓ | 2× | 2 nappes | ✓ / animé |
| Élevé (défaut ailleurs) | ✓ | ✓ (+ bloom) | 4× | 3 nappes | ✓ / animé |

« Auto » (valeur par défaut) = Moyen sur Steam Deck (`SteamDeck=1`), Élevé ailleurs. La résolution 3D n'est jamais réduite. Capture : `docs/mockups/m9_quality_low_high.png`.

### 17.6 Déterminisme
`build_booth.gd` n'a aucune source aléatoire (hachages de positions), conserve les UID des `.res`, puis **normalise `booth.tscn`** : `unique_id` = hachage du chemin du nœud (Godot 4.7.2 les tire au hasard), identifiants `ext_resource` / `sub_resource` renumérotés dans l'ordre, paramètres de shader nuls retirés. Vérifié : deux exécutions → fichiers identiques (scène, 5 maillages, 2 textures). Une retouche dans l'éditeur reste possible mais sera écrasée au prochain build : la reporter dans l'outil.

### 17.7 Captures (réelles, xvfb + `opengl3`)
`docs/mockups/m9_before_after.png` (bande 3D avant/après, J1 et J7 détention), `m9_booth_j1.png`, `m9_booth_j7_detain.png` (1920×1080), `m9_booth_j1_deck.png`, `m9_booth_j7_detain_deck.png` (1280×800), `m9_quality_low_high.png`.

### 17.8 À valider / suite
- **Décisions proposées** : (a) décor fusionné généré par outil + scène normalisée (plutôt qu'une scène éditée à la main : la fusion des maillages exige un outil, et la scène reste reproductible) ; (b) baie sur la ville de l'Anneau au lieu du quai sous la pluie (cohérence LORE §3 : station en orbite, pluie = condensation) ; (c) réglage « Qualité graphique » Auto/Bas/Moyen/Élevé ; (d) reflets analytiques sans Sky ; (e) un seul magenta (graffiti luciole) dans le décor.
- Design System : textes du décor en Chakra Petch (JetBrains Mono variable produit des contours qui se croisent : `TextMesh` échoue sur Q, 3, ›).
- Mesure GPU réelle (Steam Deck en Moyen) ; ~~draws des acteurs~~ → fait en M10 (§18).
- Git LFS : +4,2 Mo de PNG (textures) et +2,2 Mo de `.res`.

---

## 18. Implémenté en M10 — coût de rendu des personnages (2026-10-28, 3D Designer / Asset Lead, appui Godot Architect)

### 18.1 Constat
Chaque pièce d'apparence était un `MeshInstance3D` attaché à un os avec son propre matériau : 10 à 15 instances visibles par passager (corps, plaque visage, nez, 2 oreilles, jusqu'à 7 boucles, coiffe en 2–4 pièces, visière, col, liseré, accessoires, implants), chacune dessinée deux fois (passe de base + passe d'ombre de la `KeyLight`) : ≈ 27 draws par passager.

### 18.2 Technique retenue : pièces fusionnées et skinnées (un maillage, un matériau)
- Les pièces restent construites comme avant (`AppearanceApplier`, `ImplantDecor`, brassard de la Garde) : ce sont des **sources** nommées, masquées.
- `PassengerRig.rebuild_parts()` parcourt les `BoneAttachment3D` du squelette, exprime chaque pièce dans l'espace de son os (repère « en mètres » compris), concatène les primitives en **un seul `ArrayMesh` skinné** (une liaison `Skin` d'identité par os porteur, poids 1) affiché par `Skeleton3D/Parts`. Les déformations restent exactes : échelle de l'os `Head` (forme du visage), regard (`LookAtModifier3D`), animations.
- **Un matériau par acteur**, `chr_parts.gdshader` : albédo et émission (CUSTOM0/CUSTOM1, flottants), rugosité/métal (UV2) et **mode** par sommet — pièce unie (rendu identique à `passenger_body` : rim de Fresnel bicolore), plaque visage (code partagé `face_dither.gdshaderinc` : expressions, regard, iris, lèvres inchangés ; galbe cuit ; **n'ombre pas** via `IN_SHADOW_PASS`), non éclairé (tatouage holo), papiers (affichés par l'uniforme `papers_visible`, triangles dégénérés sinon : pas de draw en plus pendant `present_documents`).
- Seule la **demi-visière translucide** (alpha) garde sa propre instance (passe transparente).
- **Cache par signature** des pièces (os, transformation, paramètres de primitive, rendu) : 48 maillages ; l'acteur et le portrait d'une même apparence partagent le maillage. Refusion différée (`queue_parts_rebuild()`, une fois par image, avant le rendu) ; ≈ 1–3 ms CPU par nouvelle apparence.
- `PassengerRig.merge_parts = false` (statique, lu à la construction) restitue le rendu par pièce, pour les comparaisons.
- Couleurs : les uniformes `source_color` ne sont pas linéarisés côté CPU en Compatibilité ; les couleurs cuites sont donc stockées telles quelles (vérifié au pixel près).

### 18.3 Écartés
- Corps + pièces en un seul shader : le corps est en `diffuse_toon`/`specular_toon` (mode de rendu par shader) ; tout fusionner changerait l'ombrage. Gain nul en draws avec la passe d'ombre (2 instances = 4 draws).
- Uniformes d'instance / matériau partagé entre acteurs : ne retire aucun draw (2 matériaux par acteur suffisent).
- Masquer jambes et pieds au guichet : le corps est un seul maillage (aucun gain), et la marche/la sortie les montrent.
- LOD de la Garde : inutile une fois fusionnée (4 draws, brassard compris).
- Ombres par qualité : déjà couvert — en **Bas**, la `KeyLight` n'ombre pas, un passager coûte 2 draws.

### 18.4 Mesures (xvfb + `opengl3`, draws du `SubViewport` du booth, qualité Élevé sauf mention)

| Situation | Avant | Après |
|---|---|---|
| J1, passager au guichet (bande 3D) | 34 (passager 27, 14 instances) | **11** (passager 4, 2 instances) |
| J1, qualité Bas | — | 9 (passager 2) |
| J7, détention + escorte (bande 3D, pic) | 38 (acteurs 31) | **15** (acteurs 8) |
| File d'attente (imposteurs) | 1 instance `MultiMesh` | inchangée |
| Planche de 12 apparences + implants + brassard | 287 draws, 150 instances | 49 draws, 25 instances |

`PortraitService` : un rendu `UPDATE_ONCE` par signature (cache), viewport `UPDATE_DISABLED` sinon ; le modèle du studio (squelette, modificateurs) est désormais **en pause** entre deux portraits : 0 draw et ~0 CPU pendant le shift.

### 18.5 Vérification visuelle
Planche de 12 apparences couvrant toutes les coupes, coiffes (visière baissée/relevée, capuche, casquette, bonnet), accessoires (demi-visière, respirateur, écharpe, 4 tatouages), implants OPT/NX/MIL/KIN/DER-19, fil magenta, papiers, brassard : écart > 8/255 sur 0,04 % des pixels (contact entre sphères de boucles qui se recoupent). Portraits identiques (max 25/255 sur 53 pixels). Captures jeu (J1, J7 escorte, planche de 8, visière) : seuls diffèrent le décor animé et la phase d'`idle`. Comparatif : `docs/mockups/m10_characters_before_after.png`.

### 18.6 Outils
`tools/build_passenger_impostor.gd` pose désormais le modèle sur la 1ʳᵉ image d'`idle` figée (la pose dépendait du temps écoulé : sortie différente à chaque exécution) ; `imp_silhouette.res` régénéré, identique d'une exécution à l'autre.

### 18.7 Décision proposée
Fusion des pièces d'apparence en un maillage skinné par acteur, construit à l'application et mis en cache, avec un matériau à attributs par sommet (proposition D-075, à consigner par l'Orchestrateur).

---

## 19. M14 — planches de cinématique, phase 1 (lot C, 2026-10-30, 3D Designer / Asset Lead)

Version minimale de B89/B90 (M14 §3.6, D-184) et **deux planches témoins pour la validation de DA** (PL-F9-1, PL-F10-3), chacune en deux traitements picturaux. Rien n'est encore branché au jeu : pas de `PlateDef` lue, pas d'import dans `assets/cinematics/` (phase 2, après le choix du client).

### 19.1 Outil et passes
`tools/build_plates.gd` (SceneTree, xvfb + `opengl3`, comme `qa_capture.gd`) :
```
xvfb-run -a -s "-screen 0 1920x1200x24" godot --path . --rendering-driver opengl3 \
    --script res://tools/build_plates.gd -- [--only=PL-F9-1,PL-F10-3] [--variant=a|b|all] [--mockups] [--verify]
```
1. **Décor** construit par l'outil avec le format de sommets et les matériaux du guichet (D-073 : `booth_decor` + Texture2DArray AmbientCG, `booth_emissive`, `booth_holo`), silhouettes anonymes (`imp_silhouette.res`, primitives) ; temps figé (`wet_motion` 0, `fx_intensity` 0, `flicker` 0, silhouettes sans balancement).
2. **Passes** dans une `SubViewport` 2048×1152 (`own_world_3d`, MSAA 4×, sans TAA ni FXAA, glow et brouillard de l'environnement du guichet) : couleur ; **G-buffer** (matériau de remplacement : normale de vue octaédrique + profondeur log, sans MSAA) ; **masque** (couches `MID`/`FIG` : blanc, reste noir) ; **identifiants** (zones d'état, ci-dessous). Les passes techniques écrivent des codes bruts (environnement plat, tonemap linéaire ; les codes < 48 sont déformés en sortie 8 bits, d'où `ID_BASE`).
3. **Peinture** `plate_paint.gdshader` (ASSETS §7.6) en plein écran sur chaque couche ; les couches transparentes gardent leur alpha et reçoivent un liseré d'encre.
4. **Export** : `art_src/plates/<planche>/<a|b>/bg.png`, `mid.png`, `lit_nn.png` (+ `.webp` Lossy 0,75 pour mesurer le poids) et `art_src/plates/manifest.json` (SHA-256 et MD5, tailles PNG/WebP, VRAM, rectangles en pixels et normalisés comme `PlateLayerDef.rect`, caméra, rampe, ancres `holo` et `labels`, adaptateur et version de Mesa, durée).
5. `--mockups` : planche à plat 1920×1080 (recadrage central, toutes les vitres allumées) et **capture composée** telle qu'à l'écran (ci-dessous) dans `docs/mockups/`. `--verify` : deuxième rendu et comparaison des SHA-256.

**Aucun texte cuit** : plaques de numéro et tableau vierges ; les textes sont des `Label` posés à l'exécution sur les ancres du manifeste (test `test_plate_shaders.gd` : ni `TextMesh` ni `Label3D` dans l'outil).

### 19.2 Couches (grammaire M14 §3.3)
| Couche | Contenu | Remarque |
|---|---|---|
| `BG` | fond opaque 2048×1152 ; pour PL-F9-1, **l'état éteint** | — |
| `LIT_nn` (PL-F9-1) | 12 découpes de l'état **allumé** (vitre, cabine, lueur et reflet au sol), une par guichet, alpha = zone d'identifiant floutée (2 × flou en boîte, 18 px) | l'écran les éteint une à une (`modulate.a`) ; `reduce_motion` : jamais affichées. Demande au lot A : un `kind` d'état (`STATE`/`LIT`) et un index dans `PlateLayerDef` pour `holo_effect = glass_off_sequence` |
| `MID` | avant-plan transparent recadré (`get_used_rect`) : barrières + deux personnes de dos (F9) ; pupitres, bancs ajoutés et enfants (F10) | les objets occultés par `MID` sont dans `MID` (pas de décalage d'occlusion à la parallaxe) |
| ancres `HOLO` | rectangles des vitres (F9), du tableau (F10) | `plate_holo.gdshader` à l'exécution |
| ancres `LABEL` | plaques « 01 » → « 12 » (police mono DS) | `PlateLabelDef` : le texte est un numéro littéral, pas une clé — à prévoir (style `holo_small`) |

**Zones d'état** : maillages invisibles du groupe `plate_id` (vitre + lueur au sol) rendus en codes `ID_BASE + n × ID_STEP` ; les occultants s'y écrivent en noir. Les zones voisines se chevauchent près de la caméra : chacune a sa hauteur (+4 mm × n), sinon elles se disputent la profondeur et le rendu varie d'un passage à l'autre (constaté, corrigé).

### 19.3 Décors des témoins
- **BG-H12 (S1, variante « arc »)** : 12 façades de guichet sur un arc concave (rayon 13 m, pas 8,4°) vues du Hall depuis 3,6 m de haut (FOV 40°) ; piliers de béton mouillé, comptoirs en tôle rivetée, bandeaux, plaque de numéro jaune assourdie (marque Consortium), murs hauts en aplats à joints (les couches texturées vues de loin deviennent du bruit sous le Kuwahara), plafond bas à bandeaux rayonnants, Œil du Consortium en hologramme, agent·es en silhouette derrière les vitres (jamais de visage).
- **BG-X1 (S8)** : lieu jamais modélisé construit **en volumes simples par l'outil** (salle 9 × 12 m, pupitres d'origine, bancs **ajoutés** dépareillés : caisses de fret + planche, rangée de sièges de navette à sangles jaunes, pupitre rose ; dessins punaisés sans texte ; baie sur l'autre rive de l'Anneau), même matériau et même peinture que le guichet. Enfants de dos en primitives (buste, épaules, nuque, coiffure ou capuche ; rim faible sur la tête : un anneau clair autour d'un disque sombre se lisait comme un visage). M14 §3.6 prévoyait du 2D dessiné pour S8 : la maquette en volumes coûte autant à écrire, donne gratuitement perspective, lumière et contours G-buffer, et garde une seule grammaire (proposition ci-dessous).

### 19.4 Traitements picturaux soumis au client
| | A « aplats encrés » (`m14_plate_*.png`) | B « lavis gravé » (`m14_plate_*_alt.png`) |
|---|---|---|
| Kuwahara | rayon 4 | rayon 6 |
| Rampe 8 tons | marches franches, chroma 0,3 | marches adoucies (`band_soft` 0,45), chroma 0,5 |
| Encre | 2 px, 92 % | 1–2 px, 60 % |
| Texture | grain ordonné 0,04 | hachures dans les deux tons sombres (0,32) + grain 0,03 + papier 0,05 |
| Lecture | graphique, contrasté, proche de la bande dessinée ; la nuit avale les murs | plus doux, plus lisible dans les ombres, plus « peint » |
| Poids | plus léger (aplats) | ×1,6 à ×2,5 (grain et papier cuits) |

Rampes : gris monde (DS + BOOTH §5) teintés par la dominante de la fin — F9 acier `world.steel`, F10 vert (`state.green`, décoratif) avec lumières tirées vers l'ambre monde (lampes de classe). Recommandation 3D : **A**, avec le papier de B appliqué à l'exécution par l'écran si le client veut la matière (il ne coûte alors rien sur disque).

### 19.5 Captures composées (`*_composed.png`)
Composition figée à l'instant t ≈ 1,7 s : zoom 1,02, `MID` décalé de (−8, −3) px (parallaxe ≤ 12 px), F9 : vitres 04 et 05 éteintes, 06 à 45 % (une toutes les 0,5 s), lueurs `plate_holo` (temps figé) et numéros en `Label` (JetBrains Mono, `text.primary` allumé / `text.secondary` éteint) ; légende de M14 §3.4 (clés `cin_f9_1`, `cin_f10_3` lues dans `fr.csv` si présentes, sinon texte de M14) en style `SubtitleText` × 1,25 (23 px) sur voile `DS.SCRIM` (`bg.void` 72 %), dans la zone sûre 16:10. Cet assemblage préfigure `CinematicScreen` (lot D) ; il n'en est pas l'implémentation.

### 19.6 Mesures (xvfb, llvmpipe LLVM 20.1.2, Mesa 25.2.8, 4 cœurs ; manifeste)
| Mesure | PL-F9-1 A | PL-F9-1 B | PL-F10-3 A | PL-F10-3 B | Cible M14 |
|---|---|---|---|---|---|
| Rendu complet (passes + peinture + captures) | 21,2 s | 28,7 s | 16,0 s | 21,9 s | 63 planches ≤ 15 min |
| Fond WebP 0,75 | 46 Ko | 118 Ko | 90 Ko | 215 Ko | ≈ 150 Ko |
| Planche entière WebP (fond + couches) | 222 Ko (dont 12 `LIT` 167 Ko, `MID` 9 Ko) | 345 Ko | 134 Ko (`MID` 44 Ko) | 269 Ko | total ≤ 12 Mo |
| PNG source du fond | 0,40 Mo | 3,3 Mo | 0,44 Mo | 3,9 Mo | — |
| VRAM (RGBA8, toutes couches) | 14,9 Mo (fond 9,4 + `LIT` 3,4 + `MID` 2,4) | idem | 13,7 Mo (fond 9,4 + `MID` 4,7) | idem | ≤ 32 Mo pour 2 planches |
| Contraste de la légende (95ᵉ centile du fond sous le voile) | 16,5:1 | 16,8:1 | 16,1:1 | 16,1:1 | ≥ 7:1 |
| Déterminisme | identique | identique | identique | identique | SHA-256 identiques |

- **Déterminisme** : `--verify` (deux rendus dans le même processus) et deux exécutions séparées : **32/32 couches et 8/8 captures identiques** (MD5 et SHA-256).
- **Projection** : 63 planches en A ≈ 63 × 16–21 s ≈ 17–22 min sur llvmpipe 4 cœurs (captures comprises) — au-dessus de la cible de 15 min (M14 §3.6 l'estimait à 6 min) ; un GPU réel la tient largement ; leviers : ne rendre le G-buffer qu'une fois par planche quand les groupes ne changent pas, reconstruction incrémentale par hachage de recette. Disque : ≈ 63 × 180 Ko ≈ 11 Mo en A (sous 12 Mo) ; **B dépasserait** (≈ 17 Mo) sauf grain et papier appliqués à l'exécution.
- **VRAM** : courante + suivante ≈ 28–30 Mo en RGBA8 : sous le plafond mais serré. Leviers : `MID` recadré (fait), couches d'état libérées une fois éteintes, import VRAM Compressed (÷ 4) à valider visuellement.

### 19.7 Reste pour la phase 2 (après validation)
- Lire `PlateDef` / `PlateLayerDef` / `PlateLabelDef` (`data/cinematics/plates/*.tres`, lot E) au lieu des recettes en dur ; `dominant` par nom de jeton ; réglages du traitement retenu (un seul pour tout le jeu).
- Décors S2 → S7 (quai, cabine Pétrel, Anneau B, recycleur, Tycho) et variantes de S1 ; S8 en volumes simples ; 46 fonds, ≈ 50 couches.
- Import dans `assets/cinematics/{bg,mid,fig,lit}/` (Lossy 0,75), `manifest.json`, reconstruction incrémentale.
- `PlateFigureService` (B90 : studio de `PortraitService` en 512×768, pose, peinture en espace écran avec `plate_paint`), silhouettes de repli `fig/`, `PortraitService.size`, méthode du booth pour `UPDATE_DISABLED`.
- `tools/qa_plates_audit.gd` (M-16 : contraste ≥ 7:1 sous la légende sur toutes les planches, zone sûre, ≤ 70 caractères ; M-09, M-11, M-12) — la mesure du contraste de 19.5 en est le premier morceau ; captures 1280×800.

### 19.8 Décisions proposées
- (a) **Couches d'état** (`LIT`) découpées par passe d'identifiants pour les effets « une à une » (PL-F9-1, et plus tard les douze vitres allumées de PL-EB-3, les bornes jaunes) plutôt qu'un masque calculé à l'exécution ; besoin d'un `kind` dans `PlateLayerDef`.
- (b) **S8 en maquette de volumes simples** construite par l'outil plutôt qu'en polygones 2D (même coût, même grammaire, contours G-buffer).
- (c) **Grandes surfaces des décors de planches en aplats + joints en géométrie** (pas de couches texturées vues de loin).
- (d) Traitement **A** recommandé ; matière de B (papier) éventuellement en surcouche d'exécution.
- (e) `art_src/plates/` ignoré par git.

## 20. M14 — vie dans le Hall (lot C, 2026-10-31, 3D Designer / Asset Lead) — B86 → B88

### 20.1 File réelle (VH-1 → VH-3, D-187)
- **Maillages** (`tools/build_passenger_impostor.gd`, déterministe) : `imp_silhouette_bare.res` (400 tri.), `imp_silhouette_hood.res` (248), `imp_silhouette_cap.res` (224) — corps Kenney posé en `idle` + coiffes **aux cotes du rig** (`AppearanceApplier`) ; `imp_silhouette.res` historique inchangé (octet pour octet). Aucun bagage, accessoire ni implant (IV-1).
- **`QueueImpostors`** (`scripts/booth/queue_impostors.gd`) sur `EventBus.queue_progressed` : tête de file (`upcoming[0]`) à la place 0 derrière le pilier jusqu'à sa présentation (compteur `presented`), places 1 → 6 = `upcoming[1 …]`, au plus `QueueSilhouette.visible_count` ; la file **se vide** (plus de retour en queue). EV-06 : +3 places le long de la barrière (−3,45 ; −7,72) → (−4,45 ; −8,18), puis point d'entrée. Teinte = `GreyboxStyle.PALETTES[palette_index][0]` désaturée à 40 % (le shader la mêle au remplissage sombre), taille `1 + 0,03 × height_step`. Un `MultiMesh` par forme (ce nœud = `bare`, enfants internes `Queue_hood` / `Queue_cap` créés à la première file qui en a besoin). Qualité **Bas** : un seul maillage, pas de débordement. Sans `queue_progressed` (démo, scènes anciennes) : file cosmétique d'avant.
- **Shader** `impostor_silhouette.gdshader` : `INSTANCE_CUSTOM` (x marche → pas ±2 cm à 2 Hz ; y phase ; z mode passager/Garde/Arbitre/civil ; w assombrissement), uniforme `motion` = 0 avec `reduce_motion` (ni balancement au repos — corrigé — ni pas ; la translation de 1,2 s reste), marque émissive `UV.x` (brassard).

### 20.2 Gardes (VH-4, VH-5, D-188)
- `imp_guard.res` (440 tri. ≤ 600 : carrure élargie, casque à visière baissée, brassard marqué `UV.x` = 1, jaune émissif).
- **`HallGuards`** (`scripts/booth/hall_guards.gd`, nœud `%HallGuards`, **1 `MultiMesh`**) : postes (0–3, près du portique, balancement seul) + 1 patrouilleur. Patrouille au fond du Hall (Z −8,55) d'un côté à la fois, de x = ±7,4 (hors champ) à x = ±1,6, demi-tour, retour, à 1,1 m/s avec le pas ; « 2 » à l'Acte II = deux passages l'un après l'autre, un de chaque côté. **À l'arrêt** sur `day_phase_changed(INSPECTING)` et pendant l'escorte de DÉTENTION ; repart à `passenger_departed`. EV-05 et grève (`lights_out`) : silhouettes assombries, patrouille arrêtée. J27 : `hall_j27_arbitre` → traversée de l'Arbitre escortée sur la moitié droite (2 instances de plus, toujours 1 draw). Qualité Bas : postes seuls.
- Calendrier : `HallAmbience.for_day` (M14 §4.3, tel quel ; J31 D = un civil du comité, mode 3).
- **Hors visage (M-15)** : `test_m14_hall.gd` projette la silhouette entière (pieds → 1,9 m, ±0,32 m) de chaque point des chemins (patrouille, Arbitre, escorte, postes) et vérifie l'absence d'intersection avec le rectangle du visage + 15 %, au cadrage normal **et** au travelling (FOV 6,5°, dolly 0,3 m visée tête), en 1920×376 et 1280×251.

### 20.3 Hall par acte (VH-7, VH-8, D-190)
`BoothDirector.apply_act_ambience(day)` (à `day_started`) applique `HallAmbience.for_day(jour, mode, monde)` :
| Élément | Moyen | Coût |
|---|---|---|
| Lumière `HallTeal`/`HallRose` (jamais celles du visage) | Acte II −10 %, J16 → −15 % après 16:00 (`day_clock_ticked`), Acte III −10 % et blanc froid, J31 A jaune / B chaude / D ambre | 0 draw |
| Graffiti luciole (seul magenta) | variantes cuites dans `booth_emissive.res` (graines 9, 200 – 203) repliées en un point par l'uniforme `graffiti_state` : visible / peinture grise (J11) / grand (J21) / + 2 traits (J30) / sous verre (J31 C) | 0 draw |
| Écran des départs | statuts TRANSIT·7 cuits (graines 210 – 212, écran 220 – 226), uniforme `departures_status` : À L'HEURE, RETARD (EV-06), DERNIÈRE ROTATION en ambre (J28–J30), éteint (J31 B) | 0 draw |
| Bannière holographique | `booth_banner_{quota,enquete,continuite,date}.res` (TextMesh cuits, matériau `booth_holo`), nœud `Banner` créé à la demande ; Bas : masquée | +1 draw |
Le lit d'ambiance et le murmure ∝ file sont du lot B.

### 20.4 Bande 3D en pause pour les cinématiques
`BoothDirector.set_rendering_paused(true|false)` (et `is_rendering_paused()`) : le `SubViewport` hôte passe en `UPDATE_DISABLED` (coût GPU nul, dernière image gardée), puis revient au mode d'avant. `NullBooth` expose la même méthode (sans effet). Appel du lot D (`CinematicScreen`).

### 20.5 Mesures (xvfb + `opengl3`, render info du `SubViewport` du booth, `tools/qa_hall_audit.gd`)
| Situation | Draws bande 3D | Cible M-13 |
|---|---|---|
| J1, passager au guichet, file de 6 (3 formes), patrouilleur | **13** | ≤ 14 |
| J1, qualité Bas | **9** | ≤ 11 |
| J7, détention + escorte (pic) | **16** | ≤ 19 |
| J22, bannière + 2 postes + patrouille sortie | **14** | — |
File réelle émulée par l'outil depuis le vrai roster (`emulated_queue=1`) tant que le `DayController` n'émettait pas encore `queue_progressed`. Triangles ajoutés ≤ 9 × 400 + 4 × 440 ≈ 5,4 k.

## 21. M14 — planches de cinématique, phase 2 : production (lot C, 2026-10-31) — B89, B90, B92

### 21.1 Pipeline (`tools/build_plates.gd` + catalogue `tools/plate_sets.gd`)
- **Données d'abord** : lit les 66 `PlateDef` du lot E (`data/cinematics/plates/`, bibliothèque chargée avant elles) ; un fond par chemin `bg/bg_<id>.webp` distinct (**46**), puis les couches `MID`/`FIG` de chaque planche dans le même décor et la même caméra, les 12 couches `LIT` de PL-F9-1 (passe d'identifiants, `state_index`), et les 5 **silhouettes de repli** des figures nommées (`PlateFigureService.render_image(…, silhouette = true)`, même pose et même cadrage que le rendu à l'exécution).
- **Décors** : tous en volumes simples construits par l'outil (proposition 19.8 b étendue) — S1 Hall (arc de façades de PL-F9-1 réutilisé : vues du Hall H3/H4/H6–H9/H13/H15/H17/H18 ; côté agent·e H1/H2/H14/H16 ; porte H5, écrans H10, haut-parleur H11), S2 hangar du quai 2 / cabine et cuves de la Transit-7, S3 coque rouillée, cale, hublot, écluse 9, S4 cabine 9 m² (couchette triple, réchaud, recycleur, hublot) et appartement de l'Anneau D, S5 couloir et cellule de l'Anneau B, S6 recycleur central, S7 Tycho (dôme, plaine, sas Castellanos, réfectoire, dehors), S8 école (planche témoin), archives, bureau au-dessus du Hall, coursive. **Aucun texte cuit**, aucun visage (silhouettes ; l'agent·e de dos ou en mains seules).
- **Traitement B unique** (D-195) : `PlatePaintStyle.PRESET` (Kuwahara r6, 8 tons, `band_soft` 0,45, chroma 0,5, encre 0,6, hachures 0,32, grain 0,03) ; **papier = 0 dans les images**, posé à l'exécution par `plate_paper.gdshader` (même motif). Dominante : jeton DS de la planche (`PlatePaintStyle.TOKENS`) ; un fond partagé par des fins de dominantes différentes (BG-Q1, BG-H1…) est peint en acier neutre.
- **Recadrage** : les couches sont recadrées sur leur contenu réel (+12 px) ; les rectangles des données étaient des intentions (lot E) — `tools/build_data_m14.gd` **relit le manifeste** (`_rendered_rect`, `_anchor_rect` : couches et `Label` littéraux posés sur une ancre du décor, ex. plaques « 01 » → « 12 », « 04 », « BASSE-MARÉE »). Ordre : `build_plates` → `build_data` → `godot --import`.
- **Robustesse** : échec franc (code 1) si un shader ne compile pas (uniformes absents ou image de contrôle non transformée par `plate_paint`), si un fond / une couche n'a pas de constructeur, ou si une couche sort vide. Reconstruction **incrémentale** par hachage de recette (catalogue, shader, dominante, éclairage, couches) ; `--force`, `--verify`, `--only=bg_…|pl_…|figures`, `--mockups=…`.
- **Sources** : WebP versionnés (fonds en perte contrôlée 0,83, couches à alpha en perte contrôlée 0,9 : sans perte, elles pesaient 7,5 Mo et le total 17,8 Mo) — ni PNG lourds (88 Mo) ni Git LFS (décision de l'Orchestrateur). **Import** (`.import` écrits par l'outil) : Lossy WebP 0,75, sans mipmaps, *Fix Alpha Border* sur les couches. VRAM Compressed écarté : voir ASSETS §8 (S3TC 1,18 Mo / Basis 0,43–0,53 Mo par fond contre ≈ 0,12 Mo).

### 21.2 Mesures (xvfb, llvmpipe LLVM 20.1.2, Mesa 25.2.8, 4 cœurs)
| Mesure | Résultat | Cible |
|---|---|---|
| Rendu complet (46 fonds, 57 couches dont 12 `LIT` et 5 figures), 6 lots | ≈ 13,6 min | ≤ 15 min (M14 §3.6) |
| Disque des planches importées (`.ctex`, M-12) | **9,95 Mo** | ≤ 12 Mo (D-195 : plafond 18) |
| Sources WebP versionnées dans `assets/cinematics/` (fonds 0,83 : 10,3 Mo ; couches 0,9 avec alpha : 1,4 Mo ; + manifeste et `.import`) | **11,95 Mo** | ≤ 15 Mo (Orchestrateur) |
| VRAM, pire paire de planches consécutives (M-11) | **22,6 Mo** (PL-F9-1 + PL-F9-2) | ≤ 32 Mo |
| Légendes (M-16, `tools/qa_plates_audit.gd`, 66 planches × 1280×800 et 1920×1080) | contraste minimal **7,7:1** (PL-F3-3 Deck), toutes dans la zone sûre 16:10, ≥ 16 px | ≥ 7:1 |
| Déterminisme (M-09) | `--verify` et deux exécutions complètes séparées : 103/103 WebP identiques (MD5) | identiques |

### 21.3 Exécution (lot D)
- `PlateFigureService` (`scripts/booth/plate_figure_service.gd`) : `request_for(slot, GameState.case_memory, ctx_flags, plate.dominant)` pendant la carte de titre → texture immédiate (silhouette de repli), mise à jour sur place (`figure_ready`) ; headless, REVOIR du Dossier, figure jamais vue : silhouette.
- `PortraitService.size` (`DOSSIER_SIZE` = 128×160) : à poser avant `add_child` ; esquisse et rendu à la taille demandée ; changer la taille vide le cache.
- **D-210 (finition)** : la toute première image d'un studio `PortraitService` neuf sortait vide en OpenGL 3 (fond seul ; reproduit au Dossier › PERSONNES sans amorce : première vignette vide). Correctif à la source dans `_pump` : une passe de chauffe (`UPDATE_ONCE` + `frame_post_draw`) **une fois par studio**, avant la première lecture ; la vignette d'amorce du Dossier est retirée. Capture [`m14_fix_d210_dossier_people.png`](mockups/m14_fix_d210_dossier_people.png).
- Papier : `PlatePaintStyle.paper_material(rect.position_px, rect.size_px, Settings.fx_intensity)` comme matériau de chaque `TextureRect` de couche.
- Bande 3D : `BoothDirector.set_rendering_paused(true)` pendant la séquence (§20.4).
- `tools/plate_compose.gd` préfigure l'assemblage (captures `docs/mockups/m14_{f9_1,f1_1,f2_2,f10_3}_b[_deck].png`).

### 21.4 Décisions proposées
- (a) **VRAM Compressed écarté** pour les planches (disque) : Lossy WebP 0,75, VRAM non compressée sous le plafond.
- (b) Rectangles des couches et ancres des `Label` **lus dans le manifeste** par `build_data_m14.gd` (le rendu fait foi).
- (c) **Tranché** : sources WebP (les données pointent vers `.webp`), plus de PNG de 87 Mo.
- (d) Fonds partagés par des fins de dominantes différentes peints en neutre ; teinte de la fin éventuellement ajoutée à l'exécution par le lot D.
