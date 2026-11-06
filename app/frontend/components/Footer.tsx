import { Link } from '@inertiajs/react'
import { Ctrl } from '@/components/Ctrl'
import { DAILY_ARCHIVE, WEEKLY_ARCHIVE } from '@/lib/paths'

export type FooterProps = {
  nextAt?: string
  latestWeeklyHref?: string
  prevHref?: string | null
  nextHref?: string | null
}

export default function Footer({ nextAt = '06:00', latestWeeklyHref = WEEKLY_ARCHIVE, prevHref = null, nextHref = null }: FooterProps) {
  return (
    <footer className="site-footer">
      <div className="footer-publication"><span className="footer-wordmark">Lowpass</span><span>每天 {nextAt} · 技术日刊</span></div>
      <nav className="footer-links" aria-label="刊物归档"><Link href={DAILY_ARCHIVE}>日刊归档</Link><Link href={latestWeeklyHref}>最新周刊</Link></nav>
      {prevHref || nextHref ? <nav className="footer-turns" aria-label="继续阅读"><Ctrl href={prevHref} label="上一期" icon="chevron-left" side="left" turn="back" /><Ctrl href={nextHref} label="下一期" icon="chevron-right" side="right" turn="forward" /></nav> : null}
    </footer>
  )
}
