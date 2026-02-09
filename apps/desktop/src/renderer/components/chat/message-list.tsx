import { useEffect, useRef } from "react";
import { ScrollArea } from "@/components/ui/scroll-area";
import { useChatStore } from "@/stores/chat";
import { MessageBubble } from "./message";
import { StreamingMessage } from "./streaming-message";

export function MessageList() {
  const { messages, isStreaming, streamingContent, toolCalls } = useChatStore();
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages, streamingContent, toolCalls]);

  const displayMessages = messages.filter((m) => m.role === "user" || m.role === "assistant");

  return (
    <ScrollArea className="flex-1">
      <div className="mx-auto max-w-3xl px-4 py-4 space-y-4">
        {displayMessages.length === 0 && !isStreaming && (
          <div className="flex flex-col items-center justify-center py-20 text-center">
            <p className="text-sm text-muted-foreground">
              Send a message to start the conversation.
            </p>
          </div>
        )}

        {displayMessages.map((msg) => (
          <MessageBubble key={msg.id} message={msg} />
        ))}

        {isStreaming && (
          <StreamingMessage content={streamingContent} toolCalls={toolCalls} />
        )}

        <div ref={bottomRef} />
      </div>
    </ScrollArea>
  );
}
