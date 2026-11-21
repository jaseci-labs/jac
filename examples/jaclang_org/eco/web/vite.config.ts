import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import jac from "@jac/vite";

export default defineConfig({
    plugins: [jac({ assets: "core/site/assets" }), react(), tailwindcss()],
    resolve: {
        alias: [{ find: /^react-native$/, replacement: "react-native-web" }],
        dedupe: ["react", "react-dom", "react-router-dom"],
    },
});
