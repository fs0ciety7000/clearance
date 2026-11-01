# Paquet AUR `clearance-bin`

Paquet Arch Linux (Arch, Garuda, Manjaro, EndeavourOS…) qui installe le **binaire officiel** de la Release GitHub : il télécharge `CLEARANCE-<version>-linux.tar.gz`, vérifie son SHA-256, puis installe :

| Chemin | Contenu |
|---|---|
| `/opt/clearance/` | `CLEARANCE.x86_64` + `CLEARANCE.pck` |
| `/usr/bin/clearance` | lien vers le binaire (Godot retrouve le `.pck` à côté de l'exécutable réel) |
| `/usr/share/applications/clearance.desktop` | lanceur (menu des applications) |
| `/usr/share/icons/hicolor/{16…512}/apps/clearance.png`, `scalable/apps/clearance.svg` | icônes |
| `/usr/share/licenses/clearance-bin/` | `CREDITS.txt` + licences (Godot MIT, polices OFL, modèles CC0) |

Fichiers du dépôt AUR (dossier `clearance-bin/`) : `PKGBUILD`, `.SRCINFO` (généré), `clearance.desktop`, `LICENSE` (0BSD, couvre les fichiers de packaging, usage recommandé par l'AUR). Détails : `docs/ARCHITECTURE.md` §16.9.

> **Prérequis côté GitHub** : les assets de la Release doivent être téléchargeables **sans authentification** (dépôt public, ou Releases publiées ailleurs). Sinon `makepkg` des utilisateurs échouera au téléchargement. La Release doit aussi être postérieure à l'archive Linux avec `icons/` (version ≥ 1.0.0 construite par la CI actuelle) : `tools/update_aur.sh` le vérifie.
>
> Ne publier sur l'AUR que des versions **stables** (`X.Y.Z`) : une pré-version `1.1.0-rc1` deviendrait `pkgver=1.1.0_rc1`, mal ordonnée par `vercmp`.

## 1. Une fois : compte AUR et clé SSH

1. Créer un compte sur <https://aur.archlinux.org/register> (nom d'utilisateur, e-mail).
2. Créer une clé SSH dédiée et la déclarer dans le profil AUR (*My Account › SSH Public Key*) :
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/aur -C "aur clearance-bin"
   cat ~/.ssh/aur.pub          # à coller dans le profil AUR
   ```
3. Dire à SSH d'utiliser cette clé pour l'AUR (`~/.ssh/config`) :
   ```
   Host aur.archlinux.org
     IdentityFile ~/.ssh/aur
     User aur
   ```
4. Remplacer la ligne `# Maintainer: NOM <e-mail>` en tête de `PKGBUILD` par vos nom et e-mail publics (dans ce dépôt, puis à chaque copie).

## 2. À chaque Release (`git tag vX.Y.Z && git push origin vX.Y.Z`)

Attendre la fin du workflow **Build** (Release GitHub publiée avec `SHA256SUMS`), puis, depuis la racine de ce dépôt :

```bash
bash tools/update_aur.sh X.Y.Z          # télécharge l'archive, recoupe avec SHA256SUMS,
                                        # écrit _relver, pkgrel=1, sha256sums et .SRCINFO
git diff packaging/aur/                 # relire
```

`update_aur.sh` utilise `gh` s'il est connecté (dépôt privé), sinon `curl`. Sur Arch, il génère `.SRCINFO` avec `makepkg --printsrcinfo` ; ailleurs (ou en root), un générateur interne au format identique (vérifié contre pacman 6.0 et 7.1). `--pkgrel N` : nouvelle révision sans changement de version (PKGBUILD corrigé).

Tester la construction (sur Arch / Garuda, utilisateur normal) :

```bash
cd packaging/aur/clearance-bin
makepkg -si                 # télécharge, vérifie, construit et installe
namcap PKGBUILD clearance-bin-*.pkg.tar.zst   # facultatif (pacman -S namcap)
clearance                   # lance le jeu
rm -rf src pkg *.pkg.tar.* CLEARANCE-*.tar.gz # nettoyage avant copie
```

Avertissements `namcap` attendus et sans conséquence : « Dependency included, but may not be needed » pour les bibliothèques X11 / Vulkan / ALSA / fontconfig (le binaire Godot les charge à l'exécution par `dlopen`, elles sont bien nécessaires) et « Reference to x86_64 should be changed to $CARCH » (nom du binaire `CLEARANCE.x86_64`).

## 3. Publication sur l'AUR

Première publication (le dépôt `clearance-bin` est créé par le premier push) :

```bash
git clone ssh://aur@aur.archlinux.org/clearance-bin.git ~/aur/clearance-bin
cp packaging/aur/clearance-bin/{PKGBUILD,clearance.desktop,LICENSE} ~/aur/clearance-bin/
cd ~/aur/clearance-bin
makepkg --printsrcinfo > .SRCINFO      # (ou copier packaging/aur/clearance-bin/.SRCINFO)
git add PKGBUILD .SRCINFO clearance.desktop LICENSE
git commit -m "clearance-bin X.Y.Z-1"
git push origin master                  # la branche de l'AUR s'appelle master
```

Mises à jour suivantes : `git -C ~/aur/clearance-bin pull`, recopier les fichiers après `tools/update_aur.sh`, régénérer `.SRCINFO`, `git commit -m "clearance-bin X.Y.Z-1"`, `git push`. La page du paquet est ensuite <https://aur.archlinux.org/packages/clearance-bin>.

Rappels AUR : `.SRCINFO` doit toujours correspondre au `PKGBUILD` poussé ; ne jamais pousser d'artefacts (`*.pkg.tar.*`, archives, `src/`, `pkg/`) ; la licence du jeu lui-même (`LicenseRef-CLEARANCE`) est décrite par `CREDITS.txt`, installé dans `/usr/share/licenses/clearance-bin/`.

## Installation pour les joueurs (Arch / Garuda)

```bash
yay -S clearance-bin        # ou paru -S clearance-bin ; Garuda : aussi via « pamac »
```

Sans AUR : l'**AppImage** (`CLEARANCE-<version>-x86_64.AppImage`, `chmod +x` puis lancer ; runtime statique : seul `fusermount3` (paquet `fuse3`) est requis, sinon `--appimage-extract-and-run`) ou l'archive `.tar.gz` avec `./install.sh` (README › Builds).
