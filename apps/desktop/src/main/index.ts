import { app, shell, BrowserWindow, ipcMain, dialog, Menu } from "electron";
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
  // Workspace CRUD
  ipcMain.handle("workspace:list", () => service.workspace.list());
  ipcMain.handle("workspace:create", (_event, args: { name: string; path: string }) =>
    service.workspace.create(args)
  );
  ipcMain.handle("workspace:update", (_event, args: { id: string; name: string }) =>
    service.workspace.update(args)
  );
  ipcMain.handle("workspace:delete", (_event, args: { id: string }) =>
    service.workspace.delete(args.id)
  );

  // Session CRUD
  ipcMain.handle("session:list", (_event, args: { workspaceId: string }) =>
    service.session.listByWorkspace(args.workspaceId)
  );
  ipcMain.handle("session:create", (_event, args: { workspaceId: string; title?: string }) =>
    service.session.create(args)
  );
  ipcMain.handle("session:rename", (_event, args: { id: string; title: string }) =>
    service.session.rename(args)
  );
  ipcMain.handle("session:delete", (_event, args: { id: string }) =>
    service.session.delete(args.id)
  );

  // Chat history
  ipcMain.handle("chat:history", (_event, args: { sessionId: string }) =>
    service.message.listBySession(args.sessionId)
  );

  // Artifacts
  ipcMain.handle("artifact:list", (_event, args: { sessionId: string }) =>
    service.artifact.listBySession(args.sessionId)
  );

  // Settings
  ipcMain.handle("settings:get-all", () => service.settings.getAll());
  ipcMain.handle("settings:set", (_event, args: { settings: Record<string, string | null> }) =>
    service.settings.setMany(args.settings)
  );

  // Native dialogs
  ipcMain.handle("dialog:open-folder", async () => {
    return dialog.showOpenDialog({ properties: ["openDirectory"] });
  });

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

function sendToFocusedWindow(channel: string, ...args: unknown[]): void {
  const win = BrowserWindow.getFocusedWindow();
  if (win) {
    win.webContents.send(channel, ...args);
  }
}

function buildMenu(): void {
  const isMac = process.platform === "darwin";

  const template: Electron.MenuItemConstructorOptions[] = [
    // App menu (macOS only)
    ...(isMac
      ? [
          {
            label: app.name,
            submenu: [
              { role: "about" as const },
              { type: "separator" as const },
              {
                label: "Settings\u2026",
                accelerator: "CmdOrCtrl+,",
                click: () => sendToFocusedWindow("menu:open-settings"),
              },
              { type: "separator" as const },
              { role: "services" as const },
              { type: "separator" as const },
              { role: "hide" as const },
              { role: "hideOthers" as const },
              { role: "unhide" as const },
              { type: "separator" as const },
              { role: "quit" as const },
            ],
          } satisfies Electron.MenuItemConstructorOptions,
        ]
      : []),

    // File menu
    {
      label: "File",
      submenu: [
        {
          label: "New Session",
          accelerator: "CmdOrCtrl+N",
          click: () => sendToFocusedWindow("menu:new-session"),
        },
        {
          label: "New Workspace\u2026",
          accelerator: "CmdOrCtrl+Shift+N",
          click: () => sendToFocusedWindow("menu:new-workspace"),
        },
        { type: "separator" },
        isMac ? { role: "close" } : { role: "quit" },
      ],
    },

    // Edit menu
    {
      label: "Edit",
      submenu: [
        { role: "undo" },
        { role: "redo" },
        { type: "separator" },
        { role: "cut" },
        { role: "copy" },
        { role: "paste" },
        ...(isMac
          ? [
              { role: "pasteAndMatchStyle" as const },
              { role: "delete" as const },
              { role: "selectAll" as const },
              { type: "separator" as const },
              {
                label: "Speech",
                submenu: [
                  { role: "startSpeaking" as const },
                  { role: "stopSpeaking" as const },
                ],
              },
            ]
          : [
              { role: "delete" as const },
              { type: "separator" as const },
              { role: "selectAll" as const },
            ]),
      ],
    },

    // View menu
    {
      label: "View",
      submenu: [
        { role: "reload" },
        { role: "forceReload" },
        { role: "toggleDevTools" },
        { type: "separator" },
        { role: "resetZoom" },
        { role: "zoomIn" },
        { role: "zoomOut" },
        { type: "separator" },
        { role: "togglefullscreen" },
      ],
    },

    // Window menu
    {
      label: "Window",
      submenu: [
        { role: "minimize" },
        { role: "zoom" },
        ...(isMac
          ? [
              { type: "separator" as const },
              { role: "front" as const },
              { type: "separator" as const },
              { role: "window" as const },
            ]
          : [{ role: "close" as const }]),
      ],
    },

    // Help menu
    {
      role: "help",
      submenu: [
        {
          label: "Learn More",
          click: () => shell.openExternal("https://github.com"),
        },
      ],
    },
  ];

  const menu = Menu.buildFromTemplate(template);
  Menu.setApplicationMenu(menu);
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
      preload: join(__dirname, "../preload/index.mjs"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false,
    },
  });

  mainWindow.on("ready-to-show", () => {
    mainWindow.show();
    if (is.dev) {
      mainWindow.webContents.openDevTools({ mode: "detach" });
    }
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
  buildMenu();
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
