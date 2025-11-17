import { create } from "zustand";

/**
 * Basic counter store shared across Jac/React components.
 */
export const useCounterStore = create((set, get) => ({
  count: 0,
  step: 1,
  increment() {
    set((state) => {
      const newCount = state.count + state.step;
      return { count: newCount };
    });
  },
  decrement() {
    set((state) => {
      const newCount = state.count - state.step;
      return { count: newCount };
    });
  },
  setStep(nextStep) {
    const safeStep = Number.isFinite(nextStep) && nextStep > 0 ? nextStep : 1;
    set({ step: safeStep });
  },
  reset() {
    set({ count: 0, step: 1 });
  },
}));

// Optional: Add a subscriber to log all state changes
useCounterStore.subscribe((state) => {
  console.log("useCounterStore called");
});
