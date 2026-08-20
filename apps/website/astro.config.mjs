import { defineConfig } from 'astro/config';
import cloudflare from '@astrojs/cloudflare';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  output: 'server',
  adapter: cloudflare(),
  site: 'https://debt-manager.app',
  vite: {
    plugins: [tailwindcss()],
  },
});
