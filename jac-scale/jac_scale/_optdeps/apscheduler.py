"""Guarded re-exports for apscheduler (install group: [scheduler])."""

try:
    from apscheduler.executors.pool import ThreadPoolExecutor
    from apscheduler.schedulers.background import BackgroundScheduler

    HAS_APSCHEDULER = True
except ImportError:
    BackgroundScheduler = None
    ThreadPoolExecutor = None

    HAS_APSCHEDULER = False
