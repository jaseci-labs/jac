
import { defineConfig } from "vite";
import path from "path";
import { fileURLToPath } from "url";
import react from "@vitejs/plugin-react";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  plugins: [react()],
  root: ".", // base folder
  build: {
    rollupOptions: {
      input: "build/main.js", // your compiled entry file
      output: {
        entryFileNames: "client.[hash].js", // name of the final js file
        assetFileNames: "[name].[ext]",
      },
    },
    outDir: "dist", // final bundled output
    emptyOutDir: true,
  },
  publicDir: false,
  resolve: {
      alias: {
        "@jac/runtime": path.resolve(__dirname, "compiled/client_runtime.js"),
        "@jac-client/assets": path.resolve(__dirname, "compiled/assets"),
      },
      extensions: [".mjs", ".js", ".mts", ".ts", ".jsx", ".tsx", ".json"],
  },
});
