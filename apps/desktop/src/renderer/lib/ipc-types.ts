export interface Workspace {
  id: string;
  name: string;
  path: string;
  createdAt: number;
  updatedAt: number;
}

export interface Session {
  id: string;
  workspaceId: string;
  title: string | null;
  createdAt: number;
  updatedAt: number;
}

export interface Message {
  id: string;
  sessionId: string;
  role: string;
  content: string | null;
  toolCalls: string | null;
  toolCallId: string | null;
  tokenCount: number | null;
  createdAt: number;
  order: number;
}

export interface Artifact {
  id: string;
  sessionId: string;
  messageId: string;
  filePath: string;
  operation: string;
  createdAt: number;
}

export type SettingsMap = Record<string, string | null>;

export interface ToolCallEvent {
  toolCallId: string;
  toolName: string;
  args: unknown;
}

export interface ToolResultEvent {
  toolCallId: string;
  result: unknown;
}

export interface IpcInvokeMap {
  "workspace:list": { args: void; result: Workspace[] };
  "workspace:create": { args: { name: string; path: string }; result: Workspace };
  "workspace:update": { args: { id: string; name: string }; result: Workspace };
  "workspace:delete": { args: { id: string }; result: void };
  "session:list": { args: { workspaceId: string }; result: Session[] };
  "session:create": { args: { workspaceId: string; title?: string }; result: Session };
  "session:rename": { args: { id: string; title: string }; result: Session };
  "session:delete": { args: { id: string }; result: void };
  "chat:send": { args: { sessionId: string; content: string }; result: Message };
  "chat:stop": { args: { sessionId: string }; result: { stopped: boolean } };
  "chat:history": { args: { sessionId: string }; result: Message[] };
  "artifact:list": { args: { sessionId: string }; result: Artifact[] };
  "settings:get-all": { args: void; result: SettingsMap };
  "settings:set": { args: { settings: SettingsMap }; result: void };
  "dialog:open-folder": { args: void; result: { canceled: boolean; filePaths: string[] } };
}

export interface IpcEventMap {
  "chat:delta": { sessionId: string; delta: string };
  "chat:tool-call": { sessionId: string; toolCall: ToolCallEvent };
  "chat:tool-result": { sessionId: string; toolCallId: string; result: unknown };
  "chat:done": { sessionId: string; message: Message };
  "chat:error": { sessionId: string; error: string };
  "menu:new-session": void;
  "menu:new-workspace": void;
  "menu:open-settings": void;
}
