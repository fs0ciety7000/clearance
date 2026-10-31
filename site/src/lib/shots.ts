import type { ImageMetadata } from 'astro';

// Captures réelles du jeu (docs/mockups). Clé = nom de fichier sans extension.
// PNG historiques (≤ M9) et WebP pré-optimisés (M11+) ; astro:assets produit ensuite AVIF/WebP responsives.
const files = import.meta.glob<{ default: ImageMetadata }>('../assets/shots/*.{png,webp}', { eager: true });
export const shots: Record<string, ImageMetadata> = Object.fromEntries(
  Object.entries(files).map(([path, mod]) => [path.split('/').pop()!.replace(/\.(png|webp)$/, ''), mod.default]),
);
export const shot = (key: string): ImageMetadata => {
  const img = shots[key];
  if (!img) throw new Error(`Capture inconnue : ${key}`);
  return img;
};
