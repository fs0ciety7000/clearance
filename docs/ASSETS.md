# ASSETS — Registre des assets et pipeline

> Auteur : 3D Designer / Asset Lead · Statut : **proposition v0.1, à valider** · Propriétaire : Asset Lead (`assets/`, `scenes/booth/`, ce document)
> Complète [`DESIGN_SYSTEM.md`](../DESIGN_SYSTEM.md) §11 (polices, icônes, textures, sons) et [`BOOTH_SCENE.md`](BOOTH_SCENE.md) (mise en scène, apparence). Règle AGENTS.md n° 8 : **assets libres uniquement, source et licence consignées ici avant tout commit d'asset.**

---

## 1. Politique de licences

| Niveau | Licences | Usage | Versionnable dans le dépôt ? |
|---|---|---|---|
| ✅ Préféré | **CC0 1.0** (Kenney, Quaternius, KayKit, Poly Haven, AmbientCG) | Libre, sans attribution (créditer quand même dans le menu Crédits) | Oui, brut et importé |
| ✅ Autorisé | **SIL OFL 1.1** (polices), **ISC / MIT** (Lucide) | Conserver la notice de licence à côté des fichiers | Oui + fichier de licence |
| 🟡 Sous condition | **CC BY 3.0/4.0** | Attribution obligatoire dans les Crédits et dans ce registre | Oui |
| 🟡 Sous condition | **Licences propriétaires « libres de redevances »** : Mixamo (Adobe), BlenderKit « Royalty Free » | Intégration dans le jeu autorisée, **redistribution des fichiers bruts interdite** | **Non pour les fichiers bruts.** Ressources importées : voir §3 (dépend de la visibilité du dépôt) |
| ⛔ Interdit | **CC BY-NC**, **CC BY-ND**, « usage éditorial », « free for personal use », licence inconnue, ripped/extrait d'un autre jeu | Projet commercial | — |

Sur Sketchfab, itch.io, OpenGameArt, BlenderKit : la licence se vérifie **asset par asset** (« gratuit » ≠ libre). Capturer la page de licence (PDF ou capture) à la date du téléchargement et la ranger dans `art_src/licenses/` (§9).

---

## 2. Sources recommandées par catégorie

> URLs de mémoire, à vérifier au moment du téléchargement (les noms de packs Kenney/Quaternius évoluent).

| Catégorie | Source | URL | Licence | Notes |
|---|---|---|---|---|
| Personnages (base recommandée) | **Kenney — Animated Characters 1 / 2 / 3** | kenney.nl/assets/animated-characters-1 (puis -2, -3) | CC0 | Low-poly humanoïde riggé, skins en texture (dont « cyborg »), quelques anims (idle/run/jump). Rig annoncé compatible Mixamo : **à vérifier à l'import** (noms d'os). Format FBX → import natif Godot 4.3+ (ufbx) ou passage par Blender. |
| Personnages (alternative) | **Quaternius — Universal Base Characters / Ultimate Modular characters** | quaternius.com | CC0 | Proportions plus réalistes, modulaires. Bon plan B si les proportions Kenney ne tiennent pas en cadrage buste. |
| Personnages (repli greybox) | Kenney — Mini Characters / Blocky Characters | kenney.nl/assets | CC0 | Proportions « chibi » : grosse tête lisible, mais ton trop léger pour la DA finale. |
| Animations (recommandé) | **Quaternius — Universal Animation Library** | quaternius.com (et itch.io) | CC0 (à confirmer à la page) | Marche, idle, gestes, rig humanoïde → retarget `SkeletonProfileHumanoid`. **CC0 = versionnable sans souci.** |
| Animations | KayKit — Character Animations | kaylousberg.itch.io | CC0 (à confirmer) | Complément. |
| Animations (complément) | **Mixamo** (Adobe) | mixamo.com | Propriétaire, libre de redevances (§3) | Pour les clips manquants (`shrug`, `talk`, `react_*`). Fichiers bruts **jamais versionnés**. |
| Animations sur mesure | Faites maison dans Blender/Godot | — | Propriété du studio | `present_documents` (geste spécifique à la fente) : à keyer nous-mêmes, ~1 h. |
| Décor sci-fi / hall | Kenney — Space Station Kit, Modular Space Kit, City Kit (Commercial) | kenney.nl/assets | CC0 | Murs, sols, piliers, portes, mobilier. |
| Décor sci-fi | KayKit — Space Base Bits / City Builder Bits | kaylousberg.itch.io | CC0 | Props stylisés. |
| Décor / props | Quaternius — Sci-Fi Modular / Cyberpunk packs | quaternius.com | CC0 | Panneaux, câbles, caisses. |
| Décor / props | Poly Haven — Models | polyhaven.com/models | CC0 | Props réalistes à styliser (poteaux, mobilier urbain). |
| Décor / props | BlenderKit | blenderkit.com | CC0 **ou** « Royalty Free » | **Filtrer CC0.** Les assets RF suivent la règle Mixamo (pas de redistribution brute). |
| Textures PBR | **AmbientCG** | ambientcg.com | CC0 | Béton mouillé, métal brossé, grilles perforées (hygiaphone), grunge (vitre, encre). |
| Textures PBR | Poly Haven — Textures | polyhaven.com/textures | CC0 | Sols, métaux. |
| HDRI | **Poly Haven — HDRIs** (catégories *night*, *urban*) | polyhaven.com/hdris | CC0 | Usage limité : environnement très sombre ; sert surtout à la `ReflectionProbe` et au rendu des tests. |
| Polices | Google Fonts : Chakra Petch, Inter, JetBrains Mono | fonts.google.com | SIL OFL 1.1 | Cf. DS §3 et §11 ; `OFL.txt` dans `res://assets/fonts/`. |
| Icônes | **Lucide** (base) · Kenney Game Icons (complément) | lucide.dev · kenney.nl/assets | ISC · CC0 | Cf. DS §6. |
| Sons | Kenney Interface / Sci-Fi Sounds · freesound.org (CC0 / CC BY seulement) | kenney.nl · freesound.org | CC0 / CC BY | Propriété Audio Designer ; mentionné pour complétude. |

