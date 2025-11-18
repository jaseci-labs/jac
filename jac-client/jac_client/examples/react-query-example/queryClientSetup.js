import { QueryClient } from "@tanstack/react-query";

/**
 * Create QueryClient instance here since OneLang doesn't support 'new' keyword yet
 * This is a workaround to instantiate the QueryClient
 */
export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchOnWindowFocus: false,
      retry: 1,
      staleTime: 5000, // 5 seconds
    },
  },
});

console.log("✅ QueryClient created successfully in JS:", queryClient);
