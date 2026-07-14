"""Dispatcher consumer fixture.

Imports a walker (`Greet`) and a function-shaped boundary type
(`NotifyResult`) plus another walker (`Notify`) from `notify_service`
via `sv import`. Exercises the cross-service walker-spawn path: the
consumer constructs `Greet(name=...)`, the runtime turns that into a
POST to `/walker/Greet` on the provider, and the rehydrated walker
flows back with its `reports` populated.
"""

sv import from notify_service { Greet, Notify, NotifyResult }

walker:pub TriggerGreet {
    has who: str;

    can run with Root entry {
        rg = Greet(name=self.who);
        report rg.reports[0];
    }
}

walker:pub Announce {
    has channel: str;
    has subject: str;

    can run with Root entry {
        rn = Notify(channel=self.channel, subject=self.subject);
        report rn.reports[0];
    }
}

def:pub greet_via_walker(who: str) -> str {
    rg = Greet(name=who);
    return rg.reports[0];
}
