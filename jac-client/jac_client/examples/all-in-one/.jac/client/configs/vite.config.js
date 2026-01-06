import { defineConfig } from "vite";
import path from "path";
import { fileURLToPath } from "url";
import react from "@vitejs/plugin-react";
import tailwindcss from '@tailwindcss/vite'
const __dirname = path.dirname(fileURLToPath(import.meta.url));
// Config is in configs/ inside .jac/client/, so go up one level to .jac/client/, then up two more to project root
const buildDir = path.resolve(__dirname, "..");
const projectRoot = path.resolve(__dirname, "../../..");

/**
 * Vite configuration generated from config.json (in project root)
 * To customize, edit config.json instead of this file.
 */

export default defineConfig({
  plugins: [
    react(),
    tailwindcss()
  ],
  root: buildDir, // base folder (.jac/client/) so vite can find node_modules
    build: {
    rollupOptions: {
      input: path.resolve(buildDir, "build/main.js"), // your compiled entry file
      output: {
        entryFileNames: "client.[hash].js", // name of the final js file
        assetFileNames: "[name].[ext]",
      },
    },
    outDir: path.resolve(buildDir, "dist"), // final bundled output
    emptyOutDir: true,

  },
  publicDir: false,
  resolve: {
      alias: {
        "@jac-client/utils": path.resolve(buildDir, "compiled/client_runtime.js"),
        "@jac-client/assets": path.resolve(buildDir, "compiled/assets"),
      },
      extensions: [".mjs", ".js", ".mts", ".ts", ".jsx", ".tsx", ".json"],

  },
});
