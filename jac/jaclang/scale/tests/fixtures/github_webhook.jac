"""Fixture for the github webhook scheme: one walker per scheme in one app.
The scale config must point at the fixture directory before boot, because
`register` refuses a github-scheme walker when [scale.webhook].github_secret
is empty (see the [scale.webhook] block in the fixture jac.toml)."""

"""No api key; the runtime verifies X-Hub-Signature-256 over the raw body and
copies X-GitHub-Event / X-GitHub-Delivery into `event` / `delivery`."""
@restspec(protocol=APIProtocol.WEBHOOK, scheme="github")
walker GithubEvent {
    has event: str = "",
        delivery: str = "",
        action: str = "",
        installation: dict[str, any] = {};

    can process with Root entry {
        report {
            "status": "received",
            "event": self.event,
            "delivery": self.delivery,
            "action": self.action,
            "installation": self.installation,
            "transport": "webhook-github"
        };
    }
}

"""The default scheme, side by side with the github one."""
@restspec(protocol=APIProtocol.WEBHOOK)
walker KeyedEvent {
    has note: str = "";

    can process with Root entry {
        report {"status": "received", "note": self.note, "transport": "webhook"};
    }
}
