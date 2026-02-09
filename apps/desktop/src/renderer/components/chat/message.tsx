import { Bot, User } from "lucide-react";
import type { Message } from "@/lib/ipc-types";
import { MarkdownContent } from "./markdown-content";
import { ToolCallBlock } from "./tool-call-block";

export function MessageBubble({ message }: { message: Message }) {
  const isUser = message.role === "user";

  // Parse tool calls from the message if present
  let toolCalls: Array<{
    toolCallId: string;
    toolName: string;
    args: unknown;
  }> = [];
  if (message.toolCalls) {
    try {
      toolCalls = JSON.parse(message.toolCalls);
    } catch {
      // ignore
    }
  }

  return (
    <div className={`flex gap-3 ${isUser ? "justify-end" : ""}`}>
      {!isUser && (
        <div className="flex size-7 shrink-0 items-center justify-center rounded-full bg-accent">
          <Bot className="size-4 text-muted-foreground" />
        </div>
      )}

      <div className={`min-w-0 max-w-[85%] ${isUser ? "order-first" : ""}`}>
        {isUser ? (
          <div className="rounded-2xl rounded-br-sm bg-primary px-4 py-2 text-primary-foreground">
            <p className="whitespace-pre-wrap text-sm">{message.content}</p>
          </div>
        ) : (
          <div className="space-y-2">
            {toolCalls.length > 0 && (
              <div className="space-y-1">
                {toolCalls.map((tc) => (
                  <ToolCallBlock
                    key={tc.toolCallId}
                    toolName={tc.toolName}
                    args={tc.args}
                    status="done"
                  />
                ))}
              </div>
            )}
            {message.content && (
              <div className="prose-chat text-sm text-foreground">
                <MarkdownContent content={message.content} />
              </div>
            )}
          </div>
        )}
      </div>

      {isUser && (
        <div className="flex size-7 shrink-0 items-center justify-center rounded-full bg-accent">
          <User className="size-4 text-muted-foreground" />
        </div>
      )}
    </div>
  );
}
