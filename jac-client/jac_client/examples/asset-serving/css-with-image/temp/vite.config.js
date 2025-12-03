import { defineConfig } from "vite";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  root: ".",
  build: {
    rollupOptions: {
      input: "build/main.js",
      output: {
        entryFileNames: "client.[hash].js",
        assetFileNames: "[name].[ext]",
      },
    },
    outDir: "dist",
    emptyOutDir: true,
    minify: false,
  },
  publicDir: false,
  resolve: {
    alias: {
      "@jac-client/utils": path.resolve(__dirname, "compiled/client_runtime.js"),
      "@jac-client/assets": path.resolve(__dirname, "compiled/assets"),
    },
  },
});
