import fr, { type Dict } from '../i18n/fr';
import en from '../i18n/en';

export type Lang = 'fr' | 'en';
export const dicts: Record<Lang, Dict> = { fr, en };
export const t = (lang: Lang): Dict => dicts[lang];
export const homePath = (lang: Lang): string => (lang === 'fr' ? '/' : '/en/');
/** Page « Compte et confidentialité » (M16, lot W). */
export const privacyPath = (lang: Lang): string => (lang === 'fr' ? '/confidentialite/' : '/en/privacy/');
