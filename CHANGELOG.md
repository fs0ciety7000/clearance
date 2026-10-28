# Changelog — CLEARANCE

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
