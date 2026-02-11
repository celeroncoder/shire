import { useState, useEffect } from 'react'
import { motion } from 'motion/react'
import { Star } from 'lucide-react'

export function Navbar() {
  const [scrolled, setScrolled] = useState(false)

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 50)
    window.addEventListener('scroll', onScroll, { passive: true })
    return () => window.removeEventListener('scroll', onScroll)
  }, [])

  return (
    <motion.nav
      initial={{ y: -20, opacity: 0 }}
      animate={{ y: 0, opacity: 1 }}
      transition={{ duration: 0.5, ease: 'easeOut' }}
      className={`fixed top-0 left-0 right-0 z-50 transition-all duration-300 ${
        scrolled
          ? 'bg-[#09090b]/80 backdrop-blur-xl border-b border-edge'
          : 'bg-transparent'
      }`}
    >
      <div className="max-w-7xl mx-auto px-6 h-16 flex items-center justify-between">
        <a href="#" className="font-display text-2xl text-white tracking-tight">
          Shire
        </a>

        <div className="flex items-center gap-3">
          <a
            href="https://github.com/celeroncoder/shire"
            target="_blank"
            rel="noopener noreferrer"
            className="group inline-flex items-center gap-2 text-sm font-medium text-zinc-300 border border-edge-light px-4 py-2 rounded-full transition-all duration-200 hover:border-zinc-600 hover:text-white hover:bg-white/5"
          >
            <Star className="w-4 h-4 transition-colors group-hover:text-yellow-400" />
            Star
          </a>
          <a
            href="https://github.com/celeroncoder/shire/releases/latest"
            target="_blank"
            rel="noopener noreferrer"
            className="text-sm font-medium text-white bg-accent hover:bg-accent-hover px-5 py-2 rounded-full transition-all duration-200 hover:scale-105 active:scale-95"
          >
            Download
          </a>
        </div>
      </div>
    </motion.nav>
  )
}
