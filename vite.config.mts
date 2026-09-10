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
  optimizeDeps: {
    // radix-ui 只出现在 Inertia 的页面分片里，而页面是动态导入的：dev 首次启动扫不到它，
    // 等第一次访问才补做预构建，产出一份新的 react 分片，与已经加载的 @inertiajs_react
    // 手里那份撞成「两份 React」（Invalid hook call，页面白屏后才自动刷新恢复）。
    // 点名进第一轮预构建就没有第二轮。
    include: ['radix-ui'],
  },
  build: {
    // vite-plugin-ruby 默认开 sourcemap；生产构建不需要，关掉减小 public/vite 体积。
    sourcemap: false,
  },
})
