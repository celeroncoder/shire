import { useRef } from 'react'
import { motion, useInView } from 'motion/react'
import {
  Search,
  FileText,
  Pencil,
  Terminal,
  FileSearch,
  Globe,
  GitBranch,
} from 'lucide-react'

const tools = [
  {
    name: 'Read',
    icon: FileText,
    description: 'Read file contents with line ranges and image support',
    params: 'file_path, offset?, limit?',
  },
  {
    name: 'Edit',
    icon: Pencil,
    description: 'Precise string replacements in existing files',
    params: 'file_path, old_string, new_string',
  },
  {
    name: 'Bash',
    icon: Terminal,
    description: 'Execute shell commands — git, npm, builds, and more',
    params: 'command, timeout?',
  },
  {
    name: 'Glob',
    icon: Search,
    description: 'Fast file pattern matching across any codebase size',
    params: 'pattern, path?',
  },
  {
    name: 'Grep',
    icon: FileSearch,
    description: 'Regex search powered by ripgrep with full syntax support',
    params: 'pattern, path?, glob?',
  },
  {
    name: 'WebSearch',
    icon: Globe,
    description: 'Search the web for up-to-date information and docs',
    params: 'query',
  },
  {
    name: 'Task',
    icon: GitBranch,
    description: 'Launch specialized agents for parallel multi-step work',
    params: 'prompt, subagent_type',
  },
]

export function Tools() {
  const ref = useRef(null)
  const isInView = useInView(ref, { once: true, margin: '-80px' })

  return (
    <section id="tools" className="py-32 px-6" ref={ref}>
      <div className="max-w-6xl mx-auto">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-16 items-center">
          {/* Left — copy */}
          <motion.div
            initial={{ opacity: 0, x: -30 }}
            animate={isInView ? { opacity: 1, x: 0 } : {}}
            transition={{ duration: 0.6, ease: 'easeOut' }}
          >
            <h2 className="font-display text-4xl md:text-6xl text-white mb-6 leading-[1.05]">
              Claude Code.
              <br />
              <span className="text-accent">Every tool.</span>
            </h2>
            <p className="text-zinc-400 text-lg leading-relaxed mb-8">
              Shire wraps Claude Code and gives you access to its full toolset —
              file operations, shell commands, web search, and multi-agent
              workflows. Nothing held back.
            </p>
            <div className="space-y-3">
              <div className="flex items-center gap-3 text-sm text-zinc-500">
                <div className="w-1.5 h-1.5 rounded-full bg-green-500" />
                Read, Write, Edit files
              </div>
              <div className="flex items-center gap-3 text-sm text-zinc-500">
                <div className="w-1.5 h-1.5 rounded-full bg-green-500" />
                Bash commands &amp; git operations
              </div>
              <div className="flex items-center gap-3 text-sm text-zinc-500">
                <div className="w-1.5 h-1.5 rounded-full bg-green-500" />
                Web search &amp; web fetch
              </div>
              <div className="flex items-center gap-3 text-sm text-zinc-500">
                <div className="w-1.5 h-1.5 rounded-full bg-green-500" />
                MCP servers &amp; custom skills
              </div>
            </div>
          </motion.div>

          {/* Right — terminal mockup */}
          <motion.div
            initial={{ opacity: 0, x: 30 }}
            animate={isInView ? { opacity: 1, x: 0 } : {}}
            transition={{ delay: 0.15, duration: 0.6, ease: 'easeOut' }}
          >
            <div className="rounded-2xl border border-edge bg-surface overflow-hidden shadow-2xl shadow-black/30">
              {/* Terminal header */}
              <div className="flex items-center gap-2 px-4 py-3 border-b border-edge bg-surface-raised">
                <div className="flex gap-1.5">
                  <div className="w-3 h-3 rounded-full bg-[#ff5f57]/80" />
                  <div className="w-3 h-3 rounded-full bg-[#febc2e]/80" />
                  <div className="w-3 h-3 rounded-full bg-[#28c840]/80" />
                </div>
                <span className="text-[11px] text-zinc-600 font-mono ml-2">
                  claude code tools
                </span>
              </div>

              {/* Tool list */}
              <div className="p-4 md:p-6 font-mono text-sm space-y-1">
                {tools.map((tool, i) => {
                  const Icon = tool.icon
                  return (
                    <motion.div
                      key={tool.name}
                      initial={{ opacity: 0, x: 12 }}
                      animate={isInView ? { opacity: 1, x: 0 } : {}}
                      transition={{
                        delay: 0.35 + i * 0.08,
                        duration: 0.4,
                        ease: 'easeOut',
                      }}
                      className="group flex items-start gap-3 p-3 rounded-xl hover:bg-white/[0.03] transition-colors duration-200"
                    >
                      <Icon className="w-4 h-4 text-accent mt-0.5 flex-shrink-0" />
                      <div className="min-w-0">
                        <div className="flex items-baseline gap-2 flex-wrap">
                          <span className="text-white font-semibold">
                            {tool.name}
                          </span>
                          <span className="text-zinc-600 text-xs">
                            ({tool.params})
                          </span>
                        </div>
                        <p className="text-zinc-500 text-xs mt-0.5">
                          {tool.description}
                        </p>
                      </div>
                    </motion.div>
                  )
                })}

                <div className="pt-3 mt-2 border-t border-edge/50">
                  <span className="text-zinc-600 text-[11px]">
                    Powered by Claude Code — plus 20+ more tools
                  </span>
                </div>
              </div>
            </div>
          </motion.div>
        </div>
      </div>
    </section>
  )
}
