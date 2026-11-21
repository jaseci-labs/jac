"""A consumer that imports only a data type of the social app: the type must
mirror locally, never become an RPC stub."""

import from ..social_app { Profile }

def make(name: str) -> Profile {
    return Profile(name=name);
}
