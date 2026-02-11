import { useRef } from 'react'
import { motion, useInView } from 'motion/react'
import { FolderPlus, MessageCircle, Rocket } from 'lucide-react'

const steps = [
  {
    number: '01',
    icon: FolderPlus,
    title: 'Point',
    description:
      'Select any folder on your machine. Shire creates a workspace and launches Claude Code scoped entirely to that directory.',
  },
  {
    number: '02',
    icon: MessageCircle,
    title: 'Chat',
    description:
      'Ask questions, explore your codebase, or request changes through natural language conversation.',
  },
  {
    number: '03',
    icon: Rocket,
    title: 'Ship',
    description:
      'Claude Code writes files directly to disk. Every change is tracked as an artifact you can trace back to the exact message.',
  },
]

export function HowItWorks() {
  const ref = useRef(null)
  const isInView = useInView(ref, { once: true, margin: '-100px' })

  return (
    <section id="how-it-works" className="py-32 px-6" ref={ref}>
      <div className="max-w-6xl mx-auto">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={isInView ? { opacity: 1, y: 0 } : {}}
          transition={{ duration: 0.6 }}
          className="text-center mb-20"
        >
          <h2 className="font-display text-4xl md:text-6xl text-white">
            Three steps. Zero friction.
          </h2>
        </motion.div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-12 md:gap-8">
          {steps.map((step, i) => {
            const Icon = step.icon
            return (
              <motion.div
                key={step.number}
                initial={{ opacity: 0, y: 40 }}
                animate={isInView ? { opacity: 1, y: 0 } : {}}
                transition={{
                  delay: 0.15 + i * 0.15,
                  duration: 0.6,
                  ease: 'easeOut',
                }}
                className="relative text-center md:text-left"
              >
                <span className="font-mono text-7xl md:text-8xl font-bold text-accent/[0.08] leading-none select-none block">
                  {step.number}
                </span>
                <div className="mt-4">
                  <div className="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-surface border border-edge mb-5">
                    <Icon className="w-6 h-6 text-accent" />
                  </div>
                  <h3 className="text-2xl font-semibold text-white mb-3">
                    {step.title}
                  </h3>
                  <p className="text-zinc-400 leading-relaxed">
                    {step.description}
                  </p>
                </div>
              </motion.div>
            )
          })}
        </div>
      </div>
    </section>
  )
}
