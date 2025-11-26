
import { defineConfig } from "vite";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
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
      "@jac-client/utils": path.resolve(__dirname, "src/client_runtime.js"),
      "@jac-client/assets": path.resolve(__dirname, "src/assets"),
    },
  },
});

