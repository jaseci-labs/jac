# Form data store - manages submitted form data and user state
import from zustand { create }


glob formStore = create(lambda setState: any, getState: any -> dict {
    return {
        # User data
        "users": [],
        "currentUser": None,
        "isLoggedIn": False,

        # Actions
        "loginUser": lambda credentials: dict -> None {
            setState(lambda state: any -> dict {
                user = state.users.find(lambda u: any -> bool {
                    return u.username == credentials.username;
                });

                if user {
                    return {
                        **state,
                        "currentUser": user,
                        "isLoggedIn": True
                    };
                }
                return {**state};
            });
        },

        "logoutUser": lambda -> None {
            setState(lambda state: any -> dict {
                return {
                    **state,
                    "currentUser": None,
                    "isLoggedIn": False
                };
            });
        },

        

        "clearAllData": lambda -> None {
            setState(lambda state: any -> dict {
                return {
                    **state,
                    "users": [],
                    "currentUser": None,
                    "isLoggedIn": False,
                };
            });
        }
    };
});

def:pub useFormStore(selector: any = None) -> any {
    if selector {
        return formStore(selector);
    }
    return formStore();
}
