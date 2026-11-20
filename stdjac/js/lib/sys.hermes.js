// Python's sys module in a hermes space: lib/sys.js's, but sys.platform is
// the device's operating system as Python names it, "android" or "ios"
// (React Native's Platform.OS). A space's bundle reads it for lib/sys.js.
import { Platform } from "react-native";
export * from "./sys.js";
export const platform = Platform.OS;
