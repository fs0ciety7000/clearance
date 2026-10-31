import type { ImageMetadata } from 'astro';
import type { Lang } from './i18n';

// Captures réelles du jeu (docs/mockups). Clé = nom de fichier sans extension.
// PNG historiques (≤ M9) et WebP pré-optimisés (M11+) ; astro:assets produit ensuite AVIF/WebP responsives.
const files = import.meta.glob<{ default: ImageMetadata }>('../assets/shots/*.{png,webp}', { eager: true });
export const shots: Record<string, ImageMetadata> = Object.fromEntries(
  Object.entries(files).map(([path, mod]) => [path.split('/').pop()!.replace(/\.(png|webp)$/, ''), mod.default]),
);

// QA-092 : sur la page anglaise, capture équivalente du jeu en anglais (docs/mockups/m15_en_*, WebP).
// Captures d'interface sans rendu 3D (conteneur sans GPU) ; les captures sans équivalent anglais
// (3D seule, enseignes diégétiques D-228, ou écran non recapturé) restent les mêmes dans les deux langues.
const english: Record<string, string> = {
  m9_booth_j1: 'm15_en_shift',
  m9_booth_j1_deck: 'm15_en_shift_deck',
  m5_briefing: 'm15_en_briefing',
  m5_summary: 'm15_en_summary',
  m5_evening: 'm15_en_evening',
  m11_a11y_options: 'm15_en_pause',
  m13_search: 'm15_en_search',
  m8_symbol_report: 'm15_en_rb_symbols',
  m12_garde_shift: 'm15_en_garde_end',
};

export const shot = (key: string, lang: Lang = 'fr'): ImageMetadata => {
  const name = lang === 'en' && english[key] ? english[key] : key;
  const img = shots[name];
  if (!img) throw new Error(`Capture inconnue : ${name}`);
  return img;
};
