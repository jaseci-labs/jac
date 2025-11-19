# User slice - manages authentication and user profile state
cl {
    def createUserSlice(setState: any, getState: any, store: any) -> dict {
        return {
            "user": None,
            "isAuthenticated": False,

            "login": lambda username: str, role: str = "user" -> None {
                setState(lambda state: any -> dict {
                    return {
                        **state,
                        "user": {"username": username, "role": role},
                        "isAuthenticated": True
                    };
                });
            },

            "logout": lambda -> None {
                setState(lambda state: any -> dict {
                    return {
                        **state,
                        "user": None,
                        "isAuthenticated": False
                    };
                });
            },

            "updateProfile": lambda updates: dict -> None {
                setState(lambda state: any -> dict {
                    if not state.user {
                        return {**state};
                    }
                    return {
                        **state,
                        "user": {**state.user, **updates}
                    };
                });
            }
        };
    }
}
