import { defineConfig } from "vite";
import preact from "@preact/preset-vite";
import jac from "@jac/vite";

export default defineConfig({ root: "demos", plugins: [jac(), preact()] });
