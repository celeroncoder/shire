import { FolderPlus, Settings } from "lucide-react";
import { useNavigate } from "react-router";
import { Button } from "@/components/ui/button";
import { Separator } from "@/components/ui/separator";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";
import { useWorkspaceStore } from "@/stores/workspace";
import { useUIStore } from "@/stores/ui";
import { ipcInvoke } from "@/lib/ipc";

export function SidebarFooter() {
  const navigate = useNavigate();
  const { createWorkspace } = useWorkspaceStore();
  const { openSettings } = useUIStore();

  const handleNewWorkspace = async () => {
    const result = await ipcInvoke("dialog:open-folder");
    if (result.canceled || result.filePaths.length === 0) return;

    const folderPath = result.filePaths[0];
    const name = folderPath.split("/").pop() ?? "Workspace";
    const workspace = await createWorkspace(name, folderPath);
    navigate(`/workspace/${workspace.id}`);
  };

  return (
    <div className="no-drag shrink-0">
      <Separator />
      <div className="flex items-center justify-between px-3 py-2">
        <TooltipProvider delayDuration={300}>
          <Tooltip>
            <TooltipTrigger asChild>
              <Button
                variant="ghost"
                size="sm"
                className="gap-1.5 text-muted-foreground hover:text-foreground"
                onClick={handleNewWorkspace}
              >
                <FolderPlus className="size-4" />
                <span className="text-xs">New Workspace</span>
              </Button>
            </TooltipTrigger>
            <TooltipContent side="top">Open a folder as workspace</TooltipContent>
          </Tooltip>
        </TooltipProvider>

        <TooltipProvider delayDuration={300}>
          <Tooltip>
            <TooltipTrigger asChild>
              <Button
                variant="ghost"
                size="icon-xs"
                className="text-muted-foreground hover:text-foreground"
                onClick={openSettings}
              >
                <Settings className="size-4" />
              </Button>
            </TooltipTrigger>
            <TooltipContent side="top">Settings (Cmd+,)</TooltipContent>
          </Tooltip>
        </TooltipProvider>
      </div>
    </div>
  );
}
