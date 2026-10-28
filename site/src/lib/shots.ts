import type { ImageMetadata } from 'astro';

// Captures réelles du jeu (docs/mockups). Clé = nom de fichier sans extension.
const files = import.meta.glob<{ default: ImageMetadata }>('../assets/shots/*.png', { eager: true });
export const shots: Record<string, ImageMetadata> = Object.fromEntries(
  Object.entries(files).map(([path, mod]) => [path.split('/').pop()!.replace('.png', ''), mod.default]),
);
export const shot = (key: string): ImageMetadata => {
  const img = shots[key];
  if (!img) throw new Error(`Capture inconnue : ${key}`);
  return img;
};
