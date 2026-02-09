import { useState } from "react";
import { useNavigate, useParams } from "react-router";
import { MessageSquare, MoreHorizontal, Pencil, Trash2 } from "lucide-react";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Button } from "@/components/ui/button";
import { useWorkspaceStore } from "@/stores/workspace";
import type { Session } from "@/lib/ipc-types";
import { formatRelativeTime } from "@/lib/format";

export function SessionItem({
  session,
  workspaceId,
}: {
  session: Session;
  workspaceId: string;
}) {
  const navigate = useNavigate();
  const { sessionId: activeSessionId } = useParams();
  const { renameSession, deleteSession } = useWorkspaceStore();
  const [renaming, setRenaming] = useState(false);
  const [renameValue, setRenameValue] = useState(session.title ?? "");

  const isActive = activeSessionId === session.id;
  const title = session.title || "Untitled";

  const handleClick = () => {
    navigate(`/workspace/${workspaceId}/chat/${session.id}`);
  };

  const handleRename = async () => {
    if (renameValue.trim() && renameValue !== session.title) {
      await renameSession(session.id, renameValue.trim());
    }
    setRenaming(false);
  };

  const handleDelete = async () => {
    await deleteSession(session.id, workspaceId);
    if (isActive) {
      navigate(`/workspace/${workspaceId}`);
    }
  };

  return (
    <div
      className={`group flex items-center gap-1.5 rounded-md px-2 py-1 cursor-pointer ${
        isActive
          ? "bg-accent text-accent-foreground"
          : "text-muted-foreground hover:bg-accent/50 hover:text-foreground"
      }`}
      onClick={handleClick}
    >
      <MessageSquare className="size-3 shrink-0" />
      {renaming ? (
        <input
          className="flex-1 bg-transparent text-xs outline-none"
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
        <>
          <span className="flex-1 truncate text-xs">{title}</span>
          <span className="shrink-0 text-[10px] opacity-50">
            {formatRelativeTime(session.updatedAt)}
          </span>
        </>
      )}

      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button
            variant="ghost"
            size="icon-xs"
            className="shrink-0 opacity-0 group-hover:opacity-100 text-muted-foreground hover:text-foreground"
            onClick={(e) => e.stopPropagation()}
          >
            <MoreHorizontal className="size-3" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end" className="w-36">
          <DropdownMenuItem
            onClick={(e) => {
              e.stopPropagation();
              setRenameValue(session.title ?? "");
              setRenaming(true);
            }}
          >
            <Pencil className="mr-2 size-3.5" />
            Rename
          </DropdownMenuItem>
          <DropdownMenuItem
            className="text-destructive focus:text-destructive"
            onClick={(e) => {
              e.stopPropagation();
              handleDelete();
            }}
          >
            <Trash2 className="mr-2 size-3.5" />
            Delete
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  );
}
