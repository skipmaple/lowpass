import { fileURLToPath, URL } from 'node:url'

import react from '@vitejs/plugin-react'
import { defineConfig } from 'vitest/config'

// 前端单元测试的配置与 vite.config.mts 分开。那边的三个插件都是为「Rails 里的构建产物」
// 准备的：vite-plugin-ruby 要读 config/vite.json 并把入口重写到 public/vite*，@inertiajs/vite
// 管页面分片，@tailwindcss/vite 会去编 application.css。jsdom 里跑单元测试一个都用不上，
// 留着只会拖慢启动并把 css: false 的省事又还回去。这里只保留 JSX 转换与 @ 别名。
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./app/frontend', import.meta.url)),
    },
  },
  test: {
    environment: 'jsdom',
    // 不注入全局 describe/it/expect：测试文件自己从 vitest import，跟 app/frontend 一样按显式依赖读
    globals: false,
    setupFiles: ['test/frontend/setup.ts'],
    // 测试放在 test/frontend/（跟 Ruby 的 test/ 同级），不混进 app/frontend
    include: ['test/frontend/**/*.test.{ts,tsx}'],
    // 组件的字体、字号、颜色都是行内样式里的令牌变量，断言读的是 style 属性本身，不需要真的编 CSS
    css: false,
  },
})
