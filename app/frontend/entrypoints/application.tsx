import { createInertiaApp } from '@inertiajs/react'

import Layout from '@/components/Layout'

void createInertiaApp({
  pages: "../pages",

  strictMode: true,

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
    visitOptions: () => {
      return { queryStringArrayFormat: "brackets" }
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
