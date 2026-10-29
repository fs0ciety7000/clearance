// @ts-check
import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

const site = process.env.SITE_URL ?? 'https://clearance.cardormedia.com';

export default defineConfig({
  site,
  trailingSlash: 'ignore',
  build: { inlineStylesheets: 'always', format: 'directory' },
  compressHTML: true,
  i18n: {
    defaultLocale: 'fr',
    locales: ['fr', 'en'],
    routing: { prefixDefaultLocale: false },
  },
  image: { responsiveStyles: false },
  integrations: [
    sitemap({
      filter: (page) => !page.includes('/404'),
      i18n: { defaultLocale: 'fr', locales: { fr: 'fr', en: 'en' } },
    }),
  ],
  prefetch: false,
});
