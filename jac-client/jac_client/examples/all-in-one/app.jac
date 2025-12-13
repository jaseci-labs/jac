#
# Combined example: auth + routing + CSS styling + asset serving + nested folder imports
#
cl import from react { useState, useEffect }
cl import from "@jac-client/utils" {
    Router,
    Routes,
    Route,
    Link,
    Navigate,
    useNavigate,
    useLocation,
    jacSignup,
    jacLogin,
    jacLogout,
    jacIsLoggedIn
}

# Pure CSS + asset-in-CSS example
cl import ".styles.css";

# Nested folder imports (same pattern as nested-basic/)
cl import from .components.button {
    CustomButton
}
cl import from .button { CustomButtonRoot }

# TypeScript component import
cl import from ".components/Card.tsx" { Card }

#
# Basic backend walkers
#
node Todo {
    has text: str;
    has done: bool = False;
}

walker create_todo {
    has text: str;

    can create with `root entry {
        new_todo = here ++> Todo(text=self.text);
        report new_todo ;
    }
}

walker ping_server {
    can ping with `root entry {
        report "pong from backend!" ;
    }
}

walker get_server_message {
    can info with `root entry {
        report "hello from a basic walker!" ;
    }
}
