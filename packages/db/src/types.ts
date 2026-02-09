import type { InferInsertModel, InferSelectModel } from "drizzle-orm";
import {
  artifacts,
  messages,
  sessions,
  settings,
  workspaces,
} from "./schema.js";

export type Workspace = InferSelectModel<typeof workspaces>;
export type Session = InferSelectModel<typeof sessions>;
export type Message = InferSelectModel<typeof messages>;
export type Artifact = InferSelectModel<typeof artifacts>;
export type Setting = InferSelectModel<typeof settings>;

export type NewWorkspace = InferInsertModel<typeof workspaces>;
export type NewSession = InferInsertModel<typeof sessions>;
export type NewMessage = InferInsertModel<typeof messages>;
export type NewArtifact = InferInsertModel<typeof artifacts>;
export type NewSetting = InferInsertModel<typeof settings>;

export type CreateWorkspaceInput = Pick<NewWorkspace, "name" | "path">;
export type UpdateWorkspaceInput = {
  id: Workspace["id"];
  name: Workspace["name"];
};

export type CreateSessionInput = {
  workspaceId: Session["workspaceId"];
  title?: Session["title"];
};

export type RenameSessionInput = {
  id: Session["id"];
  title: Session["title"];
};

export type CreateMessageInput = {
  sessionId: Message["sessionId"];
  role: Message["role"];
  order: Message["order"];
  content?: Message["content"];
  toolCalls?: Message["toolCalls"];
  toolCallId?: Message["toolCallId"];
  tokenCount?: Message["tokenCount"];
};

export type CreateArtifactInput = Pick<
  NewArtifact,
  "sessionId" | "messageId" | "filePath" | "operation"
>;

export type SettingsMap = Record<string, string | null>;
