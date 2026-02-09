export function Footer() {
  return (
    <footer className="py-12 px-6 border-t border-edge">
      <div className="max-w-7xl mx-auto flex flex-col md:flex-row items-center justify-between gap-4">
        <div className="flex items-center gap-2">
          <span className="font-display text-lg text-white">Shire</span>
          <span className="text-zinc-600 text-sm">
            &middot; Built with care for developers.
          </span>
        </div>
        <div className="flex items-center gap-6">
          <a
            href="#"
            className="text-sm text-zinc-500 hover:text-white transition-colors duration-200"
          >
            GitHub
          </a>
          <a
            href="#"
            className="text-sm text-zinc-500 hover:text-white transition-colors duration-200"
          >
            Twitter
          </a>
          <a
            href="#"
            className="text-sm text-zinc-500 hover:text-white transition-colors duration-200"
          >
            Discord
          </a>
        </div>
      </div>
    </footer>
  )
}
