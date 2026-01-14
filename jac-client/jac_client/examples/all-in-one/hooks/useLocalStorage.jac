# Custom hook for localStorage persistence
# Demonstrates: custom hooks, try/except error handling, useEffect

cl import from react { useEffect }

cl {
    # Custom hook for syncing state with localStorage
    def useLocalStorage(key: str, initialValue: list) -> list {
        # Initialize state with value from localStorage or default
        [storedValue, setStoredValue] = useState(lambda -> any {
            try {
                item = window.localStorage.getItem(key);
                if item {
                    return JSON.parse(item);
                }else{
                    return initialValue;
                }

            } except Exception as e  {
                console.log("Error reading from localStorage");
                return initialValue;
            }
        });

        # Update localStorage when state changes
        useEffect(lambda -> None {
            try {
                window.localStorage.setItem(key, JSON.stringify(storedValue));
            } except Exception as e {
                console.log("Error saving to localStorage");
            }
        }, [key, storedValue]);

        return [storedValue, setStoredValue];
    }
}
