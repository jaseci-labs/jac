# Custom hook for localStorage persistence
# Demonstrates: custom hooks, try/except error handling, useEffect
cl import from react { useEffect }

cl {
    # Custom hook for syncing state with localStorage
    def useLocalStorage(key: str, initialValue: list) -> list {
        # Initialize state with default, then load from localStorage on mount
        has storedValue: list = initialValue;

        useEffect(
            lambda { try {
                item = window.localStorage.getItem(key);
                if item {
                    storedValue = JSON.parse(item);
                }
            } except Exception as e {
                print("Error reading from localStorage");
            }},
            [key]
        );

        # Sync state back to localStorage whenever storedValue changes
        useEffect(
            lambda { try {
                window.localStorage.setItem(key, JSON.stringify(storedValue));
            } except Exception as e {
                print("Error saving to localStorage");
            }},
            [key, storedValue]
        );

        return [storedValue, lambda val: any { storedValue = val; }];
    }
}
