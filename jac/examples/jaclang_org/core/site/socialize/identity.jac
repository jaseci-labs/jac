import from core.social_graph { Profile }

glob PROJECT_ERRORS: dict[str, str] = {
         "bad_url": "That is not a GitHub repository. Paste a github.com/owner/repo link.",
         "duplicate": "That repository is already one of your projects.",
         "not_found": "GitHub has no public repository at that address.",
         "not_jac": "No Jac code found in that repository. Jacyak projects are Jac repos.",
         "fetch_failed": "Could not download the repository right now. Try scoring it again in a minute.",
         "internal": "The scorer is unavailable right now. The project is saved; score it again later.",
         "cooldown": "Scored recently. Repos can be rescored every six hours.",
         "forbidden": "Only the owner can change this project."
     };

def:pub handle_of(username: str) -> str {
    return username.split("@")[0] if "@" in username else username;
}

def:pub initial_of(name: str) -> str {
    return name[0].upper() if name else "?";
}

def:pub name_of(profile: Profile) -> str {
    return profile.display_name or handle_of(profile.username);
}

def:pub avatar_of(avatars: dict[str, str], username: str) -> str {
    return avatars.get(username) or "";
}

def:pub project_error_message(code: str) -> str {
    return PROJECT_ERRORS.get(code) or ("Something went wrong (" + code + ").");
}
