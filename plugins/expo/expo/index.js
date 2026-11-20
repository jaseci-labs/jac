// The app's entry: where its spaces are, then its root component.
import "./remotes.js";
import { registerRootComponent } from "expo";
import { app } from "./src/ENTRY.jsx";

registerRootComponent(app);
