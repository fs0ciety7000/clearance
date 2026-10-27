# CLEARANCE — Design System

> Version 0.1 · Propriétaire : Design System / Senior Designer · Statut : **brouillon à valider**
> Sources de vérité : ce document (intentions, règles) · `res://ui/theme/tokens.gd` (valeurs code, `class_name DS`) · `res://ui/theme/clearance_theme.tres` (thème Godot).
> Les valeurs de base (couleurs, familles de police) sont fixées par le contrat de l'Orchestrateur. Ce document y ajoute uniquement des **nuances dérivées** (alpha, états).

---

## 1. Principes

1. **Lisibilité d'abord.** Le cœur du jeu est la *lecture comparative* sous pression. Tout effet, néon ou animation qui ralentit la lecture d'un champ est un bug de design. Les données sont toujours nettes, stables, contrastées.
2. **Hologramme = information.** Le cyan holographique signale « ceci est une donnée interrogeable ». Ce qui n'est pas de l'information (décor, chrome, pluie) n'est jamais cyan.
3. **La couleur porte un sens, jamais seule.** Chaque couleur d'accent a *un* rôle (voir §2). Toute information critique est doublée par une **forme**, une **icône** et/ou un **texte** (daltonisme, dyslexie, fatigue).
4. **Sobriété : les néons sont rares et significatifs.** Règle des 10 % : à l'écran de travail, la surface cumulée d'accents saturés ne dépasse pas ~10 % de la zone UI. Au repos, le poste est sombre et calme ; il s'allume quand quelque chose *arrive*.
5. **Diégétique d'abord, non-diégétique en dernier recours.**
   - **Diégétique** (existe dans le monde, s'affiche sur le bureau / les projecteurs du poste) : documents holographiques, Rulebook, horloge de service, tampons, citations du Consortium. Ils subissent la lumière, peuvent avoir des effets holo (légers).
   - **Non-diégétique** (méta, pour le joueur) : menus pause/options, sous-titres, tutoriels contextuels, notifications système d'accessibilité. **Aucun effet holo**, contraste maximal, style plat.
   - En cas de doute : si l'information est nécessaire pour ne pas perdre injustement, elle doit aussi exister en non-diégétique (option).
6. **Le Consortium est jaune, la rébellion est magenta.** Le jaune = autorité, marque, action officielle. Le magenta = ce qui cloche (anomalie détectée, voix dissidente). Ce couple narratif ne doit jamais être brouillé.
7. **Accessible par défaut.** Options obligatoires : réduction des effets, échelle UI (80–150 %), mode daltonien (renfort des formes, pas de changement de palette), sous-titres, timer désactivable/ralenti.

---

## 2. Couleurs

### 2.1 Tokens de base (contrat — valeurs figées)

| Token | Hex | Constante `DS` | Usage | À ne pas faire |
|---|---|---|---|---|
| `bg.void` | `#07080C` | `BG_VOID` | Fond absolu, vide entre panneaux, scrim | Utiliser pour du texte ; superposer du noir pur `#000` (écrase le chrome) |
| `bg.panel` | `#0E1118` | `BG_PANEL` | Fond des panneaux UI, corps du HoloDocument | L'utiliser comme bordure |
| `bg.elevated` | `#161B26` | `BG_ELEVATED` | Surfaces au-dessus du panel : champs, cartes, menus déroulants, hover neutre | Plus de 2 niveaux d'empilement (panel → elevated → stop) |
| `line.subtle` | `#232A38` | `LINE_SUBTLE` | Séparateurs, bordures au repos, grilles | Porter un état (un état a toujours une couleur sémantique) |
| `text.primary` | `#E8F1F5` | `TEXT_PRIMARY` | Valeurs, titres, corps de texte | — |
| `text.secondary` | `#8A97A8` | `TEXT_SECONDARY` | Labels de champs, métadonnées, descriptions | Valeurs à comparer (toujours primary) |
| `text.muted` | `#4E5868` | `TEXT_MUTED` | **Décoratif / désactivé uniquement** (n° de série, filigranes, placeholder) | Toute info utile : contraste 2,6:1 → échoue WCAG |
| `accent.cyan` | `#00E5FF` | `ACCENT_CYAN` | Hologrammes, information, **focus**, **sélection**, liens de comparaison neutres | Décor, succès, avertissement |
| `accent.yellow` | `#FFE600` | `ACCENT_YELLOW` | Marque Consortium, **CTA principal** (1 seul par écran), tampons officiels, cachets | Avertissement (c'est l'ambre), texte long |
| `accent.magenta` | `#FF2E88` | `ACCENT_MAGENTA` | **Discordance détectée**, DiscrepancyLink, contenus narratifs/rebelles | Erreur système, refus (c'est le rouge) |
| `state.amber` | `#FFA31A` | `STATE_AMBER` | Avertissement, timer bas, **règle nouvelle du jour** | Marque Consortium |
| `state.red` | `#FF3B3B` | `STATE_RED` | **REFUS**, critique, pénalité, timer critique | Simple anomalie (magenta), bouton destructif hors refus sans icône |
| `state.green` | `#2EFF9A` | `STATE_GREEN` | **APPROBATION**, validé, conforme | Hover, décor, « information » |

**Distinction critique rouge / magenta / ambre** : rouge = *décision ou sanction*, magenta = *constat d'incohérence*, ambre = *attention requise*. Les trois sont toujours accompagnés d'une icône distincte (voir §6).

### 2.2 Variantes alpha (dérivées)

Appliquées **par-dessus `bg.panel`** sauf mention. Suffixe = opacité.

| Variante | Alpha | Hex Godot (RRGGBBAA) | Usage |
|---|---|---|---|
| `cyan.08` | 8 % | `#00E5FF14` | Voile de surface holographique (corps du HoloDocument) |
| `cyan.12` | 12 % | `#00E5FF1F` | Fond d'un DocField **sélectionné** ; hover sur surface holo |
| `cyan.24` | 24 % | `#00E5FF3D` | Fond actif/pressé ; bandeau d'en-tête holo |
| `cyan.40` | 40 % | `#00E5FF66` | Bordure de document holographique au repos |
| `cyan.60` | 60 % | `#00E5FF99` | Glow de focus/sélection (shadow) |
| `cyan.80` | 80 % | `#00E5FFCC` | Trait des scanlines d'apparition, bord avant d'un balayage |
| `yellow.12/24/60` | 12/24/60 % | `#FFE6001F` / `3D` / `99` | Hover CTA, encre de tampon, glow tampon |
| `magenta.12/24/60` | idem | `#FF2E881F` / `3D` / `99` | Fond champ « flagged », glow DiscrepancyLink |
| `amber.12/24/60` | idem | `#FFA31A1F` / `3D` / `99` | Fond RuleCard « NOUVEAU », toast warning |
| `red.12/24/60` | idem | `#FF3B3B1F` / `3D` / `99` | Fond citation, glow tampon REFUSÉ |
| `green.12/24/60` | idem | `#2EFF9A1F` / `3D` / `99` | Fond confirmation, glow tampon APPROUVÉ |
| `scrim` | 72 % | `#07080CB8` | Voile derrière modale |
| `text.on-accent` | 100 % | `#07080C` | Texte posé sur un accent plein (bouton jaune, badge vert) |

Règle : **jamais d'accent plein en grande surface** (> 1 bouton, 1 badge, 1 tampon). Les grandes surfaces colorées passent par les variantes 08–24 %.

### 2.3 Contrastes WCAG 2.1 (calculés)

Calcul : luminance relative sRGB, ratio (L1+0,05)/(L2+0,05). Seuils : AA texte normal 4,5:1 · AA grand texte (≥ 24 px, ou ≥ 18,66 px gras) et éléments d'interface 3:1 · AAA 7:1.

**Texte sur fonds de base**

| Texte \ Fond | `bg.void` | `bg.panel` | `bg.elevated` | Verdict |
|---|---|---|---|---|
| `text.primary` | 17,47 | 16,48 | 15,04 | AAA partout |
| `text.secondary` | 6,74 | 6,36 | 5,80 | AA partout (AAA sur aucun) |
| `text.muted` | 2,78 | 2,63 | 2,40 | **Échec** — décoratif/désactivé uniquement |
| `accent.cyan` | 13,01 | 12,28 | 11,20 | AAA |
| `accent.yellow` | 15,80 | 14,90 | 13,60 | AAA |
| `state.green` | 15,14 | 14,29 | 13,03 | AAA |
| `state.amber` | 10,01 | 9,45 | 8,62 | AAA |
| `accent.magenta` | 5,72 | 5,39 | 4,92 | AA |
| `state.red` | 5,66 | 5,34 | 4,87 | AA (marge faible sur elevated : texte rouge ≥ 14 px semi-bold) |

**Texte foncé sur accent plein** (boutons, badges) : `bg.void` sur jaune 15,80 · vert 15,14 · cyan 13,01 · ambre 10,01 · magenta 5,72 · rouge 5,66. → Les boutons danger (rouge plein) et badges magenta utilisent du **texte `#07080C`**, pas du blanc (`text.primary` sur rouge ≈ 3,1 — échec).

**Texte sur fonds teintés** (variante alpha composée sur `bg.panel`)

| Fond composé | Hex résultant | `text.primary` | `text.secondary` | Accent lui-même |
|---|---|---|---|---|
| cyan 12 % | `#0C2A34` | 13,13 | 5,06 | 9,78 |
| cyan 24 % | `#0B444F` | 9,38 | **3,62** ✗ | 6,99 |
| magenta 12 % | `#2B1425` | 14,91 | 5,75 | 4,88 |
| magenta 24 % | `#481833` | 12,61 | 4,86 | **4,13** (grand texte seulement) |
| red 12 % | `#2B161C` | 14,85 | 5,73 | 4,81 |
| red 24 % | `#481B20` | 12,62 | 4,87 | **4,09** (grand texte seulement) |
| green 12 % | `#122E28` | 12,67 | 4,89 | 10,98 |
| green 24 % | `#164A37` | 8,86 | **3,42** ✗ | 7,68 |
| amber 12 % | `#2B2318` | 13,52 | 5,21 | 7,75 |
| amber 24 % | `#483418` | 10,30 | **3,97** ✗ | 5,90 |

→ Règle : **sur un fond 24 %, n'utiliser que `text.primary`**. Les labels secondaires passent en primary ou le fond descend à 12 %.

**Non-texte** : `line.subtle` sur `bg.panel` = 1,31:1 → une bordure `line.subtle` n'est **jamais** le seul indicateur d'un état ou d'une limite interactive. Le focus utilise `accent.cyan` (12,28:1) + glow.

---

## 3. Typographie

### 3.1 Familles (Google Fonts, OFL 1.1)

| Rôle | Famille | Graisses embarquées | Caractère |
|---|---|---|---|
| Display | **Chakra Petch** | 500, 600, 700 | Angulaire, techno-corporate. Titres, tampons, marque. |
| UI | **Inter** (variable) | 400, 500, 600 | Neutre, très lisible. Boutons, dialogues, règles, menus. |
| Données | **JetBrains Mono** (variable) | 400, 500, 700 | Chiffres tabulaires, 0 barré, I/l/1 distincts. Valeurs, codes, timer. |

JetBrains Mono est **obligatoire** pour toute valeur à comparer (ID, dates, codes, numéros) : alignement des colonnes et désambiguïsation O/0, I/l/1 — c'est une mécanique de jeu, pas un style.

### 3.2 Échelle (px à 1080p ; multipliée par l'échelle UI utilisateur)

| Token | Famille / graisse | Taille | Interligne | Tracking | Casse | Rôle |
|---|---|---|---|---|---|---|
| `display.xl` | Chakra Petch 700 | 56 | 1,1 | +2 % | MAJ | Écran titre, verdict de fin de journée |
| `display.l` | Chakra Petch 700 | 40 | 1,1 | +4 % | MAJ | Titre d'écran, texte du Stamp |
| `display.m` | Chakra Petch 600 | 28 | 1,15 | +2 % | MAJ | Titre de document (« PASSE D'ACCÈS », « PERMIS DE TRAVAIL ») |
| `title` | Chakra Petch 600 | 20 | 1,25 | +2 % | Titre | Titre de panneau, RuleCard, Citation |
| `body` | Inter 400 | 16 | 1,5 | 0 | Phrase | Dialogue passager, texte de règle, descriptions |
| `body.strong` | Inter 600 | 16 | 1,5 | 0 | Phrase | Mots-clés dans une règle (« **expire** », « **secteur 7** ») |
| `body.s` | Inter 400 | 14 | 1,45 | 0 | Phrase | Texte secondaire, aide, toasts |
| `button` | Inter 600 | 15 | 1,0 | +4 % | MAJ | Libellés de boutons |
| `label` | Inter 600 | 12 | 1,3 | +8 % | MAJ | Label de DocField (« NOM », « EXPIRATION ») |
| `data` | JetBrains Mono 500 | 16 | 1,35 | 0 | Telle quelle | Valeur de DocField |
| `data.s` | JetBrains Mono 400 | 14 | 1,35 | 0 | Telle quelle | Tableaux denses, historique, n° de citation |
| `timer` | JetBrains Mono 700 | 44 | 1,0 | −2 % | — | Horloge de service (chiffres tabulaires, pas de saut de largeur) |
| `caption` | Inter 500 | 12 | 1,3 | +2 % | Phrase | Mentions légales, légendes. **Taille minimale absolue** |

Règles :
- **Minimum 12 px @1080p**, et **14 px pour tout texte lu en jeu sous contrainte de temps** (labels exceptés car en capitales + tracking).
- Longueur de ligne des textes lus en continu (règles, dialogues) : 45–70 caractères.
- Pas d'italique (rendu pauvre en holo). L'emphase = graisse ou couleur sémantique + icône.
- Capitales réservées aux labels, boutons, display. Jamais pour un paragraphe.
- Localisation : prévoir +30 % de longueur (FR/DE). Les labels tronquent avec « … » + tooltip, les valeurs **ne tronquent jamais** (une valeur tronquée peut masquer la discordance).

---

## 4. Espacement, formes, bordures, élévation

### 4.1 Grille 4 px

| Token | px | Usage typique |
|---|---|---|
| `space.1` | 4 | Écart label ↔ valeur, icône ↔ texte compact |
| `space.2` | 8 | Padding interne de chip, écart icône ↔ libellé bouton |
| `space.3` | 12 | Padding vertical de bouton, écart entre DocFields |
| `space.4` | 16 | Padding horizontal bouton/champ, padding de carte |
| `space.5` | 20 | — |
| `space.6` | 24 | Padding HoloDocument, gouttière entre panneaux |
| `space.8` | 32 | Séparation de sections |
| `space.10/12/16` | 40/48/64 | Marges d'écran, layout macro |

Marges de sécurité écran : 48 px (1080p) ; tout HUD reste dans la zone safe 90 %.
Cible cliquable minimale : **40 × 40 px** (`HIT_TARGET_MIN`), même si le visuel est plus petit.

### 4.2 Formes : chanfreins, pas d'arrondis

L'identité est **angulaire** : angles coupés à 45°, jamais de rayons ronds (réservés aux éléments organiques/narratifs — p. ex. bulle de dialogue rebelle, à valider).

| Token | px | Usage |
|---|---|---|
| `chamfer.s` | 4 | Champs, chips, badges |
| `chamfer.m` | 8 | Boutons, RuleCard, toasts |
| `chamfer.l` | 16 | HoloDocument, panneaux majeurs |

Convention d'asymétrie : coins **haut-gauche et bas-droit** chanfreinés, les deux autres vifs (signature « ticket » corporatif). Les composants « système » (modales non-diégétiques) chanfreinent les 4 coins.
Implémentation Godot : `StyleBoxFlat.corner_radius_*` + `corner_detail = 1` → produit un chanfrein à 45°.

### 4.3 Bordures

| Token | Largeur | Couleur | Usage |
|---|---|---|---|
| `border.hairline` | 1 | `line.subtle` | Séparateurs, champs au repos |
| `border.holo` | 1 | `cyan.40` | Contour d'un document holographique |
| `border.state` | 1 → 2 | couleur sémantique | Champ flagged (magenta), erreur (rouge) |
| `focus.ring` | 2 | `accent.cyan` | Focus clavier/manette, offset 2 px, toujours visible |

### 4.4 Élévation par glow (pas d'ombre portée noire)

Dans un univers sombre, la hauteur se lit par la **lumière émise**, pas par l'ombre.

| Niveau | `shadow_size` | Couleur | Quand |
|---|---|---|---|
| `glow.0` | 0 | — | Repos |
| `glow.1` | 4 | accent 24 % | Hover |
| `glow.2` | 8 | accent 60 % | Focus, sélection, document actif |
| `glow.3` | 16 | accent 60 % | Impact de tampon, alerte active (temporaire, ≤ 400 ms puis retombe à glow.2/0) |

Au maximum **un** élément en `glow.3` simultanément. En mode « effets réduits », glow plafonné à `glow.1`.

---

## 5. Effets holographiques

Implémentés dans **un seul shader** `holo.gdshader` (CanvasItem) appliqué aux conteneurs holographiques, avec un uniform global `fx_intensity` (0 / 0,5 / 1) piloté par l'option d'accessibilité.

| Effet | Paramètre | Valeur par défaut | **Max** | Règle |
|---|---|---|---|---|
| Scanlines | alpha / période | 0,05 / 3 px | **0,08** | Défilement lent (≤ 20 px/s). Masquées sous les zones de texte de données (masque) ou alpha ≤ 0,03 sur elles |
| Flicker | amplitude luminance / fréquence | 0,03 / 0,5 Hz | **0,06 / 2 Hz** | **Jamais > 3 Hz** (photosensibilité). Jamais sur la zone de valeurs |
| Aberration chromatique | décalage R/B | 0,75 px | **1,5 px** (pic glitch 4 px ≤ 120 ms) | Bords du document uniquement ; texte de données = 0 |
| Bruit / grain | alpha | 0,02 | **0,04** | Animé à 12 fps max |
| Glitch (déchirure) | fréquence | événementiel | **2 / min** | Seulement narratif (document falsifié, intrusion rebelle) ; jamais pendant une lecture active (champ sélectionné) |

Règles absolues :
1. **Jamais d'effet sur du texte lu en continu** (règles, dialogues, valeurs de DocField, timer). Les effets vivent sur le *cadre*, le fond, et pendant les transitions.
2. **Le texte de données est rendu dans une couche au-dessus du shader**, net (pas de distorsion, pas d'aberration).
3. Option **« Effets visuels » : Complets / Réduits / Désactivés** → `fx_intensity` 1 / 0,5 / 0. En « Désactivés » : aucun flicker, aucun glitch, aucun bruit, transitions en fondu simple ≤ 160 ms. Respecter aussi le réglage OS « reduce motion » si détectable.
4. Les effets **renforcent** la sémantique, ils ne la portent jamais (un document falsifié a aussi un DocField flagged, pas seulement un glitch).
5. Pluie / reflets du monde 3D derrière les hologrammes : le panneau holo applique un voile `bg.panel` à ≥ 85 % d'opacité derrière les zones de texte pour garantir les contrastes du §2.3.

---

## 6. Iconographie

- **Grille 24 px**, zone utile 20 px (padding 2 px), trait **1,5 px** (UI dense, 16–24 px) ou **2 px** (≥ 32 px, tampons, icônes d'état majeur). Terminaisons et jointures **carrées/miter** (cohérent avec les chanfreins). Pas de remplissage sauf états actifs.
- Tailles : 16 (inline), 24 (standard), 32 (état majeur / HUD).
- Couleur : héritée du texte (`modulate`) — l'icône prend la couleur sémantique de son contexte.
- Format : SVG importé (Godot rasterise à l'import ; prévoir `scale` 2× pour 4K).
- **Source suggérée** : **Lucide** (ISC, trait 2 px réglable à 1,5, grille 24 — meilleur alignement avec notre style), complétée par **Kenney Game Icons** (CC0) pour les pictos ludiques. Retouche maison pour les icônes signature.

Icônes sémantiques obligatoires (doublage de la couleur) :

| État | Couleur | Icône (forme distincte) | Lucide indicatif |
|---|---|---|---|
| Approuvé | green | Coche dans un **cercle** | `circle-check` |
| Refusé | red | Croix dans un **octogone** | `octagon-x` |
| Discordance | magenta | **Losange** avec « ≠ » / deux traits brisés | `diamond` + glyphe custom `≠` |
| Avertissement / règle nouvelle | amber | **Triangle** avec « ! » | `triangle-alert` |
| Information / holo | cyan | **Carré chanfreiné** avec « i » | `info` (cadre custom) |
| Consortium | yellow | Logo (hexagone) | custom |

Les formes (cercle / octogone / losange / triangle / carré) restent distinctes en niveaux de gris : c'est le test de validation de toute nouvelle icône d'état.

---

## 7. Composants

Notation des états : **default · hover · focus · selected · disabled · flagged**. Le focus (clavier/manette) est toujours visible et cumulable avec les autres états.

### 7.1 HoloDocument (carte document)

**Anatomie** : `[1] bandeau d'en-tête` (émetteur + type, `display.m`, fond `cyan.24`) · `[2] filigrane/logo émetteur` (`text.muted`) · `[3] portrait` (holo, chromatique autorisé sur le cadre) · `[4] grille de DocFields` · `[5] pied : n° de série` (`data.s`, `text.secondary`) · `[6] coins chanfreinés chamfer.l` · `[7] couche FX`.
Taille de référence : 480 × 320 px (format carte) / 480 × 640 (format permis). Padding `space.6`.

| État | Visuel |
|---|---|
| default | Fond `bg.panel` + voile `cyan.08`, bordure `cyan.40` 1 px, FX holo à intensité de base |
| hover | Bordure `accent.cyan` 1 px, `glow.1` |
| focus / actif (au premier plan sur le bureau) | `glow.2` cyan, ring focus, FX réduits de moitié |
| selected (en mode comparaison) | Bordure 2 px cyan, léger lift (scale 1,02) |
| disabled (rendu / archivé) | Opacité 40 %, FX coupés, désaturé |
| flagged (contient ≥ 1 discordance confirmée) | Badge losange magenta en coin haut-droit + compteur ; la bordure **reste cyan** (le magenta est porté par les champs, pas par toute la carte) |

### 7.2 DocField (label + valeur, sélectionnable)

**Anatomie** : `label` (`label`, `text.secondary`) · `space.1` · `value` (`data`, `text.primary`) · zone cliquable = tout le bloc, min 40 px de haut · indicateur de sélection (barre gauche 2 px).

| État | Visuel |
|---|---|
| default | Fond transparent, aucune bordure |
| hover | Fond `bg.elevated` (ou `cyan.08` sur holo), curseur « cible » |
| focus | Ring cyan 2 px, chanfrein `chamfer.s` |
| selected (1ᵉʳ point de comparaison) | Fond `cyan.12`, barre gauche cyan 2 px, icône « pin » 16 px |
| disabled (non pertinent selon règles du jour) | Valeur en `text.secondary`, label en `text.muted` (reste lisible — l'info est simplement non actionnable) |
| flagged (discordance confirmée) | Fond `magenta.12`, bordure 1 px magenta, icône losange « ≠ » 16 px à droite, label suffixé « — DISCORDANCE » (lecteur d'écran / mode daltonien) |
| match (vérifié conforme, optionnel) | Petite coche verte 16 px, pas de fond |

### 7.3 DiscrepancyLink (ligne reliant 2 champs)

**Anatomie** : point d'ancrage A (carré 6 px) · tracé orthogonal (segments H/V, coudes à 45°) · point d'ancrage B · étiquette centrale (chip `data.s` : « NOM ≠ NOM », ou « DATE EXPIRÉE »).

| État | Visuel |
|---|---|
| en cours (drag / attente du 2ᵉ champ) | Trait cyan 1,5 px **pointillé** (6/4), suit le curseur |
| hover (sur un champ candidat) | Le champ candidat passe en hover ; aperçu du trait plein cyan |
| confirmé — discordance | Trait magenta **plein** 2 px + glow `magenta.60` 4 px, chip magenta (texte `#07080C`), icône ≠ |
| confirmé — concordance (le joueur s'est trompé) | Trait `text.secondary` qui se dissout en 240 ms + chip « CONCORDANT » avec icône `=` |
| disabled | — (le lien n'existe pas si un champ est disabled) |
| focus | Chip focusable (pour supprimer le lien au clavier/manette) : ring cyan |

Accessibilité : la différence plein/pointillé + l'icône ≠/= portent l'information sans la couleur.

### 7.4 Stamp (APPROUVÉ / REFUSÉ)

**Anatomie** : cadre double trait (2 px + 1 px, écart 3 px) chanfreiné · texte `display.l` MAJ · icône d'état 32 px · micro-texte « CONSORTIUM · POSTE 07 · JOUR 03 » (`caption` mono) · texture d'encre (masque grunge, alpha 85–100 %) · rotation aléatoire ±4°.

| Variante | Couleur | Icône | Texte |
|---|---|---|---|
| APPROUVÉ | `state.green` | cercle-coche | « APPROUVÉ » |
| REFUSÉ | `state.red` | octogone-croix | « REFUSÉ » |
| (narratif) DÉTENTION | `accent.yellow` cadre + rouge texte | menottes / custom | « DÉTENTION » — à valider |

| État (outil tampon sur le bureau) | Visuel |
|---|---|
| default | Tampon physique 3D rangé, poignée chrome |
| hover | Liseré de la couleur du tampon, `glow.1` |
| focus | Ring cyan + infobulle raccourci (« A / Entrée ») |
| selected (armé) | Tampon levé, ombre projetée sur le document cible |
| disabled | Désaturé, cadenas 16 px — ex. pas de document ouvert |
| impact | voir Motion §8 |

### 7.5 RuleCard / Rulebook

**RuleCard** — Anatomie : `n° de règle` (`data.s`) · `titre` (`title`) · `corps` (`body`, mots-clés `body.strong`) · `badge` (NOUVEAU / MODIFIÉ / ABROGÉ) · `référence` vers les champs concernés (chips).

| État | Visuel |
|---|---|
| default | Fond `bg.elevated`, bordure hairline, chamfer.m |
| hover | Bordure `text.secondary` |
| focus | Ring cyan |
| selected (règle invoquée dans une comparaison) | Barre gauche cyan 2 px, fond `cyan.12` ; les champs concernés pulsent une fois |
| nouveau (jour courant) | Badge ambre plein texte `#07080C` + triangle ; barre gauche ambre ; fond `amber.12` jusqu'à première lecture |
| modifié | Badge ambre contour ; diff visible (ancien texte barré `text.muted` + nouveau) |
| disabled / abrogée | Corps barré, `text.secondary`, badge « ABROGÉE » contour gris, reste consultable |

**Rulebook** — classeur holographique à onglets (Entrée · Documents · Secteurs · Contrebande · Directive du jour). Onglet avec contenu nouveau = pastille ambre + nombre. Recherche texte (non-diégétique, option). Raccourci global (Tab / bouton Y).

### 7.6 Timer / Shift clock

**Anatomie** : heure de station `HH:MM` (`timer`) · barre de progression de la journée (segments de 4 px, 1 par tranche) · compteur passagers traités (`data.s`) · icône horloge.

| État | Seuil | Visuel |
|---|---|---|
| normal | > 60 s restants (`TIMER_WARN_SECONDS`) | Chiffres `text.primary`, barre cyan |
| warning | ≤ 60 s | Chiffres + barre `state.amber`, icône triangle, un pulse de 400 ms à l'entrée du seuil (pas en boucle) |
| critical | ≤ 15 s | Chiffres `state.red`, icône octogone, tick audio chaque seconde ; pulse de la barre 1 Hz (désactivé en effets réduits) |
| paused | — | Chiffres `text.secondary`, icône pause, libellé « EN PAUSE » |
| disabled (option sans timer) | — | Horloge affichée mais figée, libellé « SERVICE LIBRE » |

Jamais de clignotement on/off des chiffres : le temps doit rester lisible.

### 7.7 Button

**Anatomie** : conteneur chanfreiné `chamfer.m` · icône optionnelle 16/24 · libellé `button` MAJ · hauteur 44 px (M) / 36 px (S) · padding H `space.4`, V `space.3`.

| Variante | default | hover | focus | pressed | disabled |
|---|---|---|---|---|---|
| **primary** (1 par écran) | Fond `accent.yellow`, texte `#07080C` | Fond jaune + `glow.1` jaune | + ring cyan 2 px offset 2 | Fond `yellow.60` sur `bg.elevated`, translateY +1 | Fond `bg.elevated`, texte `text.muted`, bordure hairline |
| **secondary** | Fond transparent, bordure 1 px `text.secondary`, texte `text.primary` | Fond `cyan.12`, bordure cyan | ring cyan | Fond `cyan.24` | Bordure `line.subtle`, texte `text.muted` |
| **danger** | Fond `state.red`, texte `#07080C`, icône octogone | `glow.1` rouge | ring cyan | Fond `red.60` | idem primary disabled |
| **ghost** (tertiaire) | Texte `text.secondary`, pas de fond | Texte primary, souligné 1 px | ring cyan | Texte cyan | `text.muted` |

« selected » s'applique au **toggle button** (filtres, onglets) : fond `cyan.12`, barre bas 2 px cyan. « flagged » n'existe pas pour les boutons.
Les actions destructrices/irréversibles demandent un **maintien** (hold 600 ms, jauge circulaire) plutôt qu'une modale de confirmation (préserve le flow).

### 7.8 Toast / Notification

**Anatomie** : barre latérale gauche 3 px (couleur sémantique) · icône d'état 24 · titre (`body.strong`) · message (`body.s`) · action optionnelle (ghost) · fermeture. Largeur 360 px, empilés en haut-droite, max 3 visibles, durée `TOAST_HOLD` 4 s (×2 si le texte dépasse 80 caractères ; persistant si action requise).

| Type | Couleur | Icône | Exemple |
|---|---|---|---|
| info | cyan | carré-i | « Nouveau document reçu » |
| success | green | cercle-coche | « Entrée enregistrée » |
| warning | amber | triangle | « Nouvelle directive : les visas du secteur 4 sont suspendus » |
| error | red | octogone | « Action impossible : aucun document ouvert » |
| narratif | magenta | losange | Message chiffré rebelle |

États : default · hover (pause du timer d'expiration) · focus (ring) · disabled (n/a) · dismissing.

### 7.9 Citation / Pénalité

Diégétique : ticket imprimé par le Consortium qui sort d'une fente du poste.
**Anatomie** : en-tête jaune Consortium (logo + « AVIS D'INFRACTION ») · n° de citation (`data.s`) · motif (`body`) · règle enfreinte (référence cliquable → RuleCard) · sanction (`data`, rouge, ex. « −5 CR ») · bord dentelé bas.

| État | Visuel |
|---|---|
| default (avertissement, 1ʳᵉ/2ᵉ citation) | Fond papier `bg.elevated`, en-tête jaune, sanction en ambre + triangle, libellé « AVERTISSEMENT » |
| pénalité | Sanction en rouge + octogone, bandeau `red.12` |
| hover / focus | Ring cyan, la règle liée se met en surbrillance dans le Rulebook |
| disabled / archivée | Opacité 40 % dans le récapitulatif de fin de journée |

### 7.10 Dialogue — bulle passager

**Anatomie** : nom du locuteur (`label`, couleur selon rôle) · bulle `bg.elevated` chanfreinée `chamfer.m` avec queue triangulaire vers le portrait · texte `body` (max 3 lignes visibles, défilement) · indicateur « suite » (chevron) · options de réponse (boutons secondary, numérotées 1–4).

| État | Visuel |
|---|---|
| default | Texte apparaissant par mots (pas par lettres) — 40 ms/mot, *skippable* ; option « texte instantané » |
| hover / focus (option de réponse) | Fond `cyan.12` / ring cyan |
| selected (réponse choisie) | Reste affichée en `text.secondary` dans l'historique |
| disabled (option verrouillée) | `text.muted` + cadenas + raison en tooltip (« Requiert : preuve de discordance ») |
| flagged (propos contradictoire avec un document) | Segment souligné magenta pointillé + icône ≠ ; sélectionnable comme un DocField pour créer un DiscrepancyLink |
| variantes de locuteur | Passager : nom `text.primary` · Consortium (haut-parleur) : nom jaune, bulle à bordure jaune · Rebelle : nom magenta, bulle à bordure magenta (seul usage autorisé de coins chanfreinés « cassés »/irréguliers) |

---

## 8. Motion

### 8.1 Durées

| Token | ms | Usage |
|---|---|---|
| `dur.instant` | 80 | Hover, press, changement de couleur |
| `dur.fast` | 160 | Focus, toggle, apparition d'un chip, tooltip |
| `dur.base` | 240 | Ouverture panneau, sélection de champ, toast in |
| `dur.slow` | 400 | Apparition d'un hologramme, tracé de DiscrepancyLink, tampon complet |
| `dur.dramatic` | 640 | Verdict, transition de jour, intrusion narrative — **rare** |
| `stagger` | 30 | Décalage entre DocFields à l'apparition |

### 8.2 Easings (Godot `Tween`)

| Nom | Godot | Usage |
|---|---|---|
| `ease.out` | `TRANS_CUBIC, EASE_OUT` | Entrées (par défaut) |
| `ease.in` | `TRANS_CUBIC, EASE_IN` | Sorties |
| `ease.inout` | `TRANS_SINE, EASE_IN_OUT` | Déplacements, pulses |
| `ease.snap` | `TRANS_EXPO, EASE_OUT` | Hologramme qui « s'accroche », DiscrepancyLink |
| `ease.impact` | `TRANS_BACK, EASE_OUT` | Tampon (léger dépassement) |

Sorties ≈ 70 % de la durée d'entrée. Rien ne bloque l'input : toute animation est interruptible.

### 8.3 Animations clés

**Apparition d'hologramme (400 ms)**
1. 0–80 ms : ligne de balayage horizontale `cyan.80` (1 px) au centre, glitch chroma 4 px.
2. 80–320 ms : ouverture verticale (scale Y 0,02 → 1, `ease.snap`), scanlines `cyan.80` qui descendent.
3. 160–400 ms : DocFields en fondu + translateY 4 → 0, `stagger` 30 ms.
4. Fin : FX retombent à l'intensité de base. *Effets réduits* : fondu 160 ms seul.

**Tampon (400 ms + rémanence)**
1. 0–120 ms : le tampon descend (`ease.in`), ombre qui se resserre.
2. 120 ms : impact — camera shake 2 px / 80 ms (désactivable), son, `glow.3` de la couleur du verdict.
3. 120–280 ms : l'empreinte apparaît scale 1,08 → 1,0 (`ease.impact`), opacité 0 → 0,92.
4. 280–400 ms : tampon remonte ; glow redescend à 0 en 400 ms.
5. Le document glisse hors champ 240 ms plus tard. *Effets réduits* : pas de shake, pas de glow, empreinte en fondu 80 ms.

**Détection de discordance (≈ 400 ms)**
1. 2ᵉ champ sélectionné → tracé du lien de A vers B en 240 ms (`ease.snap`), trait cyan.
2. Résolution (vérification règle) : si discordance, le trait vire au magenta en 80 ms, les deux champs passent en flagged avec un *unique* pulse de glow (`glow.2` → `glow.1`, 400 ms), chip « ≠ » apparaît (`dur.fast`).
3. Si concordance : trait se dissout en 240 ms, chip « = » 1,5 s puis disparaît.

**Règle nouvelle** : la RuleCard glisse depuis la droite (240 ms), badge ambre pulse 2 fois (2 × 400 ms) puis se fige.
**Timer seuil** : un seul pulse à l'entrée en warning ; en critical, pulse 1 Hz de la barre seulement.

---

## 9. Audio-UI (indicatif)

Principe : sons **courts (< 300 ms), secs, synthétiques**, mixés sur un bus `UI` séparé (volume réglable) ; la sémantique sonore suit la sémantique visuelle. Tout signal sonore critique a un équivalent visuel (et inversement, pour les joueurs sourds/malentendants).

| Interaction | Son | Caractère |
|---|---|---|
| Hover | Tick très léger (−18 dB) | Click capacitif 2–4 kHz, aléa de pitch ±3 % |
| Focus / navigation manette | Tick + | Légèrement plus grave |
| Sélection DocField | « Blip » holo | Sinus court avec pitch montant |
| Apparition hologramme | Swell + crépitement | Montée filtrée 300 ms, grain |
| Lien en cours | Bourdon électrique discret | Boucle, suit le tracé |
| Discordance confirmée | Accord dissonant 2 notes (seconde mineure) | Distinct de l'erreur |
| Concordance | Note neutre descendante | « non » doux |
| Tampon APPROUVÉ | Impact mécanique + clic métallique aigu | Lourd, satisfaisant |
| Tampon REFUSÉ | Impact mécanique + buzz grave | Lourd, sec |
| Règle nouvelle | Carillon corporatif 3 notes (motif Consortium) | Jaune = signature sonore de la marque |
| Timer warning | Bip unique | Moyen |
| Timer critical | Tick par seconde | Montant en tension |
| Citation | Imprimante thermique + carillon Consortium mineur | |
| Toast info/success/error | Variantes du blip (neutre/montant/descendant) | |
| Message rebelle | Glitch radio + voix filtrée | Magenta = signature sonore de la résistance |

---

## 10. Mapping Godot 4

### 10.1 Organisation des fichiers

```
res://ui/theme/
  clearance_theme.tres      # Theme principal (assigné dans Project Settings > GUI > Theme > Custom)
  tokens.gd                 # class_name DS — constantes uniquement
res://assets/shaders/holo.gdshader  # effets holographiques (§5) — à créer
res://assets/fonts/          # ChakraPetch-*.ttf, Inter-Variable.ttf, JetBrainsMono-Variable.ttf + OFL.txt
res://assets/icons/          # SVG Lucide/Kenney/custom, nommés icon_<nom>_24.svg
```

### 10.2 Du token au Theme

| Token | Propriété Godot |
|---|---|
| Couleurs | `Theme > Colors` (`font_color`, `font_hover_color`, `font_focus_color`, `font_disabled_color`, `font_pressed_color`, `icon_*_color`) + `StyleBoxFlat.bg_color` / `border_color` / `shadow_color` |
| Typo famille | `FontFile` (ou `FontVariation` pour fixer la graisse d'une police variable : `variation_opentype = {"wght": 600}`) assignée par type variation |
| Tracking | `FontVariation.spacing_glyph` (px) — ex. label 12 px × 8 % ≈ 1 px |
| Taille | `Theme > Font Sizes > font_size` par type variation |
| Interligne | `Label.line_spacing` (constant `line_spacing` du thème) = taille × (interligne − 1,2) env. — à ajuster visuellement |
| Espacement | `StyleBoxFlat.content_margin_*` ; constantes `separation` (BoxContainer), `h_separation`/`v_separation` (GridContainer) |
| Chanfrein | `StyleBoxFlat.corner_radius_top_left/bottom_right = CHAMFER_x`, `corner_detail = 1` |
| Bordure | `StyleBoxFlat.border_width_*`, `border_color` |
| Glow | `StyleBoxFlat.shadow_color = <accent>_60`, `shadow_size = GLOW_x`, `shadow_offset = (0,0)` |
| Focus | StyleBox `focus` de chaque type : `StyleBoxFlat` sans fond, `draw_center = false`, bordure 2 px cyan, `expand_margin_* = FOCUS_RING_OFFSET` |
| Mono chiffres | JetBrains Mono a des chiffres tabulaires par défaut ; pour Inter si chiffres nécessaires : `opentype_features = {"tnum": 1}` |

Police par défaut du thème : **Inter 400, 16 px**, couleur `text.primary`.

### 10.3 Type variations (nommage `PascalCase`, préfixe = composant)

| Type variation | Base type | Contenu clé |
|---|---|---|
| `HoloPanel` | `PanelContainer` | panel : `bg.panel` + `cyan.08` (couche) / bordure `cyan.40` / chamfer.l / margin 24 |
| `HoloPanelActive` | `PanelContainer` | idem + shadow `cyan.60` size 8 |
| `SystemPanel` | `PanelContainer` | Non-diégétique : `bg.panel`, bordure `line.subtle`, 4 coins chamfer.m, pas de FX |
| `ElevatedCard` | `PanelContainer` | `bg.elevated`, hairline, chamfer.m, margin 16 |
| `DocHeader` | `Label` | Chakra Petch 600, 28 px, `text.primary`, MAJ |
| `DocFieldLabel` | `Label` | Inter 600, 12 px, `text.secondary`, spacing_glyph +1, `uppercase = true` |
| `DocFieldValue` | `Label` | JetBrains Mono 500, 16 px, `text.primary` |
| `DocField` | `Button` (toggle_mode) | normal vide · hover `bg.elevated` · pressed (=selected) `cyan.12` · focus ring · disabled |
| `DocFieldFlagged` | `Button` | normal `magenta.12` + bordure 1 px magenta |
| `DataSmall` | `Label` | JetBrains Mono 400, 14 px, `text.secondary` |
| `TitleLabel` | `Label` | Chakra Petch 600, 20 px |
| `DisplayLabel` | `Label` | Chakra Petch 700, 40 px |
| `BodyLabel` | `RichTextLabel` | Inter 400/600 (normal/bold_font), 16 px |
| `CaptionLabel` | `Label` | Inter 500, 12 px, `text.secondary` |
| `TimerLabel` | `Label` | JetBrains Mono 700, 44 px ; couleurs warn/critical appliquées par override via `DS` |
| `ButtonPrimary` | `Button` | jaune plein / texte `#07080C` / chamfer.m / hauteur min 44 |
| `ButtonSecondary` | `Button` | bordure `text.secondary`, hover `cyan.12` |
| `ButtonDanger` | `Button` | rouge plein / texte `#07080C` |
| `ButtonGhost` | `Button` | sans StyleBox, couleurs texte uniquement |
| `ToggleTab` | `Button` | selected = `cyan.12` + barre bas 2 px (StyleBox `border_width_bottom`) |
| `RuleCard` / `RuleCardNew` / `RuleCardRepealed` | `PanelContainer` | cf. §7.5 |
| `ToastInfo` / `ToastSuccess` / `ToastWarning` / `ToastError` / `ToastNarrative` | `PanelContainer` | `bg.elevated`, `border_width_left = 3` couleur sémantique |
| `CitationTicket` | `PanelContainer` | `bg.elevated`, en-tête géré par enfant `CitationHeader` (jaune) |
| `DialogueBubble` / `DialogueBubbleConsortium` / `DialogueBubbleRebel` | `PanelContainer` | cf. §7.10 |
| `Badge` / `BadgeNew` | `PanelContainer` | chamfer.s, margin 4/8 |

Règle : **aucune couleur ou taille en dur dans les scènes**. Une scène utilise soit une type variation, soit une constante `DS.*` (pour les overrides dynamiques : timer, états calculés). Les composants complexes (DiscrepancyLink, Stamp, HoloDocument) sont des scènes `.tscn` avec script, qui lisent leurs valeurs dans `DS`.

### 10.4 Contenu de `tokens.gd`

`class_name DS extends RefCounted`, **constantes seulement** (pas de fonctions, pas d'état) :
- Couleurs de base (`BG_*`, `TEXT_*`, `ACCENT_*`, `STATE_*`) et dérivées alpha (`CYAN_08…CYAN_80`, `<ACCENT>_12/24/60`, `TEXT_ON_ACCENT`, `SCRIM`, `DISABLED_*`).
- Chemins de polices (`FONT_*_PATH`), tailles (`FS_*`), interlignes (`LINE_HEIGHT_*`), tracking (`TRACKING_*`).
- Espacements (`SPACE_0…SPACE_16`), formes (`CHAMFER_*`, `CORNER_DETAIL_CHAMFER`, `BORDER_*`, `FOCUS_RING_*`), icônes (`ICON_*`), `HIT_TARGET_MIN`.
- Élévation (`GLOW_0…GLOW_3`).
- Effets (`FX_*_MAX`, `FX_FLICKER_HZ_MAX`, `FX_GLITCH_MAX_PER_MIN`).
- Motion (`DUR_*` en secondes, `STAGGER`, `TOAST_HOLD`, seuils `TIMER_WARN_SECONDS`, `TIMER_CRITICAL_SECONDS`).

Les noms suivent `SNAKE_CASE` = token en notation pointée (`accent.cyan` → `ACCENT_CYAN`, `cyan.12` → `CYAN_12`, `space.4` → `SPACE_4`). Le `.tres` et `tokens.gd` doivent rester synchrones ; un script d'outil (`@tool`) générant le `.tres` depuis `DS` est recommandé à terme.

---

## 11. Assets libres

| Type | Source | Licence | Notes |
|---|---|---|---|
| Polices | Google Fonts — fonts.google.com : Chakra Petch, Inter, JetBrains Mono | **SIL OFL 1.1** | Embarquer `OFL.txt` dans `res://assets/fonts/` et créditer dans le menu Crédits. Pas de revente des fichiers seuls ; modification autorisée sous autre nom |
| Icônes | **Lucide** — lucide.dev | **ISC** (permissive, conserver la notice) | Trait réglable ; base recommandée pour l'UI |
| Icônes | **Kenney** — kenney.nl/assets (Game Icons, UI Pack Sci-Fi) | **CC0** | Pas d'attribution requise (appréciée) |
| Icônes | game-icons.net | CC BY 3.0 | Attribution obligatoire — à éviter sauf besoin précis |
| Textures PBR (chrome usé, métal, béton mouillé) | **AmbientCG** — ambientcg.com | **CC0** | Grunge pour l'encre des tampons, rayures du chrome |
| Textures / HDRI | **Poly Haven** — polyhaven.com | **CC0** | HDRI nocturnes urbains pour reflets |
| Sons UI | Kenney (Interface Sounds, Sci-Fi Sounds) | CC0 | Base pour §9 |
| Sons | freesound.org | Variable (CC0 / CC BY / CC BY-NC) | **Filtrer CC0 / CC BY** ; NC interdit (projet commercial) |

Tenir un registre `CREDITS` (source, auteur, licence, URL, date) pour chaque asset importé.

---

## 12. Gouvernance

1. **Rôles** : Design System (propriétaire du document, de `tokens.gd`, du `.tres`) · Orchestrateur (propriétaire du **contrat** : couleurs de base, familles de police) · Tech UI (implémentation shaders/scènes) · Audio (§9).
2. **Proposer un token** : ouvrir une demande « DS-Proposal » contenant : nom (selon convention §10.4), valeur, **besoin** (quel écran, quel problème — un token sans au moins 2 usages n'est pas créé), alternatives existantes écartées et pourquoi, contraste calculé si couleur, impact accessibilité.
3. **Proposer un composant** : anatomie, les 6 états (default/hover/focus/selected/disabled/flagged — ou justification de leur absence), comportement clavier/manette, motion, son, type variation(s) Godot, maquette ou capture.
4. **Critères d'acceptation** : réutilise les tokens existants · respecte la règle couleur + forme · contrastes AA · fonctionne en effets réduits et à 80 %/150 % d'échelle · testé avec simulateur de daltonisme (deutéranopie, protanopie, tritanopie) et en niveaux de gris.
5. **Changement du contrat** (valeurs de base) : uniquement via l'Orchestrateur ; le Design System produit l'étude d'impact (contrastes, composants touchés).
6. **Versionnage** : SemVer sur ce document (MAJEUR = renommage/suppression de token, MINEUR = ajout, CORRECTIF = précision). Changelog en bas de fichier. Un token supprimé passe d'abord par 1 version « déprécié » (commentaire `# DEPRECATED` dans `tokens.gd`).
7. **Revue** : toute PR qui touche `res://ui/` est relue par le Design System ; recherche de couleurs en dur (`Color(`, `#` hex hors `tokens.gd`) en revue.

---

## Questions ouvertes (à valider)

- Chanfreins asymétriques (HG + BD) comme signature : OK ou 4 coins partout ?
- Rouge sur `bg.elevated` = 4,87:1 (AA mais serré) : accepter, ou réserver le texte rouge à `bg.panel`/`bg.void` ?
- Variante de tampon « DÉTENTION » (jaune/rouge) : prévue par le Game Design ?
- Bulle rebelle aux angles irréguliers : exception de forme validée par la DA ?
- Lucide (ISC) comme base iconographique plutôt que Kenney (CC0) : arbitrage licence/cohérence.

## Changelog

- 0.1 — Création : tokens dérivés alpha, échelle typo, composants, motion, mapping Godot.
