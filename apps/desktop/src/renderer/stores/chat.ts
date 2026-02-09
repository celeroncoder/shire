import { create } from "zustand";
import type { Message } from "@/lib/ipc-types";
import { ipcInvoke, ipcOn } from "@/lib/ipc";

export interface ActiveToolCall {
  toolCallId: string;
  toolName: string;
  args: unknown;
  status: "running" | "done";
  result?: unknown;
}

interface ChatState {
  activeSessionId: string | null;
  messages: Message[];
  streamingContent: string;
  toolCalls: ActiveToolCall[];
  isStreaming: boolean;
  error: string | null;

  setActiveSession: (sessionId: string | null) => Promise<void>;
  loadHistory: (sessionId: string) => Promise<void>;
  sendMessage: (sessionId: string, content: string) => Promise<void>;
  stopStreaming: (sessionId: string) => Promise<void>;
  clearError: () => void;
}

export const useChatStore = create<ChatState>((set, get) => ({
  activeSessionId: null,
  messages: [],
  streamingContent: "",
  toolCalls: [],
  isStreaming: false,
  error: null,

  setActiveSession: async (sessionId) => {
    set({
      activeSessionId: sessionId,
      messages: [],
      streamingContent: "",
      toolCalls: [],
      isStreaming: false,
      error: null,
    });
    if (sessionId) {
      await get().loadHistory(sessionId);
    }
  },

  loadHistory: async (sessionId) => {
    const messages = await ipcInvoke("chat:history", { sessionId });
    if (get().activeSessionId === sessionId) {
      set({ messages });
    }
  },

  sendMessage: async (sessionId, content) => {
    const userMessage: Message = {
      id: `temp-${Date.now()}`,
      sessionId,
      role: "user",
      content,
      toolCalls: null,
      toolCallId: null,
      tokenCount: null,
      createdAt: Date.now(),
      order: get().messages.length,
    };
    set((s) => ({
      messages: [...s.messages, userMessage],
      isStreaming: true,
      streamingContent: "",
      toolCalls: [],
      error: null,
    }));
    try {
      await ipcInvoke("chat:send", { sessionId, content });
    } catch {
      // Errors come through the chat:error event
    }
  },

  stopStreaming: async (sessionId) => {
    await ipcInvoke("chat:stop", { sessionId });
  },

  clearError: () => set({ error: null }),
}));

let listenersInitialized = false;

export function initChatListeners(): void {
  if (listenersInitialized) return;
  listenersInitialized = true;

  const store = useChatStore;

  ipcOn("chat:delta", ({ sessionId, delta }) => {
    const state = store.getState();
    if (state.activeSessionId === sessionId) {
      store.setState({ streamingContent: state.streamingContent + delta });
    }
  });

  ipcOn("chat:tool-call", ({ sessionId, toolCall }) => {
    const state = store.getState();
    if (state.activeSessionId === sessionId) {
      const existing = state.toolCalls.find(
        (tc) => tc.toolCallId === toolCall.toolCallId
      );
      if (!existing) {
        store.setState({
          toolCalls: [
            ...state.toolCalls,
            {
              toolCallId: toolCall.toolCallId,
              toolName: toolCall.toolName,
              args: toolCall.args,
              status: "running",
            },
          ],
        });
      }
    }
  });

  ipcOn("chat:tool-result", ({ sessionId, toolCallId, result }) => {
    const state = store.getState();
    if (state.activeSessionId === sessionId) {
      store.setState({
        toolCalls: state.toolCalls.map((tc) =>
          tc.toolCallId === toolCallId
            ? { ...tc, status: "done" as const, result }
            : tc
        ),
      });
    }
  });

  ipcOn("chat:done", ({ sessionId, message }) => {
    const state = store.getState();
    if (state.activeSessionId === sessionId) {
      store.setState({
        messages: [...state.messages, message],
        streamingContent: "",
        toolCalls: [],
        isStreaming: false,
      });
    }
  });

  ipcOn("chat:error", ({ sessionId, error }) => {
    const state = store.getState();
    if (state.activeSessionId === sessionId) {
      store.setState({ error, isStreaming: false });
    }
  });
}
