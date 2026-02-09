import { useRef } from 'react'
import { motion, useInView } from 'motion/react'
import {
  Search,
  FileText,
  Pencil,
  FolderTree,
  FileSearch,
} from 'lucide-react'

const tools = [
  {
    name: 'glob',
    icon: Search,
    description: 'Find files matching a glob pattern',
    params: 'pattern, path?',
  },
  {
    name: 'ripgrep',
    icon: FileSearch,
    description: 'Regex search across workspace file contents',
    params: 'pattern, glob?, maxResults?',
  },
  {
    name: 'read_file',
    icon: FileText,
    description: 'Read file contents — full or by line range',
    params: 'path, startLine?, endLine?',
  },
  {
    name: 'write_file',
    icon: Pencil,
    description: 'Create or overwrite a file in the workspace',
    params: 'path, content',
  },
  {
    name: 'list_dir',
    icon: FolderTree,
    description: 'List directory entries with metadata',
    params: 'path?',
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
              Five tools.
              <br />
              <span className="text-accent">Complete control.</span>
            </h2>
            <p className="text-zinc-400 text-lg leading-relaxed mb-8">
              The AI operates through five precisely-scoped tools. Each one
              validates paths, respects file size limits, and stays sandboxed
              within your workspace. No shell access. No surprises.
            </p>
            <div className="space-y-3">
              <div className="flex items-center gap-3 text-sm text-zinc-500">
                <div className="w-1.5 h-1.5 rounded-full bg-green-500" />
                512 KB read limit
              </div>
              <div className="flex items-center gap-3 text-sm text-zinc-500">
                <div className="w-1.5 h-1.5 rounded-full bg-green-500" />
                256 KB write limit
              </div>
              <div className="flex items-center gap-3 text-sm text-zinc-500">
                <div className="w-1.5 h-1.5 rounded-full bg-green-500" />
                Binary file detection &amp; rejection
              </div>
              <div className="flex items-center gap-3 text-sm text-zinc-500">
                <div className="w-1.5 h-1.5 rounded-full bg-green-500" />
                Path traversal prevention
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
                  shire tools
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
                    All paths resolved via resolveSandboxed(workspaceRoot)
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
