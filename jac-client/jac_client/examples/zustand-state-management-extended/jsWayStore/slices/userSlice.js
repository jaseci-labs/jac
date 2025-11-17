/**
 * User slice (JavaScript version for comparison)
 */
export const createUserSlice = (set, get, store) => ({
  user: null,
  isAuthenticated: false,

  login: (username, role = "user") => {
    set((state) => ({
      ...state,
      user: { username, role },
      isAuthenticated: true,
    }));
  },

  logout: () => {
    set((state) => ({
      ...state,
      user: null,
      isAuthenticated: false,
    }));
  },

  updateProfile: (updates) => {
    set((state) => {
      if (!state.user) return state;
      return {
        ...state,
        user: { ...state.user, ...updates },
      };
    });
  },
});
