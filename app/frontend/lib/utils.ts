// shadcn 组件与未来 `npx shadcn add` 生成的文件都从 components.json 的 utils 别名
// （`@/lib/utils`）导入 cn；这里直接转出 shadcn 官方 cn 包（clsx + tailwind-merge 替代品）。
export { cn } from 'cn'
