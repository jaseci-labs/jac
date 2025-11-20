# Settings slice - manages app preferences and UI state
cl {
    def createSettingsSlice(setState: any, getState: any, store: any) -> dict {
        return {
            "theme": "light",
            "language": "en",
            "notifications": True,

            "setTheme": lambda newTheme: str -> None {
                setState(lambda state: any -> dict {
                    return {**state, "theme": newTheme};
                });
            },

            "setLanguage": lambda lang: str -> None {
                setState(lambda state: any -> dict {
                    return {**state, "language": lang};
                });
            },

            "toggleNotifications": lambda -> None {
                setState(lambda state: any -> dict {
                    return {**state, "notifications": not state.notifications};
                });
            }
        };
    }
}
