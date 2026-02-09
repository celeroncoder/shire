import { create } from "zustand";
import type { SettingsMap } from "@/lib/ipc-types";
import { ipcInvoke } from "@/lib/ipc";

interface SettingsState {
  settings: SettingsMap;
  loaded: boolean;

  loadSettings: () => Promise<void>;
  setSetting: (key: string, value: string | null) => Promise<void>;
  setSettings: (map: SettingsMap) => Promise<void>;
}

export const useSettingsStore = create<SettingsState>((set) => ({
  settings: {},
  loaded: false,

  loadSettings: async () => {
    const settings = await ipcInvoke("settings:get-all");
    set({ settings, loaded: true });
  },

  setSetting: async (key, value) => {
    await ipcInvoke("settings:set", { settings: { [key]: value } });
    set((s) => ({
      settings: { ...s.settings, [key]: value },
    }));
  },

  setSettings: async (map) => {
    await ipcInvoke("settings:set", { settings: map });
    set((s) => ({
      settings: { ...s.settings, ...map },
    }));
  },
}));
