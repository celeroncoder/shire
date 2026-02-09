import { useEffect } from "react";
import { useNavigate } from "react-router";
import { useWorkspaceStore } from "@/stores/workspace";
import { useUIStore } from "@/stores/ui";
import { ipcInvoke, ipcOn } from "@/lib/ipc";

/**
 * Listens for native menu events dispatched from the main process
 * and routes them to the appropriate store actions.
 */
export function useKeyboardShortcuts() {
  const navigate = useNavigate();
  const { activeWorkspaceId, createSession, createWorkspace } = useWorkspaceStore();
  const { toggleSettings } = useUIStore();

  useEffect(() => {
    const unsubs: (() => void)[] = [];

    unsubs.push(
      ipcOn("menu:open-settings", () => {
        toggleSettings();
      })
    );

    unsubs.push(
      ipcOn("menu:new-session", async () => {
        if (activeWorkspaceId) {
          const session = await createSession(activeWorkspaceId);
          navigate(`/workspace/${activeWorkspaceId}/chat/${session.id}`);
        }
      })
    );

    unsubs.push(
      ipcOn("menu:new-workspace", async () => {
        const result = await ipcInvoke("dialog:open-folder");
        if (result.canceled || result.filePaths.length === 0) return;
        const folderPath = result.filePaths[0];
        const name = folderPath.split("/").pop() ?? "Workspace";
        const workspace = await createWorkspace(name, folderPath);
        navigate(`/workspace/${workspace.id}`);
      })
    );

    return () => unsubs.forEach((fn) => fn());
  }, [navigate, activeWorkspaceId, createSession, createWorkspace, toggleSettings]);
}
