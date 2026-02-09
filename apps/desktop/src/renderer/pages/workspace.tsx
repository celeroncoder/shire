import { useEffect } from "react";
import { useParams, useNavigate } from "react-router";
import { MessageSquarePlus, FolderOpen } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useWorkspaceStore } from "@/stores/workspace";
import { formatRelativeTime } from "@/lib/format";

export function WorkspacePage() {
  const { workspaceId } = useParams<{ workspaceId: string }>();
  const navigate = useNavigate();
  const { workspaces, sessions, setActiveWorkspace, loadSessions, createSession } =
    useWorkspaceStore();

  const workspace = workspaces.find((w) => w.id === workspaceId);
  const wsSessions = workspaceId ? sessions[workspaceId] ?? [] : [];

  useEffect(() => {
    if (workspaceId) {
      setActiveWorkspace(workspaceId);
      loadSessions(workspaceId);
    }
  }, [workspaceId, setActiveWorkspace, loadSessions]);

  if (!workspace) {
    return (
      <div className="flex flex-1 items-center justify-center text-muted-foreground">
        Workspace not found
      </div>
    );
  }

  const handleNewChat = async () => {
    const session = await createSession(workspace.id);
    navigate(`/workspace/${workspace.id}/chat/${session.id}`);
  };

  return (
    <div className="flex flex-1 flex-col">
      {/* Header / drag region */}
      <div className="drag-region flex h-12 shrink-0 items-center px-4">
        <div className="no-drag" />
      </div>

      <div className="flex flex-1 flex-col items-center justify-center gap-6 px-8">
        <div className="flex items-center gap-3">
          <div className="flex size-10 items-center justify-center rounded-lg bg-accent">
            <FolderOpen className="size-5 text-muted-foreground" />
          </div>
          <div>
            <h1 className="text-lg font-semibold">{workspace.name}</h1>
            <p className="text-xs text-muted-foreground">{workspace.path}</p>
          </div>
        </div>

        <Button onClick={handleNewChat} className="gap-2">
          <MessageSquarePlus className="size-4" />
          New Chat
        </Button>

        {wsSessions.length > 0 && (
          <div className="w-full max-w-sm">
            <h2 className="mb-2 text-xs font-medium uppercase tracking-wide text-muted-foreground">
              Recent Sessions
            </h2>
            <div className="space-y-1">
              {wsSessions.slice(0, 10).map((session) => (
                <button
                  key={session.id}
                  className="flex w-full items-center justify-between rounded-md px-3 py-2 text-left text-sm hover:bg-accent"
                  onClick={() =>
                    navigate(`/workspace/${workspace.id}/chat/${session.id}`)
                  }
                >
                  <span className="truncate">
                    {session.title || "Untitled"}
                  </span>
                  <span className="shrink-0 text-xs text-muted-foreground">
                    {formatRelativeTime(session.updatedAt)}
                  </span>
                </button>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
