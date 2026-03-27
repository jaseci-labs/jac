"""Fixture: SV returns optional and union types to CL.

Tests that nullable returns and union types are handled
correctly across the codespace boundary.
"""

obj UserProfile {
    has username: str,
        email: str,
        bio: str = "";
}

obj ErrorResponse {
    has code: int,
        message: str;
}

def:pub find_user(username: str) -> UserProfile | None {
    return None;
}

def:pub get_user_or_error(id: str) -> UserProfile | ErrorResponse {
    return ErrorResponse(code=404, message="Not found");
}

def:pub maybe_list -> list[UserProfile] | None {
    return None;
}

cl {
    sv import from .typed_optional_union { find_user, get_user_or_error }

    def:pub app -> JsxElement {
        has user: Any = None,
            error: Any = None;

        async can with entry {
            result = await get_user_or_error("123");
            if result.code {
                error = result;
            } else {
                user = result;
            }
        }

        return <div>
            <span>{error.message}</span>
            <span>{user.username}</span>
        </div>;
    }
}
