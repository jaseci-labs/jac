/**
 * Settings slice (JavaScript version for comparison)
 */
export const createSettingsSlice = (set, get, store) => ({
  theme: "light",
  language: "en",
  notifications: true,

  setTheme: (newTheme) => {
    set((state) => ({ ...state, theme: newTheme }));
  },

  setLanguage: (lang) => {
    set((state) => ({ ...state, language: lang }));
  },

  toggleNotifications: () => {
    set((state) => ({ ...state, notifications: !state.notifications }));
  },
});