---

## 3. Note licence Mixamo

**Formulation telle que je la connais** (FAQ Mixamo / Adobe ; **non revérifiée en ligne lors de la rédaction**, à contrôler avant le premier téléchargement) :
- Les personnages et animations Mixamo sont **libres de redevances** (*royalty free*) pour des projets **personnels, commerciaux et non lucratifs**, y compris leur **intégration dans des jeux vidéo**, films, impression 3D.
- Il est **interdit de redistribuer ou de revendre les fichiers bruts** de personnages et d'animations tels quels (par exemple comme pack d'assets ou fichiers téléchargeables séparés).
- L'usage est régi par les **Conditions générales d'utilisation d'Adobe** ; un **Adobe ID** (gratuit) est requis pour télécharger.

**Incertitudes à lever** :
1. La formulation exacte et à jour de la FAQ et des conditions Adobe (elles ont pu changer).
2. Si le dépôt est **public**, des ressources Godot dérivées (`.res` d'animation retargetées) restent extractibles : zone grise vis-à-vis de l'interdiction de redistribution « brute ». Un build exporté (`.pck`) est en revanche le cas d'usage prévu.
3. La pérennité du service Mixamo.

**Règles du studio** :
- Fichiers Mixamo bruts (`.fbx`) : **jamais versionnés** → `art_src/mixamo/` dans le `.gitignore`.
- Ressources importées dérivées : versionnées **seulement si le dépôt est privé** ; si le dépôt est (ou devient) public, elles sont ignorées et reconstruites via la **procédure de téléchargement** (§5.3).
- Archiver la FAQ et les CGU (PDF daté) dans `art_src/licenses/mixamo_<AAAA-MM-JJ>.pdf`.
- **Préférer les clips CC0** (Quaternius, KayKit) chaque fois qu'ils suffisent ; Mixamo n'est qu'un complément.

---

## 4. Arborescence et conventions de nommage

### 4.1 Arborescence (dans le cadre d'ARCHITECTURE §3)
```
res://assets/
  models/
    passenger/
      bodies/        chr_body_s1_outfit_a.glb …  (corps habillés, sans tête, skinnés)
      heads/         chr_head_round.glb, chr_head_square.glb, chr_head_oval.glb, chr_head_angular.glb
      parts/         chr_nose_a.glb, chr_ear_a.glb, chr_hair_undercut.glb, acc_hood_a.glb, acc_visor_band.glb, acc_respirator_neck.glb, acc_implant_ocular.glb …
      impostors/     imp_silhouette_s1.glb … s4
      passenger_anims.res   (AnimationLibrary chargée sous le nom « passenger » — chemin fixé par ARCHITECTURE §8 bis.3)
      animations/    anim_walk.res, anim_idle.res, anim_present_documents.res, anim_leave.res,
                     anim_react_angry.res, anim_react_nervous.res, anim_shrug.res, anim_talk.res
      bonemap_humanoid.tres   (BoneMap partagé par toutes les sources)
    booth/           (M9, réel) booth_static_near.res, booth_static_far.res, booth_emissive.res, booth_holo.res,
                     booth_rain.res — décor fusionné généré par tools/build_booth.gd (pas de station/ séparé)
  textures/
    passenger/       tex_face_round_atlas.png …, tex_face_overlay_atlas.png, tex_chr_decals_atlas.png, tex_chr_detail_a.png
    booth/           (M9, réel) tex_booth_albedo_rough.png, tex_booth_normal_metal.png (Texture2DArray, 5 couches) ;
                     la vitre reste procédurale (pas de tex_glass_*)
    station/         tex_concrete_wet_a.png / _n / _orm …
  materials/         mat_chr_toon.tres, mat_face_dither.tres, mat_booth_glass.tres, mat_impostor.tres …
  shaders/           chr_toon.gdshader, face_dither.gdshader, booth_glass.gdshader, rain_sheet.gdshader,
                     impostor_silhouette.gdshader  (+ holo.gdshader du Design System)
res://data/appearance/  appearance_catalog.tres + slot_<slot>.tres   (AppearanceCatalog / AppearanceSlotDef / AppearanceOptionDef — 3D Designer + Lore Master, ARCHITECTURE §3)

art_src/  (racine du dépôt, contient un fichier .gdignore : Godot l'ignore)
  blend/             *.blend sources (Git LFS recommandé)
  downloads/         archives brutes CC0 (optionnel, sinon re-téléchargeables)
  mixamo/            FBX bruts Mixamo — DANS .gitignore
  licenses/          captures/PDF des pages de licence, datés
```

### 4.2 Règles
- `snake_case`, ASCII, sans espaces ni accents ; anglais pour les noms de fichiers (cohérent avec le code).
- Préfixes : `chr_` personnage · `acc_` accessoire · `imp_` imposteur · `anim_` clip · `env_` décor structurel · `prop_` objet · `tex_` texture · `mat_` matériau · `hdri_` environnement. Les shaders n'ont pas de préfixe (`booth_glass.gdshader`, comme `holo.gdshader`).
- Suffixes de textures : `_a` albedo (sRGB) · `_n` normal · `_orm` occlusion/roughness/metal (linéaire) · `_e` émissif · `_m` masque · `_atlas` atlas multi-cellules.
- Variantes : lettre (`_a`, `_b`) pour des variantes artistiques, nom explicite pour des types (`round`, `square`).
- Noms de clips dans la bibliothèque : **exactement** `walk`, `idle`, `present_documents`, `leave`, `react_angry`, `react_nervous`, `shrug`, `talk` (contrat). Les fichiers de clips portent le préfixe `anim_`, pas les entrées de la bibliothèque.
- Noms de nœuds dans les scènes : `PascalCase` (`PassengerActor`, `DeskMark`, `FacePlate`).

---

## 5. Pipeline personnage, pas à pas

### 5.1 Base (Kenney → Godot)
1. **Télécharger** Kenney Animated Characters 1–3 (zip) → `art_src/downloads/kenney_animated_characters_<n>/`. Consigner au registre (§10).
2. **Vérifier** : échelle (1 unité = 1 m ; mesurer la hauteur), orientation, noms d'os (préfixe `mixamorig:` ?), présence d'un os `Head` et `Neck`, nombre d'os, triangles.
3. **Blender** (facultatif en greybox, nécessaire pour le MVP) — Blender 4.x :
   - Importer le FBX ; appliquer les transformations (`Ctrl+A` → All Transforms) ; vérifier que le personnage regarde vers −Y Blender (devient +Z Godot, `MODEL_FRONT`).
   - **Séparer la tête** du corps : la tête devient un maillage rigide par type de visage (§6.1), attaché à l'os `Head` en jeu.
   - **Peindre les zones en couleurs de sommets** (`COLOR_0`, canal R discrétisé) : 0,0 peau · 0,2 haut · 0,4 bas · 0,6 accent · 0,8 chaussures · 1,0 non teinté. Le shader toon recolore par zone avec les palettes tirées du seed (§7.1). Garder une texture de détail en niveaux de gris (plis, coutures, AO) commune.
   - **Effacer le visage** de la skin d'origine (zone peau unie) : le visage est porté par la plaque d'atlas.
   - Modéliser les **tenues** (2 par silhouette) en partant du corps de base ; transférer les poids (*Data Transfer* → Vertex Groups) depuis le corps ; **même armature** pour tous.
   - Silhouettes : S1–S4 obtenues par sculpt léger des volumes de tenue (épaules, ventre, longueur de manteau) — **ne pas modifier les os de repos** (sinon le retarget diverge) ; la taille passe par l'échelle uniforme en jeu.
4. **Export glTF 2.0** (`.glb`) : `+Y Up` ✓ · Apply Modifiers ✓ · Skinning ✓ · Color Attributes (couleurs de sommets) ✓ · Tangents ✓ · Animations ✗ pour les maillages (les clips sont importés à part) · Materials : Export (les matériaux seront remplacés dans Godot).
5. **Import Godot** (dock Import + *Advanced Import Settings*) : voir §8 ; sur le `Skeleton3D` → **Retarget** → `BoneMap` avec profil **`SkeletonProfileHumanoid`** → enregistrer en `bonemap_humanoid.tres` → **réutiliser ce même BoneMap** pour toutes les sources.
6. **Scène** `passenger_actor.tscn` : arborescence et noms fixés par **ARCHITECTURE §8 bis.2** (`Visual/Armature/Skeleton3D`, `HeadAttachment` → `Face` + `HeadArea`, `ChestAttachment`, `NeckLook`/`HeadLook`, `AnimationPlayer`, `AnimationTree`, `ExpressionController`, `AppearanceApplier`…). Ce que l'Asset Lead fournit dans cette structure :
   - les maillages par slot (corps, tête/oreilles, nez, cheveux, coiffe, accessoires, implants), **tous skinnés ou attachés au même squelette retargeté**, pour que `AppearanceApplier` puisse les échanger ;
   - la plaque `Face` (quad légèrement galbé, décalée de 2 mm, `mat_face_dither`), positionnée par type de tête (ancre par option `face`) ;
   - des points d'ancrage nommés pour accessoires et implants (`anchor_visor`, `anchor_respirator`, `anchor_implant_ocular`, `anchor_implant_temple`, `anchor_implant_jaw`, `anchor_implant_neck`) ;
   - le même jeu de pièces sert au **`PortraitRenderer`** (option A acceptée) : pas de calque 2D à produire (`AppearanceOptionDef.portrait_layer` reste vide).

### 5.2 Animations (CC0 d'abord, Mixamo en complément)
1. **Source CC0** (Quaternius/KayKit) : importer le fichier, *Import As* = **Animation Library**, appliquer `bonemap_humanoid.tres` dans *Retarget*.
2. **Rest Fixer** (même réglage pour toutes les sources) : *Apply Node Transforms* ✓ · *Normalize Position Tracks* ✓ · *Overwrite Axis* ✓ · *Fix Silhouette* ✓ si la pose de repos diffère (T-pose vs A-pose).
3. **Remove Tracks** : *Except Bone Transform* ✓ · *Unimportant Positions* ✓ · *Unmapped Bones* ✓.
4. Par clip : renommer, *Loop Mode* (`Linear` pour `walk`, `idle`, `talk` ; `None` pour les autres, dont `leave` = one-shot de demi-tour/quart de tour + premiers pas qui enchaîne sur `walk`), FPS 30, *Trimming* ✓, *Remove Immutable Tracks* ✓ ; **Save to File** → `animations/anim_<clip>.res` avec *Keep Custom Tracks* (les pistes de repères survivent au ré-import).
5. **Marche en place** : supprimer le déplacement horizontal de `Hips` (ou télécharger la version *In Place*) ; mesurer la **vitesse de référence** (longueur de foulée / durée du cycle) et la noter dans le registre des clips (§5.4) : le code règle `speed_scale = v / v_ref`.
6. **Bibliothèque** : créer `passenger_anims.res` (AnimationLibrary) et y ajouter les 8 clips sous leurs noms de contrat (*Animation → Manage Animations*, ou petit script `@tool` fourni au Godot Architect). L'`AnimationPlayer` de l'acteur charge cette bibliothèque sous le nom **`passenger`** → `play(&"passenger/walk")`.
7. **Repères** : ajouter dans les clips les pistes *Call Method* `documents_slot` (0,75 s de `present_documents`, déclenche `documents_presented` ; ARCHITECTURE §8 bis.6 l'appelle encore `documents_out` → nom à unifier), `footstep_l/r`, `glass_hit` (BOOTH_SCENE §7.3).
8. **Pose de fin** des one-shots = première image d'`idle` (retouche dans Blender ou dans l'éditeur d'animation de Godot).

### 5.3 Procédure Mixamo (pour les clips manquants)
1. Se connecter à mixamo.com (Adobe ID). Personnage de référence : **Y Bot** (ou import du maillage Kenney si accepté).
2. Rechercher le clip (noms **indicatifs**, à vérifier dans le catalogue) : `shrug` → « Shrugging » ; `talk` → « Talking » ; `react_angry` → « Angry Gesture » / « Angry » ; `react_nervous` → « Nervously Look Around » ; `idle` → « Breathing Idle » ; `walk` → « Walking » (*In Place* coché).
3. Réglages de téléchargement : **FBX Binary**, **Without Skin**, **30 FPS**, **Keyframe Reduction : none**, *In Place* pour les marches.
4. Ranger dans `art_src/mixamo/anim_<clip>_mixamo.fbx` (ignoré par git) ; noter dans le registre : nom exact du clip Mixamo, date, réglages.
5. Importer comme en §5.2 avec **le même `bonemap_humanoid.tres`** (l'auto-mapping Godot reconnaît le squelette Mixamo ; vérifier le mapping des doigts, inutiles ici → os non mappés supprimés).
6. Toute personne qui clone le dépôt **sans** les ressources Mixamo refait les étapes 1–5 à partir du registre ; tant que ce n'est pas fait, la bibliothèque utilise les **clips de repli CC0/greybox** du même nom.

### 5.4 Registre technique des clips — **implémenté en M6**

**Choix de rig** : on garde le **squelette Kenney** (le maillage, 1 604 triangles, et ses poids ne bougent pas) et on retargete les clips **Quaternius UAL** dessus. Les deux sources passent à l'import par un `BoneMap` au profil commun **`SkeletonProfileHumanoid`** (`bonemap_kenney.tres`, `bonemap_ual.tres` — un BoneMap par squelette source, le *profil* est partagé ; écrits par `tools/build_passenger_bonemaps.gd`) : os renommés `Hips`, `Neck`, `Head`…, repos normalisés (*Rest Fixer* : Apply Node Transforms, Normalize Position Tracks, Fix Silhouette). L'inverse (re-skinner le maillage Kenney sur le squelette UAL) aurait exigé un re-pondérage : proportions trop différentes (tête « chibi », jambes courtes). Le mannequin UAL (13,7 k triangles, sans vêtements) est écarté.

Bibliothèque `passenger_anims.res` construite par **`tools/build_passenger_anims.gd`** (reproductible) : rééchantillonnage 30 i/s, pistes de rotation des 22 os mappés (sans doigts) + position de `Hips` ; décalage du parent non mappé `HipsCtrl` retiré ; **tête redressée de 31,6°** (écart de retarget mesuré sur `Idle`, compensé moitié cou / moitié tête sur tous les clips) ; gestes absents d'UAL = **couches procédurales** (rotations « espace personnage » clé par clé, converties en rotations locales par cinématique directe sur le squelette Kenney) posées sur `Idle`.

| Clip | Source retenue | Boucle | Durée | v_ref (m/s) | Repères | Pose de fin = idle |
|---|---|---|---|---|---|---|
| `walk` | UAL `Walk_Loop` (sans root motion) | oui | 1,333 s | **0,724** (rig ×1 ; mesurée sur le pied d'appui, métadonnée `walk_v_ref`) | `footstep_l` 0,00 · `footstep_r` 0,667 (pied le plus en avant) | — |
| `idle` | UAL `Idle_Loop` | oui | 2,5 s (*écart* : 6–8 s demandés, la désynchronisation reste assurée par la phase/`speed_scale`) | — | — | — |
| `present_documents` | `Idle` + couche (veste → penché, main vers la fente → retour) | non | 1,2 s | — | `papers_show` 0,30 · **`documents_slot` 0,75** · `papers_hide` 0,85 | ☑ (couches → 0) |
| `leave` | UAL `Walk_Loop` [0 ; 0,8 s] (le quart/demi-tour est fait par la locomotion) | non (enchaîne `walk`) | 0,8 s | idem `walk` | `footstep_l` 0,00 · `footstep_r` 0,667 | = début de `walk` |
| `react_angry` | `Idle` + couche (buste en avant, mains au comptoir, secousse de tête) | non | 1,2 s | — | `glass_hit` 0,45 | ☑ |
| `react_nervous` | `Idle` + couche (main à la nuque, regard fuyant) | non | 1,3 s | — | — | ☑ |
| `shrug` | `Idle` + couche (épaules, avant-bras ouverts, paumes) | non | 0,9 s | — | — | ☑ |
| `talk` | UAL `Idle_Talking_Loop` (filtre haut du corps dans l'`AnimationTree`) | oui | 2,933 s | — | — | — |
| `remove_visor` | `Idle` + couche (main au front, écran relevé) | non | 1,1 s | — | `visor_off` 0,55 | ☑ |

Autres clips UAL utilisables plus tard : `Walk_Formal_Loop` (sortie approuvée), `Hit_Chest`/`Hit_Head` (sursaut), `Interact`, `PickUp_Table`, `Push_Loop`, `Sitting_*`.

### 5.5 Vérifications (checklist avant commit)
- [ ] Hauteur mesurée conforme (1,55–1,85 m selon échelle) ; pieds au sol (y = 0) en `idle`.
- [ ] Pas de **patinage** des pieds à 1,0–1,2 m/s (`walk`, y compris en sortie), ni pendant les premiers pas de `leave`, aux échelles 0,94 et 1,06.
- [ ] Aucune image en T-pose au début d'un fondu ; transitions `idle ↔ walk` propres.
- [ ] Os `Head` et `Neck` présents sous ces noms après retarget ; `LookAtModifier3D` sans retournement aux limites d'angle.
- [ ] One-shots finissent sur la pose d'`idle`.
- [ ] Repère `documents_slot` présent ; la main sort du cadre par le bas à ce moment (vue caméra finale).
- [ ] Plaque visage alignée sur les 4 types de tête, pas de *z-fighting* (décalage 2 mm).
- [ ] Budgets BOOTH_SCENE §13 respectés (Moniteur Godot : triangles, draw calls).
- [ ] Ligne ajoutée au registre §10, licence archivée si nécessaire.

---

## 6. Pièces d'apparence (système modulaire)

Règles, combinatoire, anti-répétition et ressemblances : **BOOTH_SCENE §12**. Ici : ce qu'il faut produire.

### 6.1 Liste minimale MVP

| Famille | Pièces | Nb | Production |
|---|---|---|---|
| Corps habillés | 4 silhouettes (S1 trapu, S2 élancé, S3 moyen, S4 menu) × 2 tenues (dont 1 avec capuche baissée) | **8** maillages skinnés | Blender, à partir du corps Kenney |
| Têtes | rond · carré · ovale · anguleux | **4** maillages rigides | Blender |
| Atlas d'expressions | 1 par type de tête (8 yeux/sourcils + 8 bouches, BOOTH_SCENE §10.3) | **4** textures 512² | Dessin 2D (Krita/Aseprite), gabarit commun |
| Atlas overlay | pupilles, rides (2 niveaux : adulte, âgé), pilosités (courte, moustache, longue) | **1** texture 512² | 2D |
| Atlas décals | 6 marques biométriques (3 cicatrices, 3 tatouages encre) + 4 tatouages holo | **1** texture 512² | 2D |
| Nez (slot `nose_mouth`, × 2 variantes de lèvres dans l'atlas) | 3 formes | **3** | Blender |
| Oreilles (variantes du slot `face`) | 3 formes | **3** | Blender |
| Coupes | 6 maillages + « rasé » (texture) | **6** | Blender (low-poly, cartes simples) |
| Coiffes | capuche relevée, casquette, bonnet | **3** | Blender |
| Visières | bandeau translucide, demi-visière | **2** | Blender |
| Masques respiratoires | porté au cou, filtre latéral | **2** | Blender |
| Implants visibles | oculaire (anneau + iris émissif), shunt temporal, plaque mandibulaire, port cervical | **4** | Blender + émissif |
| Imposteurs de file | 1 par silhouette, ≤ 400 tris | **4** | Décimation des corps |
| Palettes (données) | 8 peaux · 10 cheveux · 6 yeux · 12 palettes de tenue (3 couleurs) | — | options du catalogue (`skin`, `hair`, `eyes`, `palette`) |
| **Total** | | **≈ 41 maillages, 6 textures** | Estimation : 10–14 j/personne pour un artiste 3D junior-confirmé |

**Plancher si le temps manque** (encore ≥ 10³ apparences perceptuellement distinctes) : 4 corps (1 tenue/silhouette) · 3 têtes · 3 atlas · 2 nez · 2 oreilles · 4 coupes · 2 coiffes · 1 visière · 1 masque · 4 implants.

### 6.2 Gabarit de l'atlas d'expressions
- Cellules 128×128, yeux centrés sur la même ligne pour les 4 types (alignement de la « ligne des yeux » exigé par le comparateur UI_FLOW §4.9).
- Dessin en **niveaux de gris** à 64×64 utiles (le shader quantifie), puis canaux : R encre, G masque iris, B ombrage peau, A alpha.
- Lisibilité testée à **90 px de visage** (cadrage normal) et à 300 px (travelling).

### 6.3 Contraintes de compatibilité (dans le catalogue)
- Coiffe ⇒ masque la coupe (sauf mèches avant).
- Capuche relevée ⇔ tenue « à capuche » uniquement.
- Visière translucide ≤ 40 % d'opacité ; masque jamais sur la bouche au guichet.
- Implants, âge apparent : **imposés par les données gameplay**, jamais tirés du seed.
- Chaque slot porte `identity` et `visible_in_portrait` (`AppearanceSlotDef`) ; `FaceComparator` ne compare que les slots `identity && visible_in_portrait` (BOOTH_SCENE §12.2).

### 6.4 Catalogue (données)
Structure fixée par ARCHITECTURE §5.2 : `AppearanceCatalog` (`slots`, `min_distance`, `window_size` = 15) → `AppearanceSlotDef` (`id`, `identity`, `visible_in_portrait`, `options`) → `AppearanceOptionDef` (`id`, `weight`, `faction_weights`, `tags` — ex. `&"family:round_face"` pour les ressemblances familiales —, références visuelles `mesh`, `atlas_cell`, `material`, `portrait_layer`).
L'Asset Lead (avec le Lore Master pour les poids par faction) remplit les options et leurs références visuelles ; le tirage (`AppearanceGenerator`) et l'application (`AppearanceApplier`, `PortraitRenderer`) sont du code (Godot Architect / Gameplay Systems). Les contraintes de compatibilité (§6.3) s'expriment par `tags` — à confirmer avec le Godot Architect. Slots supplémentaires proposés (`marks`, `implants`, `facial_hair`) : BOOTH_SCENE §12.2.

---

## 7. Stylisation cyberpunk (shaders)

### 7.1 `chr_toon.gdshader` (corps, tête, accessoires)
- `render_mode diffuse_toon, specular_toon` ; 2–3 paliers de lumière.
- **Recoloration par zones** : `COLOR.r` → index de zone → couleur d'uniform (`skin_tone`, `top`, `bottom`, `accent`, `shoes`), multipliée par `tex_chr_detail_a` (gris).
- **Rim de Fresnel bicolore** (teintes `world.*` désaturées hors tokens sémantiques — **à valider Design System**) : `rim = pow(1 − dot(NORMAL, VIEW), 3) × 0,6` ; couleur = mélange `world.teal.dim` → `world.rose.dim` selon la normale en X monde (gauche froid, droite chaud), cohérent avec `RimLeft`/`RimRight` (BOOTH_SCENE §5). Intensité ÷ 2 si `fx_intensity` < 1.
- Pas de contour (outline) en MVP (coût et lisibilité à 140 px) ; à tester si les silhouettes se fondent dans le fond.

### 7.2 Implants émissifs
- Surface dédiée, `EMISSION = implant_color × énergie (≤ 1,5)`. Couleur : **cyan** (= donnée comparable avec le bio-scan, DS §1 principe 2) — à valider DS.
- Pulsation lente facultative **≤ 0,5 Hz**, amplitude ≤ 10 % (DS §5 : jamais > 3 Hz). Aucune pulsation en effets « Désactivés ».
- Les types se distinguent par la **forme et l'emplacement**, pas par la couleur (règle couleur + forme du DS).

### 7.3 `face_dither.gdshader` (plaque visage)
- Échantillonne 2 cellules (yeux, bouche) + pupilles + overlay + décals ; uniforms `eyes_cell`, `mouth_cell`, `pupil_offset`, `skin_tone`, `eye_color`, `age_level`, `transition` (0–1).
- Dithering **Bayer 4×4 en espace UV** quantifié à 64×64 par cellule ; 3 tons dérivés de `skin_tone`.
- Transition d'expression = seuil de dither animé sur 120 ms.

### 7.4 `booth_glass.gdshader`, `rain_sheet.gdshader`, `impostor_silhouette.gdshader`
Spécifiés dans BOOTH_SCENE §4.2, §6 et §11. Ils lisent `fx_intensity` (paramètre posé par `BoothDirector` / `BoothQuality`). M9 : `rain_sheet` lit ses paramètres par sommet (3 nappes = 1 maillage) et `layers` (qualité).

### 7.5 Décor définitif (M9) : `booth_decor`, `booth_emissive`, `booth_holo`
Décrits dans BOOTH_SCENE §17.2 : un matériau PBR à `Texture2DArray` pour tout le statique éclairé (couche / mouillé / teinte / métal par sommet, reflets analytiques en émission), un matériau non éclairé pour néons, lettres cuites, écrans et ville, un matériau additif pour hologrammes et voiles.

---

## 8. Réglages d'import Godot

| Type | Réglages |
|---|---|
| **Personnages `.glb`** | Meshes : *Ensure Tangents* ✓, *Generate LODs* ✗ (personnage à distance fixe), *Light Baking* : Disabled ; Skeleton : *Retarget* `bonemap_humanoid.tres` + Rest Fixer (§5.2) ; Materials : *Use External* → `mat_chr_toon.tres` ; Animation : *Import* ✗ (maillages sans clips) |
| **Animations** | *Import As* : Animation Library ; Retarget identique ; FPS 30 ; *Trimming* ✓ ; *Remove Immutable Tracks* ✓ ; Loop par clip ; *Save to File* `.res` |
| **Décor `.glb`** | *Generate LODs* ✓, *Create Shadow Meshes* ✓, *Light Baking* : Static (si on décide d'un bake ; sinon Dynamic), collisions inutiles (décor non traversé hors chemins) |
| **Albedo / détail** | Compress : VRAM Compressed, Mipmaps ✓, sRGB (par défaut) |
| **Normal maps** | *Normal Map* : Enable (compression RGTC), Mipmaps ✓ |
| **ORM / masques** | VRAM Compressed, linéaire (pas sRGB) |
| **Atlas visage / overlay / décals** | **Lossless** (jamais VRAM : la compression détruit le dither), Mipmaps ✗, filtre **Nearest** dans le matériau |
| **Émissifs** | VRAM Compressed, sRGB |
| **HDRI** | `.hdr`/`.exr` 1k ou 2k max, Mipmaps ✓ |
| **Polices / icônes** | Cf. DS §3 et §6 |

Les fichiers `*.import` sont **versionnés** (ARCHITECTURE §3).

**Réglages effectifs M6** (passager) : `chr_kenney_medium.fbx` — LOD ✗, Light Baking Disabled, animations ✗, `retarget/bone_map` = `bonemap_kenney.tres`, squelette renommé `GeneralSkeleton`, Rest Fixer (Apply Node Transforms, Normalize Position Tracks, Fix Silhouette). `anim_ual1_standard.glb` — mêmes réglages de retarget avec `bonemap_ual.tres`, *Remove Immutable Tracks* ✗ ; **écart** : les options *Remove Tracks* (`except_bone_transform`, `unimportant_positions`, `unmapped_bones`) sont **désactivées** — en Godot 4.7.2 elles produisent des erreurs `Index p_track out of bounds` à l'import et vident les clips ; le filtrage (os mappés sans doigts, position de `Hips` seule) est fait par `tools/build_passenger_anims.gd`. Cartes de zones : *Lossless*, mipmaps ✗, `detect_3d/compress_to` = 0, échantillonnage *nearest* dans `chr_toon.gdshader`.

**Régénération complète** : `bash tools/fetch_assets.sh` (sources) → `godot --headless --script res://tools/build_passenger_bonemaps.gd` → `godot --headless --import` → `build_passenger_anims.gd` → `build_passenger_skins.gd` → `build_passenger_impostor.gd`.

**Réglages effectifs M9** (décor du guichet, `tools/build_booth.gd`) :
- Textures : `tex_booth_albedo_rough.png` (albédo sRGB + rugosité en alpha) et `tex_booth_normal_metal.png` (normale OpenGL RG + métal B + occlusion A), 5 couches 512 px empilées verticalement (Lanczos depuis le 1K AmbientCG ; tôle perforée : trous mis au noir via la carte d'opacité) ; importeur **`2d_array_texture`** (`slices/vertical=5`), VRAM Compressed (S3TC/BPTC + ETC2/ASTC), mipmaps ✓, `channel_pack` optimisé. Échantillonnage `filter_linear_mipmap` (sans anisotrope : cadre frontal).
- Maillages : `ArrayMesh` `.res` binaires générés (`ARRAY_FLAG_COMPRESS_ATTRIBUTES`), UID conservés ; aucun `.glb` importé : les modèles Kenney City Kit sont lus à la génération par `GLTFDocument` depuis `art_src/downloads/` (couleurs prises dans `colormap.png`, cellules « ardoise » = vitrages), puis fusionnés.
- Enseignes : `TextMesh` (Chakra Petch Bold / SemiBold) cuits en triangles dans le maillage émissif — pas de `Label3D` (1 draw par étiquette).
- Ordre : `fetch_assets.sh` → `build_booth.gd -- --textures` → `godot --headless --import` → `build_booth.gd`.

---

## 9. Hygiène du dépôt

- `art_src/` contient un `.gdignore` (Godot n'importe rien) ; `art_src/mixamo/` dans `.gitignore`.
- **Git LFS recommandé** pour `*.blend`, `*.glb`, `*.png` > 1 Mo, `*.exr`, `*.hdr` — **à décider** (impact CI / clones).
- Aucun asset ne rentre dans `res://assets/` sans **ligne dans le registre** ci-dessous.
- Crédits en jeu générés à partir de ce registre (colonne Licence ≠ CC0 → attribution obligatoire).

---

## 10. Registre des assets

> Une ligne par asset (ou par pack homogène). **Source** = URL + date de téléchargement. **Modifié ?** = non / oui (+ nature : retopo, recoloration, retarget…).

| Asset | Source | Licence | Auteur | Modifié ? | Chemin |
|---|---|---|---|---|---|
| Chakra Petch SemiBold + Bold | github.com/google/fonts (ofl/chakrapetch), 2026-10-27 | SIL OFL 1.1 | The Chakra Petch Project Authors | non | `assets/fonts/ChakraPetch-*.ttf` + `OFL-ChakraPetch.txt` |
| Inter (variable) | github.com/google/fonts (ofl/inter), 2026-10-27 | SIL OFL 1.1 | The Inter Project Authors | non (renommé `Inter-Variable.ttf`) | `assets/fonts/Inter-Variable.ttf` + `OFL-Inter.txt` |
| JetBrains Mono (variable) | github.com/google/fonts (ofl/jetbrainsmono), 2026-10-27 | SIL OFL 1.1 | The JetBrains Mono Project Authors | non (renommé `JetBrainsMono-Variable.ttf`) | `assets/fonts/JetBrainsMono-Variable.ttf` + `OFL-JetBrainsMono.txt` |
| GUT 9.7.1 (outil de test, hors jeu) | github.com/bitwes/Gut tag v9.7.1, 2026-10-27 | MIT | bitwes | non | `addons/gut/` |
| Kenney **Animated Characters** (Protagonists, Survivors, Retro) — modèle `characterMedium` | kenney.nl/assets/animated-characters-protagonists · -survivors · -retro, 2026-10-27 (`tools/fetch_assets.sh`) | CC0 1.0 | Kenney (kenney.nl) | oui : retarget `SkeletonProfileHumanoid` à l'import ; tête réduite (×0,45) et cou raccourci au rendu | `assets/models/passenger/chr_kenney_medium.fbx` (+ `.import`, `bonemap_kenney.tres`, `License_Kenney.txt`) |
| Kenney Animated Characters — **skins** (8 : criminalMaleA, cyborgFemaleA, skaterFemaleA, skaterMaleA, survivorFemaleA, survivorMaleB, humanFemaleA, humanMaleA ; zombies écartés) | idem | CC0 1.0 | Kenney | oui : converties en **cartes de zones** recolorables (visage peint effacé) par `tools/build_passenger_skins.gd` | sources `art_src/kenney_skins/*.png` (versionnées, non importées) → `assets/textures/passenger/tex_chr_zones_*.png` |
| Quaternius **Universal Animation Library [Standard]** (`UAL1_Standard.glb`, sans root motion) | quaternius.itch.io/universal-animation-library (0 $), 2026-10-27 | CC0 1.0 | Quaternius | oui : retarget profil humanoïde, découpes, redressement de la tête, couches procédurales, repères | `assets/models/passenger/anim_ual1_standard.glb` (+ `.import`, `bonemap_ual.tres`, `License_Quaternius_UAL.txt`) → `passenger_anims.res` |
| Silhouette de file (dérivée du modèle Kenney posé en `idle`, 400 triangles) | généré (`tools/build_passenger_impostor.gd`) | CC0 (dérivé) | Kenney / studio | oui (pose figée + simplification meshoptimizer) | `assets/models/passenger/imp_silhouette.res` |
| Kenney **City Kit (Commercial)** — `building-skyscraper-a…e`, `low-detail-building-b/d/i/l/wide-b` + `colormap.png` | kenney.nl/assets/city-kit-commercial, 2026-10-28 (`tools/fetch_assets.sh`) | CC0 1.0 | Kenney | oui : lus par `GLTFDocument` à la génération, recolorés (silhouettes sombres, vitrages émissifs), mis à l'échelle et inclinés (courbure de l'anneau), fusionnés | dans `assets/models/booth/booth_emissive.res` (sources non versionnées : `art_src/downloads/city-kit-commercial/`) |
| AmbientCG **Metal050C** (métal rayé, « chrome usé ») | ambientcg.com/view?id=Metal050C, 1K-JPG, 2026-10-28 (`fetch_assets.sh`) | CC0 1.0 | AmbientCG (Lennart Demes) | oui : 512 px, recomposé (couche 0) | `assets/textures/booth/tex_booth_albedo_rough.png` + `tex_booth_normal_metal.png` |
| AmbientCG **MetalPlates001** (tôles rivetées) | ambientcg.com/view?id=MetalPlates001, 1K-JPG, 2026-10-28 | CC0 1.0 | AmbientCG | oui : 512 px, couche 1 | idem |
| AmbientCG **Concrete044B** (béton en panneaux, épaufré) | ambientcg.com/view?id=Concrete044B, 1K-JPG, 2026-10-28 | CC0 1.0 | AmbientCG | oui : 512 px, couche 2 | idem |
| AmbientCG **PaintedMetal016** (bandes de danger rouillées) | ambientcg.com/view?id=PaintedMetal016, 1K-JPG, 2026-10-28 | CC0 1.0 | AmbientCG | oui : 512 px, couche 3, teinte assombrie | idem |
| AmbientCG **SheetMetal001** (tôle perforée, grille d'hygiaphone) | ambientcg.com/view?id=SheetMetal001, 1K-JPG, 2026-10-28 | CC0 1.0 | AmbientCG | oui : 512 px, couche 4, trous au noir (opacité) | idem |
| Décor fusionné du guichet (5 maillages) | généré (`tools/build_booth.gd`) | CC0 (dérivé) / studio | studio + sources ci-dessus | — | `assets/models/booth/booth_static_near.res`, `booth_static_far.res`, `booth_emissive.res`, `booth_holo.res`, `booth_rain.res` |

---

## 11. Questions ouvertes

1. Le dépôt est-il (ou sera-t-il) **public** ? Conditionne le versionnage des ressources dérivées de Mixamo (§3).
2. **Git LFS** : oui / non ?
3. ~~Base personnage~~ → **tranché en M6** : Kenney (squelette + maillage) + clips Quaternius UAL retargetés ; tête Kenney réduite pour tenir le cadrage buste (§5.4).
4. Implants en cyan émissif (= information) et palette monde désaturée des rims : **à valider Design System**.
5. M9 : Git LFS pour `assets/textures/booth/*.png` (4,2 Mo) et `assets/models/booth/*.res` (2,2 Mo) ?

*Acquis* : animations Quaternius UAL (CC0) en priorité, Mixamo en complément (Orchestrateur ; D-011 à mettre à jour) ; portrait par rendu du modèle 3D (`PortraitRenderer`).
