import { useState, Suspense, lazy } from 'react'
import { motion } from 'motion/react'
import { ArrowRight, FolderOpen, FileText } from 'lucide-react'

const Dithering = lazy(() =>
  import('@paper-design/shaders-react').then((mod) => ({
    default: mod.Dithering,
  }))
)

function AppMockup() {
  return (
    <motion.div
      initial={{ opacity: 0, y: 50 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 0.9, duration: 0.8, ease: 'easeOut' }}
      className="mt-16 md:mt-20 max-w-4xl mx-auto w-full px-4"
    >
      <div className="relative rounded-2xl border border-edge/60 bg-surface/70 backdrop-blur-sm overflow-hidden shadow-2xl shadow-accent/5">
        {/* Window chrome */}
        <div className="flex items-center gap-2 px-4 py-3 border-b border-edge/50">
          <div className="flex gap-1.5">
            <div className="w-3 h-3 rounded-full bg-[#ff5f57]/80" />
            <div className="w-3 h-3 rounded-full bg-[#febc2e]/80" />
            <div className="w-3 h-3 rounded-full bg-[#28c840]/80" />
          </div>
          <span className="text-[11px] text-zinc-600 font-mono ml-2">
            Shire
          </span>
        </div>

        {/* App body */}
        <div className="flex h-56 md:h-72">
          {/* Sidebar */}
          <div className="w-44 border-r border-edge/40 p-3 space-y-3 hidden md:block">
            <div className="text-[10px] text-zinc-600 font-semibold uppercase tracking-wider">
              Workspaces
            </div>
            <div className="space-y-1">
              <div className="flex items-center gap-2 px-2 py-1.5 rounded-lg bg-accent/10 text-[11px] text-accent font-medium">
                <FolderOpen className="w-3 h-3" /> my-project
              </div>
              <div className="pl-5 space-y-0.5">
                <div className="text-[10px] text-zinc-400 py-1 px-2 rounded bg-accent/5">
                  Fix auth flow
                </div>
                <div className="text-[10px] text-zinc-600 py-1 px-2">
                  Add API routes
                </div>
                <div className="text-[10px] text-zinc-600 py-1 px-2">
                  Refactor utils
                </div>
              </div>
            </div>
            <div className="flex items-center gap-2 px-2 py-1.5 text-[11px] text-zinc-600">
              <FolderOpen className="w-3 h-3" /> api-server
            </div>
          </div>

          {/* Chat area */}
          <div className="flex-1 p-4 space-y-4 overflow-hidden">
            <div className="flex justify-end">
              <div className="bg-accent/10 rounded-2xl rounded-br-sm px-4 py-2.5 text-[11px] text-zinc-300 max-w-[260px]">
                How do I fix the authentication bug in the login flow?
              </div>
            </div>

            <div className="space-y-2">
              <div className="text-[11px] text-zinc-400 max-w-[300px] leading-relaxed">
                I'll look into the authentication module. Let me read the
                relevant files...
              </div>
              <div className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-white/[0.04] border border-white/[0.06] text-[10px] text-zinc-500 font-mono">
                <FileText className="w-3 h-3 text-accent/60" />
                read_file src/auth/login.ts
              </div>
            </div>

            <div className="flex gap-1 items-center pt-1">
              <div className="w-1.5 h-1.5 rounded-full bg-accent/50 animate-bounce [animation-delay:0ms]" />
              <div className="w-1.5 h-1.5 rounded-full bg-accent/50 animate-bounce [animation-delay:150ms]" />
              <div className="w-1.5 h-1.5 rounded-full bg-accent/50 animate-bounce [animation-delay:300ms]" />
            </div>
          </div>
        </div>

        {/* Bottom fade */}
        <div className="absolute bottom-0 left-0 right-0 h-20 bg-gradient-to-t from-[#09090b] to-transparent pointer-events-none" />
      </div>
    </motion.div>
  )
}

export function Hero() {
  const [isHovered, setIsHovered] = useState(false)

  return (
    <section
      className="relative min-h-screen flex flex-col items-center justify-center overflow-hidden pt-16 pb-8"
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
    >
      {/* Dithering shader background */}
      <Suspense fallback={null}>
        <div className="absolute inset-0 z-0 pointer-events-none opacity-30 mix-blend-screen">
          <Dithering
            colorBack="#00000000"
            colorFront="#EC4E02"
            shape="warp"
            type="4x4"
            speed={isHovered ? 0.6 : 0.2}
            className="size-full"
            minPixelRatio={1}
          />
        </div>
      </Suspense>

      {/* Gradient overlays */}
      <div className="absolute inset-0 bg-gradient-to-b from-[#09090b] via-transparent to-transparent z-[1]" />
      <div className="absolute bottom-0 left-0 right-0 h-48 bg-gradient-to-t from-[#09090b] to-transparent z-[1]" />

      {/* Radial glow */}
      <div className="absolute top-1/3 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] rounded-full bg-accent/[0.06] blur-[120px] pointer-events-none z-[1]" />

      {/* Content */}
      <div className="relative z-10 max-w-5xl mx-auto px-6 text-center flex flex-col items-center">
        <motion.h1
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.3, duration: 0.7 }}
          className="font-display text-6xl md:text-8xl lg:text-9xl font-normal tracking-tight leading-[0.95] mt-24 mb-8"
        >
          Your folders,
          <br />
          <span className="text-accent">supercharged.</span>
        </motion.h1>

        <motion.p
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.5, duration: 0.6 }}
          className="text-zinc-400 text-lg md:text-xl max-w-2xl mx-auto mb-12 leading-relaxed"
        >
          Point Shire at any directory and chat with an AI that can search,
          read, and write your files. A coding assistant grounded in your actual
          project.
        </motion.p>

        {/*<motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.7, duration: 0.6 }}
          className="flex flex-col sm:flex-row items-center justify-center gap-4"
        >
          <a
            href="#waitlist"
            className="group inline-flex h-14 items-center justify-center gap-3 rounded-full bg-accent px-10 text-base font-medium text-white transition-all duration-300 hover:bg-accent-hover hover:scale-105 active:scale-95 hover:shadow-[0_0_40px_rgba(236,78,2,0.3)]"
          >
            Join the Waitlist
            <ArrowRight className="h-5 w-5 transition-transform duration-300 group-hover:translate-x-1" />
          </a>
          <a
            href="#features"
            className="inline-flex h-14 items-center justify-center gap-2 rounded-full border border-edge-light px-8 text-base font-medium text-zinc-300 transition-all duration-300 hover:border-zinc-600 hover:text-white hover:bg-white/5"
          >
            Explore Features
          </a>
        </motion.div>*/}

        <AppMockup />
      </div>
    </section>
  )
}
