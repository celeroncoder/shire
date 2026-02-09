import { useEffect } from "react";
import { MemoryRouter, Routes, Route } from "react-router";
import { Sidebar } from "@/components/sidebar/sidebar";
import { SettingsDialog } from "@/components/settings/settings-dialog";
import { HomePage } from "@/pages/home";
import { WorkspacePage } from "@/pages/workspace";
import { ChatPage } from "@/pages/chat";
import { useWorkspaceStore } from "@/stores/workspace";
import { useSettingsStore } from "@/stores/settings";
import { initChatListeners } from "@/stores/chat";
import { useKeyboardShortcuts } from "@/hooks/use-keyboard-shortcuts";

function AppShell() {
  const { loadWorkspaces } = useWorkspaceStore();
  const { loadSettings } = useSettingsStore();

  useEffect(() => {
    loadWorkspaces();
    loadSettings();
    initChatListeners();
  }, [loadWorkspaces, loadSettings]);

  useKeyboardShortcuts();

  return (
    <div className="flex h-screen bg-background text-foreground">
      <Sidebar />
      <main className="flex flex-1 flex-col min-w-0">
        <Routes>
          <Route path="/" element={<HomePage />} />
          <Route path="/workspace/:workspaceId" element={<WorkspacePage />} />
          <Route
            path="/workspace/:workspaceId/chat/:sessionId"
            element={<ChatPage />}
          />
        </Routes>
      </main>
      <SettingsDialog />
    </div>
  );
}

export function App() {
  return (
    <MemoryRouter>
      <AppShell />
    </MemoryRouter>
  );
}
