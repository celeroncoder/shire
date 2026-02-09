import { useState } from "react";
import { useNavigate, useParams } from "react-router";
import { ChevronRight, Plus, MoreHorizontal, Pencil, Trash2, FolderOpen } from "lucide-react";
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from "@/components/ui/collapsible";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Button } from "@/components/ui/button";
import { useWorkspaceStore } from "@/stores/workspace";
import type { Workspace } from "@/lib/ipc-types";
import { SessionItem } from "./session-item";

const INITIAL_SHOW = 5;

export function WorkspaceItem({ workspace }: { workspace: Workspace }) {
  const navigate = useNavigate();
  const { workspaceId: activeWsId } = useParams();
  const {
    sessions,
    expandedWorkspaceIds,
    toggleExpanded,
    createSession,
    deleteWorkspace,
    loadSessions,
  } = useWorkspaceStore();
  const [showAll, setShowAll] = useState(false);
  const [renaming, setRenaming] = useState(false);
  const [renameValue, setRenameValue] = useState(workspace.name);

  const isExpanded = expandedWorkspaceIds.has(workspace.id);
  const wsSessions = sessions[workspace.id] ?? [];
  const visibleSessions = showAll ? wsSessions : wsSessions.slice(0, INITIAL_SHOW);
  const hasMore = wsSessions.length > INITIAL_SHOW;

  const handleToggle = () => {
    toggleExpanded(workspace.id);
    if (!isExpanded && !sessions[workspace.id]) {
      loadSessions(workspace.id);
    }
  };

  const handleNewSession = async (e: React.MouseEvent) => {
    e.stopPropagation();
    const session = await createSession(workspace.id);
    navigate(`/workspace/${workspace.id}/chat/${session.id}`);
  };

  const handleRename = async () => {
    if (renameValue.trim() && renameValue !== workspace.name) {
      await useWorkspaceStore.getState().updateWorkspace(workspace.id, renameValue.trim());
    }
    setRenaming(false);
  };

  const handleDelete = async () => {
    await deleteWorkspace(workspace.id);
    if (activeWsId === workspace.id) {
      navigate("/");
    }
  };

  return (
    <Collapsible open={isExpanded} onOpenChange={handleToggle}>
      <div className="group flex items-center gap-1 rounded-md px-1 py-0.5 hover:bg-accent">
        <CollapsibleTrigger asChild>
          <button className="flex flex-1 items-center gap-1.5 overflow-hidden py-1 text-left">
            <ChevronRight
              className={`size-3.5 shrink-0 text-muted-foreground transition-transform ${
                isExpanded ? "rotate-90" : ""
              }`}
            />
            <FolderOpen className="size-3.5 shrink-0 text-muted-foreground" />
            {renaming ? (
              <input
                className="w-full bg-transparent text-sm outline-none"
                value={renameValue}
                onChange={(e) => setRenameValue(e.target.value)}
                onBlur={handleRename}
                onKeyDown={(e) => {
                  if (e.key === "Enter") handleRename();
                  if (e.key === "Escape") setRenaming(false);
                }}
                onClick={(e) => e.stopPropagation()}
                autoFocus
              />
            ) : (
              <span className="truncate text-sm font-medium">{workspace.name}</span>
            )}
          </button>
        </CollapsibleTrigger>

        <div className="flex shrink-0 items-center opacity-0 group-hover:opacity-100">
          <Button
            variant="ghost"
            size="icon-xs"
            className="text-muted-foreground hover:text-foreground"
            onClick={handleNewSession}
          >
            <Plus className="size-3.5" />
          </Button>

          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button
                variant="ghost"
                size="icon-xs"
                className="text-muted-foreground hover:text-foreground"
              >
                <MoreHorizontal className="size-3.5" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="w-40">
              <DropdownMenuItem
                onClick={() => {
                  setRenameValue(workspace.name);
                  setRenaming(true);
                }}
              >
                <Pencil className="mr-2 size-3.5" />
                Rename
              </DropdownMenuItem>
              <DropdownMenuItem
                className="text-destructive focus:text-destructive"
                onClick={handleDelete}
              >
                <Trash2 className="mr-2 size-3.5" />
                Delete
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </div>

      <CollapsibleContent>
        <div className="ml-3 border-l border-border pl-2">
          {wsSessions.length === 0 ? (
            <p className="py-1 pl-2 text-xs text-muted-foreground">No sessions</p>
          ) : (
            <>
              {visibleSessions.map((session) => (
                <SessionItem
                  key={session.id}
                  session={session}
                  workspaceId={workspace.id}
                />
              ))}
              {hasMore && !showAll && (
                <button
                  className="w-full py-1 pl-2 text-left text-xs text-muted-foreground hover:text-foreground"
                  onClick={() => setShowAll(true)}
                >
                  Show {wsSessions.length - INITIAL_SHOW} more...
                </button>
              )}
            </>
          )}
        </div>
      </CollapsibleContent>
    </Collapsible>
  );
}
