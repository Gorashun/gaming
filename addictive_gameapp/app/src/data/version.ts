/**
 * Build version (docs/RELEASE.md §Versioning): `<major>.<minor>.<commit count>+<short sha>`.
 * Vite replaces `__APP_VERSION__` at build time; in Vitest (no define) it is 'dev'.
 */
export const APP_VERSION: string = typeof __APP_VERSION__ === 'string' ? __APP_VERSION__ : 'dev';
