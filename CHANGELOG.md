# Changelog — CLEARANCE

## 0.12.0 — 2026-10-29

### M12 « Rejouabilité »
- **Épilogue « Un an plus tard » (J31)** : jour jouable après toute fin de l'Acte III ; 4 mondes, 13 variantes de fin, retrouvailles selon votre partie, conclusion propre à chaque fin ; rejouable depuis le Dossier (D-120, D-122 à D-125).
- **Garde de nuit** : mode endurance — une directive nouvelle tous les 5 passagers parmi 20, paliers d'anomalies plus subtiles, fin à 3 erreurs ; graine du jour `NUIT-AAAA-MM-JJ` ou code libre à partager, records (D-121, D-126 à D-128).
- **Événements de station** : 8 événements (panne de scanner, quarantaine, cartes volées, inspection surprise…), 3 à 6 par campagne, toujours annoncés (D-129, D-136).
- **Échos** : 8 personnages de l'Acte I reviennent selon vos verdicts (D-130).
- **Dossier de l'agent** : fins, personnages, choix, records, épilogues — sans rien gâcher avant la fin de l'histoire (D-131).
- Profil v2 (conversion automatique) ; règles modifiables en cours de shift.

### Corrections
- Passe QA M12 (QA-050 à QA-062) : manette dans les boîtes de confirmation, exemption EV-08 exprimée en passagers en Garde (D-138), conclusions cohérentes avec le foyer, échos pour les sauvegardes 0.11, mémoire des portraits bornée, générateur plus sûr pendant les événements.

## 0.11.0 — 2026-10-29

### M11 « Confort »
- **Sauvegardes** : 3 emplacements, sauvegarde automatique chaque soir avec **reprise de n'importe quel jour passé**, les fins n'effacent plus la partie (archivée « terminée »), progression globale (fins vues, personnages croisés). Conversion automatique des sauvegardes 0.10.0 (D-101, D-117).
- **Mode Récit** : pas de chrono, pas d'amendes, toutes les fins accessibles, foyer et arrestations adoucis ; passage en Dur possible à tout moment, jamais l'inverse (D-102, D-118).
- **Écrans de partie** : Continuer, Nouvelle partie (emplacement + difficulté), Charger (cartes d'emplacement, reprise d'un jour, suppression en deux temps).
- **Tutoriel interactif du J1** en 6 étapes, passable, réactivable dans les options.
- **Manette complète** (Xbox, PlayStation, Steam Deck) : focus sur tous les écrans, invites qui suivent le périphérique utilisé.
- **Vision des couleurs** : 4 modes, et aucune information portée par la seule couleur ; réglage séparé du scintillement holographique (guichet 3D compris).
- **Carte d'identité redessinée** : valeurs à 13 px en 1080p et 12 px sur Steam Deck.

### Corrections
- Passe QA M11 (QA-041 à QA-049) : Ⓐ suit le focus entre deux passagers, tutoriel joignable à la manette, sauvegardes endommagées signalées et récupérées, passage en Dur persisté immédiatement, néons du guichet sans scintillement quand l'option est coupée.

## 0.10.0 — 2026-10-29

### Acte III « Témoins » — jours 21 à 30
- **J20** devient un pivot obligatoire (carte « FIN DE L'ACTE II », soirée « Nuit du 1ᵉʳ avril ») ; interstitiel « Chapitre III · Témoins » (D-086).
- **Nouvelles mécaniques** : **Répondants** — un passager n'est admissible que si son garant a été admis le jour même (onglet Main courante) ; **Retour aux quais** (le ticket de file et le bio-scan disparaissent) ; **Enquête** et **Déposition** du J29 (D-087).
- **Contenu** : nouvelles règles et anomalies, cas scénarisés de l'Acte III, briefings et soirées J20–J29 ; aides conditionnelles seulement (D-089).
- **Fins** : 10 fins au J30, dont **F10 « Le Pont »** (familles de Tycho admises en règle) ; figure finale Dora ou Mira (D-088).
- Sauvegarde **v5** (conversion automatique des sauvegardes 0.9.x).

### Corrections (QA-032 à QA-040)
- Manuel des règles à une seule rangée d'onglets défilante, date du jour dans le pied (D-097).
- Bandeau de résultat dans l'en-tête du plan de travail, plus de chevauchement avec les documents ; soirée défilante (D-098).
- Objets glissés dessinés selon leur type ; en-tête du passager sur deux lignes ; convocations falsifiées jamais générées sans carte d'identité ; équilibrage de l'Acte III (D-099, D-100) ; sortie du jeu plus sûre côté audio.

## 0.9.0 — 2026-10-28

### Acte II — jours 11 à 20
- **J10 « Nuit des vannes »** devient un pivot avec soirée (D-076) ; interstitiel « Chapitre II · Rééquilibrage ».
- **Nouvelles mécaniques** : quota respiratoire du guichet (souple, D-077), rations d'air du foyer, scanner partiel (version Consortium ou Lucioles) avec liens suggérés à confirmer.
- **Contenu** : règles R23–R31, nouveaux documents (contrat de travail…), 4 nouvelles anomalies, onglets Employeurs / Vaisseaux / Révocations, 28 cas scénarisés (SC-23 à SC-50) avec 4 nouveaux personnages récurrents et des retours de l'Acte I, briefings et soirées J10–J19, prélèvements sur l'épargne (J11, J17).
- **Fins** : 9 fins au J20, dont **F8 « Le Registre »** et **F9 « Les vitres éteintes »** (D-078) ; figure finale Ilan ou Mira (D-079) ; lumières coupées au J20.
- Sauvegarde **v4** (conversion automatique des sauvegardes 0.8.x).

### Corrections
- Plantage intermittent au rechargement de scène (course dans le mixage audio de Godot 4.7.2, contournée, D-083).
- Plan de travail lisible à 4–5 documents (côte à côte ou piles à onglets, D-085) ; barre du haut adaptée au texte agrandi ; boîte « Embarquer » modale ; textes manquants ; homonymes des personnages de l'Acte II ; robustesse au rechargement en plein shift ; le générateur de données échoue clairement en cas d'erreur.

## 0.8.1 — 2026-10-28

### Rendu et performances
- **Décor définitif du guichet** : guichet blindé en chrome usé, vitre avec condensation, hall et baie sur la ville de l'Anneau, textures AmbientCG (CC0). Décor : 56 → 7 draw calls (D-073).
- **Personnages optimisés** : pièces d'apparence fusionnées en un maillage skinné par acteur, matériau unique, cache partagé avec les portraits. Passager : 27 → 4 draw calls ; J1 : 84 → 11 au total ; J7 détention + escorte : 87 → 15 (D-075).
- **Option « Qualité graphique »** : Auto / Bas / Moyen / Élevé (Auto = Moyen sur Steam Deck) (D-074).
- Génération déterministe de la scène du guichet et de la silhouette de la file d'attente.

## 0.8.0 — 2026-10-28

Première version complète : campagne jours 1 à 10 avec 7 fins, passager animé (Kenney + Quaternius, CC0), audio complet, détention, objets glissés, avis de recherche, Lucioles, soirées à choix ; passe QA (17 bugs corrigés) ; exports Windows / macOS / Linux (Steam Deck).
