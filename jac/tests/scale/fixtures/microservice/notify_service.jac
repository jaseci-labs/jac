"""Notification microservice fixture.

Exposes its public surface through walkers (not functions). Used by
sv-import-of-walker tests to verify that a walker on the *provider*
can be reached from a consumer that does `sv import from notify_service`.
"""

obj NotifyResult {
    has channel: str = "",
        delivered: bool = False,
        message: str = "";
}

walker:pub Greet {
    has name: str;

    can greet with Root entry {
        report f"hello, {self.name}";
    }
}

walker:pub Notify {
    has channel: str;
    has subject: str;
    has body: str = "";

    can send with Root entry {
        report NotifyResult(
            channel=self.channel,
            delivered=True,
            message=f"[{self.channel}] {self.subject}"
        );
    }
}
