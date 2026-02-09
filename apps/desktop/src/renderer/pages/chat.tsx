import { useEffect } from "react";
import { useParams } from "react-router";
import { useWorkspaceStore } from "@/stores/workspace";
import { useChatStore } from "@/stores/chat";
import { ChatHeader } from "@/components/chat/chat-header";
import { MessageList } from "@/components/chat/message-list";
import { Composer } from "@/components/chat/composer";
import { ChatError } from "@/components/chat/chat-error";

export function ChatPage() {
  const { workspaceId, sessionId } = useParams<{
    workspaceId: string;
    sessionId: string;
  }>();
  const { setActiveWorkspace, sessions } = useWorkspaceStore();
  const { setActiveSession } = useChatStore();

  useEffect(() => {
    if (workspaceId) setActiveWorkspace(workspaceId);
    if (sessionId) setActiveSession(sessionId);
    return () => {
      setActiveSession(null);
    };
  }, [workspaceId, sessionId, setActiveWorkspace, setActiveSession]);

  const session = workspaceId
    ? (sessions[workspaceId] ?? []).find((s) => s.id === sessionId)
    : undefined;

  return (
    <div className="flex flex-1 flex-col min-h-0">
      <ChatHeader title={session?.title ?? "Untitled"} />
      <MessageList />
      <ChatError />
      <Composer sessionId={sessionId ?? ""} />
    </div>
  );
}
