# Form data store - manages submitted form data and user state
cl import from zustand { create }

cl {
    let formStore = create(lambda setState: any, getState: any -> dict {
        return {
            # User data
            "users": [],
            "currentUser": None,
            "isLoggedIn": False,

            # Form submissions
            "registrations": [],
            "contactMessages": [],
            "profiles": [],

            # Actions
            "registerUser": lambda userData: dict -> None {
                setState(lambda state: any -> dict {
                    let newUser = {
                        "id": Date.now(),
                        "username": userData.username,
                        "email": userData.email,
                        "age": userData.age,
                        "createdAt": Date().toISOString()
                    };
                    return {
                        **state,
                        "users": state.users.concat([newUser]),
                        "registrations": state.registrations.concat([userData])
                    };
                });
            },

            "loginUser": lambda credentials: dict -> None {
                setState(lambda state: any -> dict {
                    let user = state.users.find(lambda u: any -> bool {
                        return u.email == credentials.email;
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

            "updateProfile": lambda profileData: dict -> None {
                setState(lambda state: any -> dict {
                    if state.currentUser {
                        let updatedUser = {
                            **state.currentUser,
                            "displayName": profileData.displayName,
                            "bio": profileData.bio or "",
                            "website": profileData.website or "",
                            "notifications": profileData.notifications
                        };

                        return {
                            **state,
                            "currentUser": updatedUser,
                            "profiles": state.profiles.concat([profileData])
                        };
                    }
                    return {**state};
                });
            },

            "submitContactMessage": lambda messageData: dict -> None {
                setState(lambda state: any -> dict {
                    let message = {
                        "id": Date.now(),
                        "submittedAt": Date().toISOString(),
                        **messageData
                    };
                    return {
                        **state,
                        "contactMessages": state.contactMessages.concat([message])
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
                        "registrations": [],
                        "contactMessages": [],
                        "profiles": []
                    };
                });
            }
        };
    });

    def useFormStore(selector: any = None) -> any {
        if selector {
            return formStore(selector);
        }
        return formStore();
    }
}
