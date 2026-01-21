cl {
    # Pure authentication rules (testable)

    def:pub validateCredentials(username: str, password: str) -> str {
        if not username or not password {
            return "Please fill in all fields";
        }
        if username.length < 3 {
            return "Username must be at least 3 characters";
        }
        if password.length < 6 {
            return "Password must be at least 6 characters";
        }
        return "";
    }

    def:pub authView(isLoggedIn: bool) -> str {
        return "todos" if isLoggedIn else "login";
    }

    def:pub shouldShowError(error: str) -> bool {
        return error != None and error != "";
    }

}