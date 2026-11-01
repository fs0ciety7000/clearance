// Liens directs vers les fichiers de la Release GitHub de `VERSION`.
// Les noms suivent `tools/export_all.sh` / `.github/workflows/build.yml` (Release v1.1.0).
// Seuls les liens directs dépendent de `RELEASED` : tant que la version n'est pas publiée,
// les composants gardent le bouton générique vers `DOWNLOAD_URL` (aucun lien mort).
import { DOWNLOAD_URL, REPO_URL, VERSION } from '../config';

/** Page Releases (toutes les versions) : `DOWNLOAD_URL` sans `/latest`, sinon `REPO_URL/releases`. */
export const RELEASES_URL: string = (() => {
  const u = DOWNLOAD_URL.replace(/\/latest\/?$/, '').replace(/\/$/, '');
  return /\/releases$/.test(u) ? u : `${REPO_URL.replace(/\/$/, '')}/releases`;
})();

/** Dossier des fichiers de la Release `v${VERSION}`. */
export const RELEASE_BASE = `${RELEASES_URL}/download/v${VERSION}`;

/** Page de la Release de cette version (notes de version, liste des fichiers). */
export const RELEASE_PAGE = `${RELEASES_URL}/tag/v${VERSION}`;

export type Os = 'windows' | 'macos' | 'linux';
export type Edition = 'full' | 'demo';
export type Kind = 'installer' | 'archive';

const v = VERSION;
/** Noms de fichiers par édition, plateforme et type (installeur / archive portable). */
const NAMES: Record<Edition, Record<Os, Record<Kind, string>>> = {
  full: {
    windows: { installer: `CLEARANCE-Setup-${v}.exe`, archive: `CLEARANCE-${v}-windows.zip` },
    macos: { installer: `CLEARANCE-${v}.dmg`, archive: `CLEARANCE-${v}-macos.zip` },
    linux: { installer: `CLEARANCE-${v}-x86_64.AppImage`, archive: `CLEARANCE-${v}-linux.tar.gz` },
  },
  demo: {
    windows: { installer: `CLEARANCE-Demo-Setup-${v}.exe`, archive: `CLEARANCE-${v}-demo-windows.zip` },
    macos: { installer: `CLEARANCE-Demo-${v}.dmg`, archive: `CLEARANCE-${v}-demo-macos.zip` },
    linux: { installer: `CLEARANCE-Demo-${v}-x86_64.AppImage`, archive: `CLEARANCE-${v}-demo-linux.tar.gz` },
  },
};

/**
 * Tailles affichées, en Mio arrondis (« 62 Mo »), relevées sur la Release v1.1.0.
 * Approximatives et communes jeu complet / démo (écart < 1 Mo) : elles bougent peu d'une
 * version à l'autre. À AJUSTER si une version change nettement la taille des builds
 * (`curl -sIL <url>` → `content-length`, ÷ 1 048 576).
 */
const SIZES_MB: Record<Os, Record<Kind, number>> = {
  windows: { installer: 62, archive: 76 }, // 64 664 363 o · 79 221 348 o
  macos: { installer: 97, archive: 97 }, // 101 749 749 o · 101 698 616 o
  linux: { installer: 64, archive: 66 }, // 67 283 448 o · 69 452 923 o
};

/** Extension affichée (`.exe`, `.dmg`, `.AppImage`, `.zip`, `.tar.gz`). */
const ext = (name: string): string => (name.endsWith('.tar.gz') ? '.tar.gz' : name.slice(name.lastIndexOf('.')));

export interface DlFile { name: string; url: string; ext: string; sizeMb: number }

export const file = (edition: Edition, os: Os, kind: Kind): DlFile => {
  const name = NAMES[edition][os][kind];
  return { name, url: `${RELEASE_BASE}/${name}`, ext: ext(name), sizeMb: SIZES_MB[os][kind] };
};

/** Sommes SHA-256 : archives du jeu, installeurs, démo. */
export const CHECKSUMS = ['SHA256SUMS', 'SHA256SUMS-installers', 'SHA256SUMS-demo'].map((name) => ({
  name,
  url: `${RELEASE_BASE}/${name}`,
}));

/** Toutes les URL générées (vérification : `node` + `curl -sIL`). */
export const allUrls = (): string[] => [
  ...(['full', 'demo'] as const).flatMap((e) =>
    (['windows', 'macos', 'linux'] as const).flatMap((o) => (['installer', 'archive'] as const).map((k) => file(e, o, k).url)),
  ),
  ...CHECKSUMS.map((c) => c.url),
];
