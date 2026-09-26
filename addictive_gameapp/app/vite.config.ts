import { defineConfig } from 'vite';
// Shared with the Android workflow (versionName/versionCode).
import { appVersion } from './scripts/version.mjs';

const version = appVersion().name;

export default defineConfig({
  base: './',
  server: { host: true, port: 5173 },
  build: { target: 'es2022' },
  // Build version (docs/RELEASE.md): read via src/data/version.ts, shown in the debug panel.
  define: { __APP_VERSION__: JSON.stringify(version) },
});
