# Combined store - merges all slices into a single Zustand store
cl import from zustand { create }
cl import from .userSlice { createUserSlice }
cl import from .settingsSlice { createSettingsSlice }
cl import from .cartSlice { createCartSlice }

cl {
    let appStore = create(lambda setState: any, getState: any, store: any -> dict {
        return {
            **createUserSlice(setState, getState, store),
            **createSettingsSlice(setState, getState, store),
            **createCartSlice(setState, getState, store)
        };
    });

    def useAppStore(selector: any = None) -> any {
        if selector {
            return appStore(selector);
        }
        return appStore();
    }
}
