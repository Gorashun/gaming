import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'se.ferrer.klunk',
  appName: 'KLUNK',
  webDir: 'dist',
  android: {
    allowMixedContent: false,
    backgroundColor: '#0B1020',
  },
  server: {
    androidScheme: 'https',
  },
};

export default config;
