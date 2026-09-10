import { fileURLToPath, URL } from 'node:url'

import inertia from '@inertiajs/vite'
import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'

export default defineConfig({
  plugins: [
    tailwindcss(),
    RubyPlugin(),
    inertia(),
    react(),
  ],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./app/frontend', import.meta.url)),
    },
  },
  build: {
    // vite-plugin-ruby 默认开 sourcemap；生产构建不需要，关掉减小 public/vite 体积。
    sourcemap: false,
  },
})
