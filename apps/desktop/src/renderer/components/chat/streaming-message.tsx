import { Bot } from "lucide-react";
import type { ActiveToolCall } from "@/stores/chat";
import { MarkdownContent } from "./markdown-content";
import { ToolCallBlock } from "./tool-call-block";

export function StreamingMessage({
  content,
  toolCalls,
}: {
  content: string;
  toolCalls: ActiveToolCall[];
}) {
  return (
    <div className="flex gap-3">
      <div className="flex size-7 shrink-0 items-center justify-center rounded-full bg-accent">
        <Bot className="size-4 text-muted-foreground" />
      </div>

      <div className="min-w-0 max-w-[85%] space-y-2">
        {toolCalls.length > 0 && (
          <div className="space-y-1">
            {toolCalls.map((tc) => (
              <ToolCallBlock
                key={tc.toolCallId}
                toolName={tc.toolName}
                args={tc.args}
                status={tc.status}
                result={tc.result}
              />
            ))}
          </div>
        )}

        {content ? (
          <div className="prose-chat text-sm text-foreground">
            <MarkdownContent content={content} />
            <span className="cursor-blink inline-block h-4 w-0.5 bg-foreground align-text-bottom" />
          </div>
        ) : toolCalls.length === 0 ? (
          <div className="flex items-center gap-2 text-sm text-muted-foreground">
            <span className="cursor-blink inline-block h-4 w-0.5 bg-muted-foreground" />
            Thinking...
          </div>
        ) : null}
      </div>
    </div>
  );
}
