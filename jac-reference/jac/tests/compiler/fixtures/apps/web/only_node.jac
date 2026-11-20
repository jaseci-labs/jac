"""A consumer that imports a node of the social app: nodes never cross an
app boundary."""

import from ..social_app { Post }

def make -> Post {
    return Post(text="x");
}
