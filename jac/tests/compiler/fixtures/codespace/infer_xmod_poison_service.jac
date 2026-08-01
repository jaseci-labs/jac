"""Server helper whose closure needs the Python stdlib: unpullable.

A client module may still plain-import the obj -- the pull must decline
(datetime cannot join the browser bundle) and the partition bridges it as
a wire type instead, exactly as an `sv import` would.
"""
import datetime;

def _now_label -> str {
    return str(datetime.datetime.now());
}

obj Ticket {
    has label: str = "";

    def refresh {
        self.label = _now_label();
    }
}
