import { FolderOpen } from "lucide-react";
import { useNavigate } from "react-router";
import { Button } from "@/components/ui/button";
import { useWorkspaceStore } from "@/stores/workspace";
import { ipcInvoke } from "@/lib/ipc";

export function HomePage() {
  const navigate = useNavigate();
  const { createWorkspace } = useWorkspaceStore();

  const handleOpenFolder = async () => {
    const result = await ipcInvoke("dialog:open-folder");
    if (result.canceled || result.filePaths.length === 0) return;

    const folderPath = result.filePaths[0];
    const name = folderPath.split("/").pop() ?? "Workspace";
    const workspace = await createWorkspace(name, folderPath);
    navigate(`/workspace/${workspace.id}`);
  };

  return (
    <div className="flex flex-1 flex-col items-center justify-center gap-4">
      <div className="flex size-16 items-center justify-center rounded-2xl bg-accent">
        <FolderOpen className="size-8 text-muted-foreground" />
      </div>
      <div className="text-center">
        <h1 className="text-xl font-semibold">Welcome to Shire</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          Open a folder to start a workspace
        </p>
      </div>
      <Button onClick={handleOpenFolder} className="gap-2">
        <FolderOpen className="size-4" />
        Open Folder
      </Button>
    </div>
  );
}
