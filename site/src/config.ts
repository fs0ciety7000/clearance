// Configuration publique du site (variables lues au build). Aucune valeur secrète ici.
const env = import.meta.env;

/** Page de téléchargement (GitHub Releases par défaut). */
export const DOWNLOAD_URL: string =
  env.PUBLIC_DOWNLOAD_URL || 'https://github.com/fs0ciety7000/clearance/releases/latest';

/** Version annoncée par le site. */
export const VERSION: string = env.PUBLIC_VERSION || '0.15.0';

/** `1` quand la version ci-dessus est réellement publiée au lien de téléchargement ; sinon « à venir ». */
export const RELEASED: boolean = env.PUBLIC_RELEASED === '1';

/** `1` pour afficher « Jouer dans le navigateur » (export Web validé par le lot W). Désactivé par défaut. */
export const WEB_DEMO: boolean = env.PUBLIC_WEB_DEMO === '1';

/** Adresse de la version Web (export Godot servi sous `public/play/` par défaut). */
export const WEB_DEMO_URL: string = env.PUBLIC_WEB_DEMO_URL || '/play/';

export const GAME_YEAR = 2187;
