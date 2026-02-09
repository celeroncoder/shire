import { AlertCircle, X, RotateCcw } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useChatStore } from "@/stores/chat";

export function ChatError() {
  const { error, clearError, activeSessionId, sendMessage, messages } =
    useChatStore();

  if (!error) return null;

  const handleRetry = () => {
    clearError();
    // Retry the last user message
    const lastUserMsg = [...messages].reverse().find((m) => m.role === "user");
    if (lastUserMsg?.content && activeSessionId) {
      sendMessage(activeSessionId, lastUserMsg.content);
    }
  };

  return (
    <div className="shrink-0 border-t border-destructive/30 bg-destructive/10 px-4 py-2">
      <div className="mx-auto flex max-w-3xl items-center gap-2">
        <AlertCircle className="size-4 shrink-0 text-destructive" />
        <span className="flex-1 truncate text-sm text-destructive">{error}</span>
        <Button
          variant="ghost"
          size="icon-xs"
          className="text-destructive hover:text-destructive"
          onClick={handleRetry}
        >
          <RotateCcw className="size-3.5" />
        </Button>
        <Button
          variant="ghost"
          size="icon-xs"
          className="text-destructive hover:text-destructive"
          onClick={clearError}
        >
          <X className="size-3.5" />
        </Button>
      </div>
    </div>
  );
}
