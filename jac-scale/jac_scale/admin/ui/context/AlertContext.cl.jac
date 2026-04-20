"""Global alert/toast notification context."""

cl {
    import from react { createContext, useContext }

    glob ALERT_DISMISS_MS = 3000;
    glob:pub AlertContext = createContext(None);

    def:pub AlertProvider(children: Any) -> JsxElement {
        has message: str = "",
            alertType: str = "success";

        def showAlert(msg: str, type: str = "success") {
            message = msg;
            alertType = type;
            setTimeout(lambda { message = "";}, ALERT_DISMISS_MS);
        }

        value = {"message": message, "alertType": alertType, "showAlert": showAlert};

        return
            <AlertContext.Provider value={value}>{children}</AlertContext.Provider>;
    }

    def:pub useAlert -> dict {
        return useContext(AlertContext);
    }
}
