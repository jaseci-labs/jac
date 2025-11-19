/**
 * Cart slice (JavaScript version for comparison)
 */
export const createCartSlice = (set, get, store) => ({
  items: [],
  total: 0,

  addItem: (item) => {
    set((state) => {
      const newItems = [...state.items, item];
      const newTotal = state.total + (item.price || 0);
      return {
        ...state,
        items: newItems,
        total: newTotal,
      };
    });
  },

  removeItem: (itemId) => {
    set((state) => {
      const itemToRemove = state.items.find((i) => i.id === itemId);
      const newItems = state.items.filter((i) => i.id !== itemId);
      const priceToSubtract = itemToRemove?.price || 0;

      return {
        ...state,
        items: newItems,
        total: state.total - priceToSubtract,
      };
    });
  },

  clearCart: () => {
    set((state) => ({ ...state, items: [], total: 0 }));
  },
});
