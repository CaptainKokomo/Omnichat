import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';
import { fileURLToPath } from 'url';

const rootDir = path.dirname(fileURLToPath(new URL('.', import.meta.url)));
const isDev = process.env.NODE_ENV === 'development';

export default defineConfig({
  base: isDev ? '/' : './',
  plugins: [react()],
  build: {
    outDir: 'dist/renderer',
    sourcemap: true
  },
  resolve: {
    alias: {
      '@shared': path.resolve(rootDir, 'shared')
    }
  },
  server: {
    port: 5173,
    strictPort: true
  }
});
