import { useEffect, useRef, useState, useCallback } from "react";
import { ScrollArea } from "@/components/ui/scroll-area";
import { useWorkspaceStore } from "@/stores/workspace";
import { WorkspaceItem } from "./workspace-item";
import { SidebarFooter } from "./sidebar-footer";

export function Sidebar() {
  const { workspaces } = useWorkspaceStore();
  const [width, setWidth] = useState(260);
  const isResizing = useRef(false);

  const handleMouseDown = useCallback((e: React.MouseEvent) => {
    e.preventDefault();
    isResizing.current = true;
    document.body.style.cursor = "col-resize";
    document.body.style.userSelect = "none";
  }, []);

  useEffect(() => {
    const handleMouseMove = (e: MouseEvent) => {
      if (!isResizing.current) return;
      const newWidth = Math.min(400, Math.max(200, e.clientX));
      setWidth(newWidth);
    };

    const handleMouseUp = () => {
      isResizing.current = false;
      document.body.style.cursor = "";
      document.body.style.userSelect = "";
    };

    document.addEventListener("mousemove", handleMouseMove);
    document.addEventListener("mouseup", handleMouseUp);
    return () => {
      document.removeEventListener("mousemove", handleMouseMove);
      document.removeEventListener("mouseup", handleMouseUp);
    };
  }, []);

  return (
    <aside
      className="relative flex flex-col border-r border-border bg-background"
      style={{ width }}
    >
      {/* Drag region for traffic lights */}
      <div className="drag-region h-12 shrink-0" />

      {/* Workspace list */}
      <ScrollArea className="flex-1">
        <div className="no-drag px-2 pb-2">
          {workspaces.length === 0 ? (
            <p className="px-2 py-4 text-sm text-muted-foreground">
              No workspaces yet. Open a folder to get started.
            </p>
          ) : (
            workspaces.map((ws) => (
              <WorkspaceItem key={ws.id} workspace={ws} />
            ))
          )}
        </div>
      </ScrollArea>

      {/* Footer */}
      <SidebarFooter />

      {/* Resize handle */}
      <div
        className="absolute top-0 right-0 bottom-0 w-1 cursor-col-resize hover:bg-ring/30 active:bg-ring/50"
        onMouseDown={handleMouseDown}
      />
    </aside>
  );
}
