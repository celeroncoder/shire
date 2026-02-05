import { MemoryRouter, Routes, Route } from "react-router";

function Home() {
  return (
    <div className="flex h-screen">
      {/* Sidebar */}
      <aside className="drag-region flex w-64 flex-col border-r border-neutral-200 bg-neutral-50 pt-10 dark:border-neutral-800 dark:bg-neutral-900">
        <div className="no-drag flex-1 overflow-y-auto px-3 pt-2">
          <h2 className="px-2 text-xs font-semibold uppercase tracking-wide text-neutral-500">
            Sessions
          </h2>
          <p className="mt-4 px-2 text-sm text-neutral-400">
            No sessions yet.
          </p>
        </div>
      </aside>

      {/* Main content */}
      <main className="flex flex-1 flex-col items-center justify-center bg-white dark:bg-neutral-950">
        <h1 className="text-3xl font-bold text-neutral-900 dark:text-neutral-100">
          Welcome to Shire
        </h1>
        <p className="mt-2 text-neutral-500">
          Open a workspace to get started.
        </p>
      </main>
    </div>
  );
}

export function App() {
  return (
    <MemoryRouter>
      <Routes>
        <Route path="/" element={<Home />} />
      </Routes>
    </MemoryRouter>
  );
}
