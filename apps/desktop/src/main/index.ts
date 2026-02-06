import { app, shell, BrowserWindow, ipcMain } from "electron";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { is } from "@electron-toolkit/utils";
import { streamText, type CoreMessage } from "ai";
import { createAnthropic, anthropic } from "@ai-sdk/anthropic";
import { createOpenAI, openai } from "@ai-sdk/openai";
import { createDatabase, createService, type Message } from "@shire/db";
import { createTools } from "@shire/tools";
import { z } from "zod";

const __dirname = dirname(fileURLToPath(import.meta.url));

const migrationsFolder = is.dev
  ? resolve(__dirname, "../../../../packages/db/src/migrations")
  : join(process.resourcesPath, "migrations");

const dbPath = join(app.getPath("userData"), "shire.db");
const db = createDatabase(dbPath, migrationsFolder);
const service = createService(db);
const activeStreams = new Map<string, AbortController>();

const chatSendSchema = z.object({
  sessionId: z.string().min(1),
  content: z.string().min(1),
});

const chatStopSchema = z.object({
  sessionId: z.string().min(1),
});

function getSetting(...keys: string[]): string | null {
  for (const key of keys) {
    const value = service.settings.get(key);
    if (typeof value === "string" && value.length > 0) {
      return value;
    }
  }

  return null;
}

function resolveModel() {
  const provider = getSetting("ai_provider", "provider")?.toLowerCase();
  const configuredModel = getSetting("ai_model", "model");

  const openAiApiKey =
    getSetting("openai_api_key", "openaiApiKey", "api_key_openai") ??
    process.env["OPENAI_API_KEY"] ??
    null;

  const anthropicApiKey =
    getSetting("anthropic_api_key", "anthropicApiKey", "api_key_anthropic") ??
    process.env["ANTHROPIC_API_KEY"] ??
    null;

  if (provider === "anthropic" || (!provider && !openAiApiKey && anthropicApiKey)) {
    const anthropicProvider = anthropicApiKey
      ? createAnthropic({ apiKey: anthropicApiKey })
      : anthropic;

    return anthropicProvider(configuredModel ?? "claude-3-5-sonnet-latest");
  }

  if (!openAiApiKey && !process.env["OPENAI_API_KEY"]) {
    if (anthropicApiKey || process.env["ANTHROPIC_API_KEY"]) {
      const anthropicProvider = anthropicApiKey
        ? createAnthropic({ apiKey: anthropicApiKey })
        : anthropic;

      return anthropicProvider(configuredModel ?? "claude-3-5-sonnet-latest");
    }

    throw new Error(
      "Missing API credentials. Set OPENAI_API_KEY or ANTHROPIC_API_KEY, or store a provider key in settings."
    );
  }

  const openAiProvider = openAiApiKey ? createOpenAI({ apiKey: openAiApiKey }) : openai;
  return openAiProvider(configuredModel ?? "gpt-4o-mini");
}

function buildSystemPrompt(workspacePath: string): string {
  return [
    "You are Shire, a local coding assistant operating inside one workspace.",
    `Workspace root: ${workspacePath}`,
    "Use tools when you need project context. Never invent file contents.",
    "Available tools:",
    "- glob: discover files by pattern",
    "- ripgrep: search file contents with regex",
    "- list_dir: inspect directories",
    "- read_file: read file contents safely",
    "- write_file: create/update files when requested",
    "Rules:",
    "- Always use relative paths.",
    "- Prefer read/search before write.",
    "- Keep edits focused to the user request.",
    "- Explain what you changed and why in the final response.",
  ].join("\n");
}

function toCoreMessages(history: Message[]): CoreMessage[] {
  const messages: CoreMessage[] = [];

  for (const row of history) {
    if (row.role === "user" && row.content) {
      messages.push({ role: "user", content: row.content });
      continue;
    }

    if (row.role === "assistant" && row.content) {
      messages.push({ role: "assistant", content: row.content });
    }
  }

  return messages;
}

function normalizeErrorMessage(error: unknown): string {
  if (error instanceof Error) {
    return error.message;
  }

  return String(error);
}

