import { createInertiaApp } from '@inertiajs/react'

import Layout from '@/components/Layout'
import { loadContentFonts } from '@/lib/contentFonts'
import { restoreHistoryScroll } from '@/lib/historyScroll'
import { markFirstLoad } from '@/lib/motion'
import { focusMainOnNavigate } from '@/lib/navigationFocus'
import { crossfadeFor } from '@/lib/pageTurn'

// 登录与常用阅读页随入口加载，避免应用启动后再串行等待页面分片；其他页面仍按需加载。
import '@/pages/Login/Show'
import '@/pages/Daily/Show'
import '@/pages/Weekly/Show'

loadContentFonts()
restoreHistoryScroll()
focusMainOnNavigate()
markFirstLoad()

void createInertiaApp({
  pages: "../pages",

  strictMode: true,
  title: (title) => `${title} · Lowpass`,

  // 持久布局：默认给每个页面套 Layout（报头/页脚），跨页跳转时 Layout 不重新挂载
  // （React 按元素类型在同一位置做 reconciliation，不看是哪个函数生成的 JSX）。
  // 页面需要非默认的 masthead/footer props（比如高亮当前导航项）时，在页面文件里覆盖
  // 自己的 `<PageComponent>.layout`，例如 Home.tsx 的写法；Task 17 沿用同一模式。
  layout: () => Layout,

  // Inertia 默认进度条是亮蓝色 #29d 带光晕；换成墨色细线，不用发光/阴影。
  progress: {
    color: '#1D1D1B',
    includeCSS: false,
    showSpinner: false,
  },

  defaults: {
    form: {
      forceIndicesArrayFormatInFormData: false,
      withAllErrors: true,
    },
    visitOptions: (href, options) => {
      return { queryStringArrayFormat: "brackets", ...crossfadeFor(href, options) }
    },
  },
}).catch((error) => {
  // This ensures this entrypoint is only loaded on Inertia pages
  // by checking for the presence of the root element (#app by default).
  // Feel free to remove this `catch` if you don't need it.
  if (document.getElementById("app")) {
    throw error
  } else {
    console.error(
      "Missing root element.\n\n" +
      "If you see this error, it probably means you loaded Inertia.js on non-Inertia pages.\n" +
      'Consider moving <%= vite_typescript_tag "application.tsx" %> to the Inertia-specific layout instead.',
    )
  }
})
