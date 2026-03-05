"""Fixture: scheduled walkers and functions for scheduler tests."""

import datetime;

glob execution_log: list = [],
     run_at: str = (datetime.datetime.now() + datetime.timedelta(seconds=1)).isoformat(),
     fn_run_at: str = (
         datetime.datetime.now() + datetime.timedelta(seconds=1)
     ).isoformat();

# 1. Date walker
@schedule(date=run_at)
walker DateWalker {
    can greet with Root entry {
        execution_log.append("date-walker");
    }
}

# 2. Interval walker
@schedule(interval=0.3)
walker IntervalWalker {
    can tick with Root entry {
        execution_log.append("interval-walker");
    }
}

# 3. Cron walker
@schedule(cron="* * * * *")
walker CronWalker {
    can check with Root entry {
        execution_log.append("cron-walker");
    }
}

# 4. Date function
@schedule(date=fn_run_at)
def date_function {
    execution_log.append("date-function");
}

# 5. Interval function
@schedule(interval=0.3)
def interval_function {
    execution_log.append("interval-function");
}

# 6. Cron function
@schedule(cron="* * * * *")
def cron_function {
    execution_log.append("cron-function");
}

# 7. Default trigger (static) walker
@schedule(interval=1)
walker StaticWalker {
    can act with Root entry { }
}

# 8. Explicit ScheduleTrigger.STATIC function
@schedule(interval=1, trigger=ScheduleTrigger.STATIC)
def static_fn { }

# 9. String trigger="static" function
@schedule(interval=1, trigger="static")
def str_trigger_fn { }
