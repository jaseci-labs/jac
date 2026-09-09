"""File-rooted service app: it owns exactly this file, so core/helper.jac
beside it stays shared."""

import from core.helper { label }

walker:pub Ping {
    has count: int = 0;

    can reply with Root entry {
        report label(self.count);
    }
}
