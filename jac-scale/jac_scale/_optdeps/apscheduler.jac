"""Guarded re-exports for apscheduler (install group: [scheduler])."""

with entry {
    try {
        import from apscheduler.schedulers.background { BackgroundScheduler }
        import from apscheduler.executors.pool { ThreadPoolExecutor }
        import from apscheduler.triggers.cron { CronTrigger }
        HAS_APSCHEDULER = True;
    } except ImportError {
        BackgroundScheduler = None;
        ThreadPoolExecutor = None;
        CronTrigger = None;
        HAS_APSCHEDULER = False;
    }
}
