"""Fixture: @schedule specs the server must refuse to start with."""

@schedule(interval=0)
def spin {}

@schedule(cron="60 * * * *")
def bad_minute {}

@schedule(interval=2, cron="* * * * *")
walker SpinWalker {
    can act with Root entry {}
}

@schedule(interval=1e300)
def huge {}

@schedule(interval=60)
def good_one {}
