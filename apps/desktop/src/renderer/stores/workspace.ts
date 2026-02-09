import { create } from "zustand";
import type { Workspace, Session } from "@/lib/ipc-types";
import { ipcInvoke } from "@/lib/ipc";

interface WorkspaceState {
  workspaces: Workspace[];
  sessions: Record<string, Session[]>;
  activeWorkspaceId: string | null;
  expandedWorkspaceIds: Set<string>;

  loadWorkspaces: () => Promise<void>;
  createWorkspace: (name: string, path: string) => Promise<Workspace>;
  updateWorkspace: (id: string, name: string) => Promise<void>;
  deleteWorkspace: (id: string) => Promise<void>;
  setActiveWorkspace: (id: string | null) => void;
  toggleExpanded: (id: string) => void;
  loadSessions: (workspaceId: string) => Promise<void>;
  createSession: (workspaceId: string, title?: string) => Promise<Session>;
  renameSession: (id: string, title: string) => Promise<void>;
  deleteSession: (id: string, workspaceId: string) => Promise<void>;
}

export const useWorkspaceStore = create<WorkspaceState>((set, get) => ({
  workspaces: [],
  sessions: {},
  activeWorkspaceId: null,
  expandedWorkspaceIds: new Set(),

  loadWorkspaces: async () => {
    const workspaces = await ipcInvoke("workspace:list");
    set({ workspaces });
  },

  createWorkspace: async (name, path) => {
    const workspace = await ipcInvoke("workspace:create", { name, path });
    set((s) => ({
      workspaces: [workspace, ...s.workspaces],
      expandedWorkspaceIds: new Set([...s.expandedWorkspaceIds, workspace.id]),
    }));
    return workspace;
  },

  updateWorkspace: async (id, name) => {
    const updated = await ipcInvoke("workspace:update", { id, name });
    set((s) => ({
      workspaces: s.workspaces.map((w) => (w.id === id ? updated : w)),
    }));
  },

  deleteWorkspace: async (id) => {
    await ipcInvoke("workspace:delete", { id });
    set((s) => {
      const sessions = { ...s.sessions };
      delete sessions[id];
      const expanded = new Set(s.expandedWorkspaceIds);
      expanded.delete(id);
      return {
        workspaces: s.workspaces.filter((w) => w.id !== id),
        sessions,
        expandedWorkspaceIds: expanded,
        activeWorkspaceId: s.activeWorkspaceId === id ? null : s.activeWorkspaceId,
      };
    });
  },

  setActiveWorkspace: (id) => {
    set({ activeWorkspaceId: id });
    if (id) {
      const { sessions, loadSessions } = get();
      if (!sessions[id]) {
        loadSessions(id);
      }
    }
  },

  toggleExpanded: (id) => {
    set((s) => {
      const expanded = new Set(s.expandedWorkspaceIds);
      if (expanded.has(id)) {
        expanded.delete(id);
      } else {
        expanded.add(id);
        if (!s.sessions[id]) {
          get().loadSessions(id);
        }
      }
      return { expandedWorkspaceIds: expanded };
    });
  },

  loadSessions: async (workspaceId) => {
    const sessions = await ipcInvoke("session:list", { workspaceId });
    set((s) => ({
      sessions: { ...s.sessions, [workspaceId]: sessions },
    }));
  },

  createSession: async (workspaceId, title) => {
    const session = await ipcInvoke("session:create", { workspaceId, title });
    set((s) => ({
      sessions: {
        ...s.sessions,
        [workspaceId]: [session, ...(s.sessions[workspaceId] ?? [])],
      },
    }));
    return session;
  },

  renameSession: async (id, title) => {
    const updated = await ipcInvoke("session:rename", { id, title });
    set((s) => {
      const sessions = { ...s.sessions };
      for (const wsId of Object.keys(sessions)) {
        sessions[wsId] = sessions[wsId].map((sess) =>
          sess.id === id ? updated : sess
        );
      }
      return { sessions };
    });
  },

  deleteSession: async (id, workspaceId) => {
    await ipcInvoke("session:delete", { id });
    set((s) => ({
      sessions: {
        ...s.sessions,
        [workspaceId]: (s.sessions[workspaceId] ?? []).filter(
          (sess) => sess.id !== id
        ),
      },
    }));
  },
}));
