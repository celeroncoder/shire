import { resolve } from "path";
import { defineConfig, externalizeDepsPlugin } from "electron-vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  main: {
    plugins: [externalizeDepsPlugin({ exclude: ["@shire/db", "@shire/tools"] })],
    build: {
      rollupOptions: {
        external: ["@vscode/ripgrep"],
      },
    },
  },
  preload: {
    plugins: [externalizeDepsPlugin({ exclude: ["@shire/db", "@shire/tools"] })],
    build: {
      rollupOptions: {
        external: ["@vscode/ripgrep"],
      },
    },
  },
  renderer: {
    resolve: {
      alias: {
        "@": resolve("src/renderer"),
      },
    },
    plugins: [react(), tailwindcss()],
  },
});
