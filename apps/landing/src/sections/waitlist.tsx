import { useState, Suspense, lazy, useRef, type FormEvent } from 'react'
import { motion, useInView } from 'motion/react'
import { ArrowRight, Check } from 'lucide-react'

const Dithering = lazy(() =>
  import('@paper-design/shaders-react').then((mod) => ({
    default: mod.Dithering,
  }))
)

export function Waitlist() {
  const [email, setEmail] = useState('')
  const [submitted, setSubmitted] = useState(false)
  const [isHovered, setIsHovered] = useState(false)
  const ref = useRef(null)
  const isInView = useInView(ref, { once: true, margin: '-100px' })

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault()
    if (email.trim()) setSubmitted(true)
  }

  return (
    <section id="waitlist" className="py-32 px-6" ref={ref}>
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
              Be the first to try Shire.
            </h2>
            <p className="text-zinc-400 text-lg mb-10 leading-relaxed">
              We're building the future of local-first AI coding. Join the
              waitlist for early access.
            </p>

            {submitted ? (
              <motion.div
                initial={{ opacity: 0, scale: 0.9 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ duration: 0.4 }}
                className="inline-flex items-center gap-3 bg-accent/10 border border-accent/20 rounded-full px-8 py-4 text-accent"
              >
                <Check className="w-5 h-5" />
                <span className="font-medium">
                  You're on the list. We'll be in touch.
                </span>
              </motion.div>
            ) : (
              <form
                onSubmit={handleSubmit}
                className="flex flex-col sm:flex-row items-center gap-3 max-w-md mx-auto"
              >
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="you@example.com"
                  required
                  className="w-full h-14 px-6 rounded-full bg-[#09090b] border border-edge-light text-white placeholder:text-zinc-600 focus:outline-none focus:border-accent/50 focus:ring-2 focus:ring-accent/20 transition-all font-body text-sm"
                />
                <button
                  type="submit"
                  className="group flex-shrink-0 inline-flex h-14 items-center justify-center gap-2 rounded-full bg-accent px-8 text-base font-medium text-white transition-all duration-300 hover:bg-accent-hover hover:scale-105 active:scale-95 hover:shadow-[0_0_40px_rgba(236,78,2,0.3)] cursor-pointer"
                >
                  Join
                  <ArrowRight className="w-4 h-4 transition-transform duration-200 group-hover:translate-x-0.5" />
                </button>
              </form>
            )}
          </div>
        </div>
      </motion.div>
    </section>
  )
}
