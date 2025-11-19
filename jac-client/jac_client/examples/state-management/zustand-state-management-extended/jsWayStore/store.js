import { create } from "zustand";
import { createUserSlice } from "./slices/userSlice";
import { createSettingsSlice } from "./slices/settingsSlice";
import { createCartSlice } from "./slices/cartSlice";

/**
 * Combined store merging all slices
 * This is the production pattern for large apps
 */
export const useAppStore = create((...args) => ({
  ...createUserSlice(...args),
  ...createSettingsSlice(...args),
  ...createCartSlice(...args),
}));
