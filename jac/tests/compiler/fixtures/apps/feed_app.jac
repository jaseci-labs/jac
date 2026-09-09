"""File-rooted `feed` service app that leans on a shared pure helper."""

import from .shared_fmt { stamp }

obj Item {
    has text: str;
}

walker Feed {
    has text: str;

    can go with Root entry {
        report Item(text=stamp(self.text));
    }
}
