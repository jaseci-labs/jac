"""Dispatcher consumer fixture.

Imports a walker (`Greet`) and a function-shaped boundary type
(`NotifyResult`) plus another walker (`Notify`) from `notify_service`
via `sv import`. Exercises the cross-service walker-spawn path: the
consumer awaits `Greet(name=...)`, the runtime turns that into a
POST to `/walker/Greet` on the provider, and the rehydrated walker
flows back with its `reports` populated.
"""

import from notify_service { Greet, Notify, NotifyResult }

async walker:pub TriggerGreet {
    has who: str;

    async can run with Root entry {
        rg = await Greet(name=self.who);
        report rg.reports[0];
    }
}

async walker:pub Announce {
    has channel: str,
        subject: str;

    async can run with Root entry {
        rn = await Notify(channel=self.channel, subject=self.subject);
        report rn.reports[0];
    }
}

async def:pub greet_via_walker(who: str) -> str {
    rg = await Greet(name=who);
    return rg.reports[0];
}
