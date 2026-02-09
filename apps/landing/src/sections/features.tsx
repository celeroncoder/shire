import { useRef } from 'react'
import { motion, useInView } from 'motion/react'
import {
  FolderOpen,
  MessageSquare,
  Wrench,
  Zap,
  Database,
  FileOutput,
  Monitor,
} from 'lucide-react'

type Feature = {
  id: string
  icon: typeof FolderOpen
  title: string
  description: string
  span: 1 | 2
}

const features: Feature[] = [
  {
    id: 'workspace',
    icon: FolderOpen,
    title: 'Workspace Management',
    description:
      'Create and manage workspaces backed by real directories. Each workspace scopes the AI entirely to your project.',
    span: 2,
  },
  {
    id: 'chat',
    icon: MessageSquare,
    title: 'Streaming Chat',
    description:
      'Multi-turn conversations with streaming responses. Rich markdown rendering with syntax highlighting.',
    span: 1,
  },
  {
    id: 'tools',
    icon: Wrench,
    title: 'Five AI Tools',
    description:
      'File search, content search, file read, file write, and directory listing — all sandboxed to your workspace.',
    span: 1,
  },
  {
    id: 'provider',
    icon: Zap,
    title: 'Multi-Provider',
    description:
      'Anthropic, OpenAI, or any compatible endpoint. Run local models via Ollama or LMStudio.',
    span: 1,
  },
  {
    id: 'persistence',
    icon: Database,
    title: 'Full Persistence',
    description:
      'Messages, tool calls, and results stored in SQLite. Pick up exactly where you left off.',
    span: 1,
  },
  {
    id: 'artifacts',
    icon: FileOutput,
    title: 'Artifact Tracking',
    description:
      'AI-generated files are tracked as artifacts, linked to the session and message that created them.',
    span: 1,
  },
  {
    id: 'native',
    icon: Monitor,
    title: 'Native Desktop Feel',
    description:
      'Frameless window, macOS vibrancy, native context menus, and keyboard shortcuts. Feels like it belongs on your machine.',
    span: 2,
  },
]

function WorkspaceVisual() {
  const items = ['my-project', 'api-server', 'docs']
  return (
    <div className="flex flex-wrap gap-2 mt-5">
      {items.map((name) => (
        <div
          key={name}
          className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-white/[0.04] border border-white/[0.06] text-xs text-zinc-500"
        >
          <FolderOpen className="w-3 h-3 text-accent/70" />
          {name}
        </div>
      ))}
    </div>
  )
}

function NativeDesktopVisual() {
  return (
    <div className="mt-5 rounded-xl border border-white/[0.06] bg-white/[0.02] overflow-hidden max-w-[200px]">
      <div className="flex items-center gap-1.5 px-3 py-2 border-b border-white/[0.06]">
        <div className="w-2 h-2 rounded-full bg-[#ff5f57]" />
        <div className="w-2 h-2 rounded-full bg-[#febc2e]" />
        <div className="w-2 h-2 rounded-full bg-[#28c840]" />
        <span className="text-[10px] text-zinc-600 ml-1.5 font-mono">
          Shire
        </span>
      </div>
      <div className="p-3 space-y-1.5">
        <div className="h-1.5 w-16 bg-accent/20 rounded-full" />
        <div className="h-1.5 w-24 bg-white/[0.05] rounded-full" />
        <div className="h-1.5 w-20 bg-white/[0.04] rounded-full" />
        <div className="h-1.5 w-14 bg-white/[0.03] rounded-full" />
      </div>
    </div>
  )
}

function FeatureCard({
  feature,
  index,
}: {
  feature: Feature
  index: number
}) {
  const ref = useRef(null)
  const isInView = useInView(ref, { once: true, margin: '-60px' })
  const Icon = feature.icon

  return (
    <motion.div
      ref={ref}
      initial={{ opacity: 0, y: 30 }}
      animate={isInView ? { opacity: 1, y: 0 } : {}}
      transition={{ delay: index * 0.08, duration: 0.5, ease: 'easeOut' }}
      className={`group relative rounded-3xl border border-edge bg-surface p-8 transition-all duration-300 hover:border-accent/20 hover:shadow-[0_0_80px_-20px_rgba(236,78,2,0.12)] ${
        feature.span === 2 ? 'md:col-span-2' : ''
      }`}
    >
      <div className="flex items-start gap-4">
        <div className="flex-shrink-0 w-12 h-12 rounded-2xl bg-accent/10 flex items-center justify-center group-hover:bg-accent/15 transition-colors duration-300">
          <Icon className="w-5 h-5 text-accent" />
        </div>
        <div className="min-w-0">
          <h3 className="text-lg font-semibold text-white mb-2">
            {feature.title}
          </h3>
          <p className="text-zinc-400 text-sm leading-relaxed">
            {feature.description}
          </p>
          {feature.id === 'workspace' && <WorkspaceVisual />}
          {feature.id === 'native' && <NativeDesktopVisual />}
        </div>
      </div>
    </motion.div>
  )
}

export function Features() {
  return (
    <section id="features" className="py-32 px-6 relative">
      {/* Subtle dot grid background */}
      <div
        className="absolute inset-0 pointer-events-none"
        style={{
          backgroundImage:
            'radial-gradient(circle at 1px 1px, rgba(255,255,255,0.025) 1px, transparent 0)',
          backgroundSize: '40px 40px',
        }}
      />

      <div className="max-w-6xl mx-auto relative">
        <div className="text-center mb-20">
          <motion.h2
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ duration: 0.6 }}
            className="font-display text-4xl md:text-6xl text-white mb-6"
          >
            Everything you need,
            <br />
            <span className="text-zinc-500">nothing you don't.</span>
          </motion.h2>
          <motion.p
            initial={{ opacity: 0, y: 15 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: 0.15, duration: 0.5 }}
            className="text-zinc-500 text-lg max-w-lg mx-auto"
          >
            Built for developers who want AI assistance without the cloud
            dependency.
          </motion.p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {features.map((feature, i) => (
            <FeatureCard key={feature.id} feature={feature} index={i} />
          ))}
        </div>
      </div>
    </section>
  )
}