function registerIpcHandlers(): void {
  ipcMain.handle("chat:send", async (event, rawArgs) => {
    const { sessionId, content } = chatSendSchema.parse(rawArgs);
    const session = service.session.getById(sessionId);

    if (!session) {
      throw new Error(`Session ${sessionId} not found`);
    }

    const workspace = service.workspace.getById(session.workspaceId);
    if (!workspace) {
      throw new Error(`Workspace ${session.workspaceId} not found`);
    }

    activeStreams.get(sessionId)?.abort();

    const abortController = new AbortController();
    activeStreams.set(sessionId, abortController);

    const userOrder = service.message.getNextOrder(sessionId);
    service.message.create({
      sessionId,
      role: "user",
      content,
      order: userOrder,
    });

    const history = service.message.listBySession(sessionId);
    const coreMessages = toCoreMessages(history);
    const tools = createTools(workspace.path);

    try {
      const result = streamText({
        model: resolveModel(),
        system: buildSystemPrompt(workspace.path),
        messages: coreMessages,
        tools,
        maxSteps: 10,
        abortSignal: abortController.signal,
        toolCallStreaming: true,
        onChunk: ({ chunk }) => {
          if (chunk.type === "text-delta") {
            event.sender.send("chat:delta", { sessionId, delta: chunk.textDelta });
            return;
          }

          if (chunk.type === "tool-call") {
            event.sender.send("chat:tool-call", {
              sessionId,
              toolCall: {
                toolCallId: chunk.toolCallId,
                toolName: chunk.toolName,
                args: chunk.args,
              },
            });
            return;
          }

          if (chunk.type === "tool-result") {
            event.sender.send("chat:tool-result", {
              sessionId,
              toolCallId: chunk.toolCallId,
              result: chunk.result,
            });
          }
        },
        onError: ({ error }) => {
          event.sender.send("chat:error", {
            sessionId,
            error: normalizeErrorMessage(error),
          });
        },
      });

      const [assistantText, toolCalls, toolResults] = await Promise.all([
        result.text,
        result.toolCalls,
        result.toolResults,
      ]);

      const assistantOrder = service.message.getNextOrder(sessionId);
      const assistantMessage = service.message.create({
        sessionId,
        role: "assistant",
        content: assistantText,
        toolCalls: toolCalls.length > 0 ? JSON.stringify(toolCalls) : null,
        order: assistantOrder,
      });

      const toolMessages = service.message.createMany(
        toolResults.map((toolResult, index) => ({
          sessionId,
          role: "tool",
          order: assistantOrder + index + 1,
          content: JSON.stringify({
            toolName: toolResult.toolName,
            args: toolResult.args,
            result: toolResult.result,
          }),
          toolCallId: toolResult.toolCallId,
        }))
      );

      for (const toolMessage of toolMessages) {
        try {
          const parsed = JSON.parse(toolMessage.content ?? "{}") as {
            toolName?: string;
            result?: unknown;
          };

          if (parsed.toolName !== "write_file") {
            continue;
          }

          const resultData =
            typeof parsed.result === "object" && parsed.result !== null
              ? (parsed.result as Record<string, unknown>)
              : {};

          const path = resultData["path"];
          const written = resultData["written"];
          if (typeof path === "string" && written === true) {
            service.artifact.create({
              sessionId,
              messageId: toolMessage.id,
              filePath: path,
              operation: "write",
            });
          }
        } catch {
          // Ignore malformed tool payloads.
        }
      }

      service.session.touch(sessionId);

      event.sender.send("chat:done", { sessionId, message: assistantMessage });
      return assistantMessage;
    } catch (error) {
      const message = normalizeErrorMessage(error);
      event.sender.send("chat:error", { sessionId, error: message });
      throw error;
    } finally {
      if (activeStreams.get(sessionId) === abortController) {
        activeStreams.delete(sessionId);
      }
    }
  });

  ipcMain.handle("chat:stop", (_event, rawArgs) => {
    const { sessionId } = chatStopSchema.parse(rawArgs);
    const stream = activeStreams.get(sessionId);

    if (!stream) {
      return { stopped: false };
    }

    stream.abort();
    activeStreams.delete(sessionId);
    return { stopped: true };
  });
}

function createWindow(): void {
  const mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    minWidth: 800,
    minHeight: 600,
    show: false,
    titleBarStyle: "hiddenInset",
    vibrancy: "sidebar",
    trafficLightPosition: { x: 16, y: 16 },
    webPreferences: {
      preload: join(__dirname, "../preload/index.js"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false,
    },
  });

  mainWindow.on("ready-to-show", () => {
    mainWindow.show();
  });

  mainWindow.webContents.setWindowOpenHandler((details) => {
    shell.openExternal(details.url);
    return { action: "deny" };
  });

  if (is.dev && process.env["ELECTRON_RENDERER_URL"]) {
    mainWindow.loadURL(process.env["ELECTRON_RENDERER_URL"]);
  } else {
    mainWindow.loadFile(join(__dirname, "../renderer/index.html"));
  }
}

app.whenReady().then(() => {
  registerIpcHandlers();
  createWindow();

  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit();
  }
});

export { db, service };
