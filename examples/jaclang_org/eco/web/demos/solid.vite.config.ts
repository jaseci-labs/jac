import { defineConfig } from "vite";
import solid from "vite-plugin-solid";
import jac from "@jac/vite";

export default defineConfig({ root: "demos", plugins: [jac(), solid()] });
