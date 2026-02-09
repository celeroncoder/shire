import { useState } from "react";
import { ChevronRight, Wrench, Loader2, CheckCircle2 } from "lucide-react";
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from "@/components/ui/collapsible";

function summarizeArgs(args: unknown): string {
  if (!args || typeof args !== "object") return "";
  const obj = args as Record<string, unknown>;
  if ("pattern" in obj) return String(obj.pattern);
  if ("path" in obj) return String(obj.path);
  if ("query" in obj) return String(obj.query);
  const keys = Object.keys(obj);
  if (keys.length === 0) return "";
  return keys.join(", ");
}

export function ToolCallBlock({
  toolName,
  args,
  status,
  result,
}: {
  toolName: string;
  args: unknown;
  status: "running" | "done";
  result?: unknown;
}) {
  const [open, setOpen] = useState(false);
  const summary = summarizeArgs(args);

  return (
    <Collapsible open={open} onOpenChange={setOpen}>
      <CollapsibleTrigger asChild>
        <button className="flex w-full items-center gap-2 rounded-md border border-border bg-muted/30 px-3 py-1.5 text-left text-xs hover:bg-muted/50">
          <ChevronRight
            className={`size-3 shrink-0 text-muted-foreground transition-transform ${
              open ? "rotate-90" : ""
            }`}
          />
          <Wrench className="size-3 shrink-0 text-muted-foreground" />
          <span className="font-medium text-foreground">{toolName}</span>
          {summary && (
            <span className="truncate text-muted-foreground">{summary}</span>
          )}
          <span className="ml-auto shrink-0">
            {status === "running" ? (
              <Loader2 className="size-3 animate-spin text-muted-foreground" />
            ) : (
              <CheckCircle2 className="size-3 text-green-500" />
            )}
          </span>
        </button>
      </CollapsibleTrigger>
      <CollapsibleContent>
        <div className="mt-1 space-y-1 rounded-md border border-border bg-muted/20 p-2 text-xs">
          {args != null && (
            <div>
              <p className="mb-0.5 font-medium text-muted-foreground">Input</p>
              <pre className="overflow-x-auto whitespace-pre-wrap break-all text-foreground">
                {JSON.stringify(args, null, 2)}
              </pre>
            </div>
          )}
          {result !== undefined && (
            <div>
              <p className="mb-0.5 font-medium text-muted-foreground">Output</p>
              <pre className="overflow-x-auto whitespace-pre-wrap break-all text-foreground max-h-48 overflow-y-auto">
                {typeof result === "string" ? result : JSON.stringify(result, null, 2) as string}
              </pre>
            </div>
          )}
        </div>
      </CollapsibleContent>
    </Collapsible>
  );
}
