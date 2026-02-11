import { Suspense, lazy, useRef, useState } from 'react'
import { motion, useInView } from 'motion/react'
import { Download, Star } from 'lucide-react'

const Dithering = lazy(() =>
  import('@paper-design/shaders-react').then((mod) => ({
    default: mod.Dithering,
  }))
)

const GITHUB_REPO = 'https://github.com/celeroncoder/shire'
const DOWNLOAD_URL =
  'https://github.com/celeroncoder/shire/releases/latest'

export function Waitlist() {
  const [isHovered, setIsHovered] = useState(false)
  const ref = useRef(null)
  const isInView = useInView(ref, { once: true, margin: '-100px' })

  return (
    <section id="download" className="py-32 px-6" ref={ref}>
      <motion.div
        initial={{ opacity: 0, y: 40 }}
        animate={isInView ? { opacity: 1, y: 0 } : {}}
        transition={{ duration: 0.7, ease: 'easeOut' }}
        className="max-w-5xl mx-auto relative"
        onMouseEnter={() => setIsHovered(true)}
        onMouseLeave={() => setIsHovered(false)}
      >
        <div className="relative overflow-hidden rounded-[40px] border border-edge bg-surface min-h-[480px] flex flex-col items-center justify-center">
          {/* Dithering background */}
          <Suspense fallback={null}>
            <div className="absolute inset-0 z-0 pointer-events-none opacity-20 mix-blend-screen">
              <Dithering
                colorBack="#00000000"
                colorFront="#EC4E02"
                shape="warp"
                type="4x4"
                speed={isHovered ? 0.5 : 0.15}
                className="size-full"
                minPixelRatio={1}
              />
            </div>
          </Suspense>

          {/* Radial glow */}
          <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[400px] h-[400px] rounded-full bg-accent/[0.04] blur-[80px] pointer-events-none" />

          <div className="relative z-10 px-8 max-w-2xl mx-auto text-center">
            <h2 className="font-display text-4xl md:text-6xl text-white mb-6">
              Try Shire today.
            </h2>
            <p className="text-zinc-400 text-lg mb-10 leading-relaxed">
              The native Claude Code experience for macOS. Download the app or
              star the repo to follow along.
            </p>

            <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
              <a
                href={DOWNLOAD_URL}
                className="group inline-flex h-14 items-center justify-center gap-3 rounded-full bg-accent px-10 text-base font-medium text-white transition-all duration-300 hover:bg-accent-hover hover:scale-105 active:scale-95 hover:shadow-[0_0_40px_rgba(236,78,2,0.3)]"
              >
                <Download className="w-5 h-5" />
                Download for macOS
              </a>
              <a
                href={GITHUB_REPO}
                target="_blank"
                rel="noopener noreferrer"
                className="group inline-flex h-14 items-center justify-center gap-3 rounded-full border border-edge-light px-8 text-base font-medium text-zinc-300 transition-all duration-300 hover:border-zinc-600 hover:text-white hover:bg-white/5"
              >
                <Star className="w-5 h-5 transition-colors group-hover:text-yellow-400" />
                Star on GitHub
              </a>
            </div>
          </div>
        </div>
      </motion.div>
    </section>
  )
}
