import React from "react";
import { createRoot } from "react-dom/client";
import { app as App } from "./app.js";

const root = createRoot(document.getElementById("root"));
root.render(<App />);
