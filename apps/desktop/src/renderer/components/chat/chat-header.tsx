export function ChatHeader({ title }: { title: string }) {
  return (
    <div className="drag-region flex h-12 shrink-0 items-center border-b border-border px-4">
      <h2 className="no-drag truncate text-sm font-medium text-foreground">
        {title}
      </h2>
    </div>
  );
}
