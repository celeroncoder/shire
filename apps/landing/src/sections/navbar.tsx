import { useState, useEffect } from 'react'
import { motion } from 'motion/react'

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

        <a
          href="#waitlist"
          className="text-sm font-medium text-white bg-accent hover:bg-accent-hover px-5 py-2 rounded-full transition-all duration-200 hover:scale-105 active:scale-95"
        >
          Join Waitlist
        </a>
      </div>
    </motion.nav>
  )
}
