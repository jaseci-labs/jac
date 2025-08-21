# Task Scheduling: Automate Your Jac Applications

## Overview

Jac Cloud's scheduler allows you to run walkers automatically at specific times or intervals. This is useful for:

- Running periodic background tasks
- Processing data at scheduled intervals
- Sending scheduled notifications
- Executing maintenance operations
- Any task that needs to happen on a recurring basis

## Scheduler Configuration

To configure a scheduled walker, add a `schedule` dictionary to the walker's `__specs__` configuration. The schedule supports three trigger types:

1. **Cron** - Schedule using cron expressions
2. **Interval** - Schedule at regular time intervals
3. **Date** - Schedule at a specific date and time

### Common Configuration Options

| **NAME**      | **TYPE**               | **DESCRIPTION**                                                                                   | **DEFAULT** |
| ------------- | ---------------------- | ------------------------------------------------------------------------------------------------- | ----------- |
| trigger       | str                    | trigger type (`cron`, `interval`, `date`)                                                         | N/A         |
| node          | str or None            | entry node if necessary, defaults to root                                                         | None        |
| args          | list[Any] or None      | list of arguments to initialize the walker                                                        | None        |
| kwargs        | dict[str, Any] or None | dict of keyword arguments to initialize the walker                                                | None        |
| max_instances | int                    | max simultaneous running job per walker type                                                      | 1           |
| next_run_time | datetime or None       | target date before the first trigger will happen                                                  | None        |
| propagate     | bool                   | if multiple jac-cloud service can trigger at the same time or first service only per trigger only | false       |
| save          | bool                   | if walker instance will be save to the db including the results                                   | false       |

## Cron Trigger

The cron trigger uses a cron-like expression to schedule tasks with high precision.

### Additional Cron Configuration Options

| **NAME**    | **TYPES**               | **DESCRIPTION**                                                | **DEFAULT** |
| ----------- | ----------------------- | -------------------------------------------------------------- | ----------- |
| year        | int or str              | 4-digit year                                                   | \*          |
| month       | int or str              | month (1-12)                                                   | \*          |
| day         | int or str              | day of month (1-31)                                            | \*          |
| week        | int or str              | ISO week (1-53)                                                | \*          |
| day_of_week | int or str              | number or name of weekday (0-6 or mon,tue,wed,thu,fri,sat,sun) | \*          |
| hour        | int or str              | hour (0-23)                                                    | \*          |
| minute      | int or str              | minute (0-59)                                                  | \*          |
| second      | int or str              | second (0-59)                                                  | \*          |
| start_date  | datetime or str or None | earliest possible date/time to trigger on (inclusive)          | None        |
| end_date    | datetime or str or None | latest possible date/time to trigger on (inclusive)            | None        |

### Cron Example

```jac
walker walker_cron {
    has arg1: int;
    has arg2: str;
    has kwarg1: int = 3;
    has kwarg2: str = "4";

    can enter with `root entry {
        print("I am a scheduled walker!")
    }

    class __specs__ {
        has private: bool = True;
        has schedule: dict = {
            "trigger": "cron",
            "args": [1, "2"],
            "kwargs": {
                "kwarg1": 30,
                "kwarg2": "40"
            },
            # Run every day at midnight
            "hour": "0",
            "minute": "0",
            "save": True
        };
    }
}
```

## Interval Trigger

The interval trigger runs a task at regular time intervals.

### Additional Interval Configuration Options

| **NAME**   | **TYPES**               | **DESCRIPTION**                             | **DEFAULT** |
| ---------- | ----------------------- | ------------------------------------------- | ----------- |
| weeks      | int                     | number of weeks to wait                     |             |
| days       | int                     | number of days to wait                      |             |
| hours      | int                     | number of hours to wait                     |             |
| minutes    | int                     | number of minutes to wait                   |             |
| seconds    | int                     | number of seconds to wait                   | 1           |
| start_date | datetime or str or None | starting point for the interval calculation |             |
| end_date   | datetime or str or None | latest possible date/time to trigger on     |             |

### Interval Example

```jac
walker walker_interval {
    has arg1: int;
    has arg2: str;
    has kwarg1: int = 3;
    has kwarg2: str = "4";

    can enter with `root entry {
        print("I am a scheduled walker running every 5 seconds!");
    }

    class __specs__ {
        has private: bool = True;
        has schedule: dict = {
            "trigger": "interval",
            "args": [1, "2"],
            "kwargs": {
                "kwarg1": 30,
                "kwarg2": "40"
            },
            "seconds": 5,
            "save": True
        };
    }
}
```

## Date Trigger

The date trigger runs a task once at a specific date and time.

### Additional Date Configuration Options

| **NAME** | **TYPES**       | **DESCRIPTION**                 | **DEFAULT** |
| -------- | --------------- | ------------------------------- | ----------- |
| run_date | datetime or str | the date/time to run the job at |             |

### Date Example

```jac
walker walker_date {
    has arg1: int;
    has arg2: str;
    has kwarg1: int = 3;
    has kwarg2: str = "4";

    can enter with `root entry {
        print("I am a scheduled walker running once at a specific time!");
    }

    class __specs__ {
        has private: bool = True;
        has schedule: dict = {
            "trigger": "date",
            "args": [1, "2"],
            "kwargs": {
                "kwarg1": 30,
                "kwarg2": "40"
            },
            "run_date": "2025-04-30T11:12:00+00:00",
            "save": True
        };
    }
}
```

## Jac Cloud Optional Task Queue

Jac Cloud also supports asynchronous task management that can be enabled by setting the `TASK_CONSUMER_CRON_SECOND` environment variable. This allows you to create tasks that will be processed by a background worker.

### Example Use Case

```jac
import from jac_cloud.plugin.implementation {create_task}

node TaskCounter {
    has val: int = 0;
}

walker get_or_create_counter {
    can enter1 with `root entry {
        tc = TaskCounter();
        here ++> tc;

        report tc;
    }

    can enter2 with TaskCounter entry {
        report here;
    }
}

walker increment_counter {
    has val: int;

    can enter with TaskCounter entry {
        here.val += self.val;
    }

    class __specs__ {
        has private: bool = True;
    }
}

walker trigger_counter_task {
    can enter with `root entry {
        tcs = [-->(`?TaskCounter)];
        if tcs {
            report create_task(increment_counter(val=1), tcs[0]);
        }
    }
}
```

### How Tasks Work

- `trigger_counter_task` creates a walker task that will be consumed by the Task Consumer
- The task is saved to both the database and Redis
- The polling mechanism uses Redis to avoid excessive database traffic
  - The minimum polling interval is 1 second, configurable via `TASK_CONSUMER_CRON_SECOND`
- Task consumption is atomic, ensuring only one Jac Cloud instance processes each task
- If Redis is cleared, pending tasks will be repopulated from the database when Jac Cloud restarts

## Best Practices

1. **Set Appropriate Intervals**: Use intervals that match your application's needs (e.g., don't poll every second if hourly updates are sufficient)
2. **Make Tasks Idempotent**: Design scheduled tasks to be safely run multiple times
3. **Handle Failures Gracefully**: Add error handling in your scheduled walkers
4. **Consider Time Zones**: Be aware of server time zones when scheduling date/time-specific tasks
5. **Monitor Task Performance**: Log execution times and success rates for scheduled tasks

## Debugging Scheduled Tasks

If your scheduled task isn't running:

1. Check that the `schedule` configuration is correctly formatted
2. Ensure the `private` flag is set to `true` (recommended for scheduled tasks)
3. Verify the environment variable `TASK_CONSUMER_CRON_SECOND` is set (for async tasks)
4. Check the logs for any errors during task execution
5. Test the walker manually to ensure it works properly

## Next Steps

- Learn about [WebSocket Communication](websocket.md) for real-time updates
- Explore [Webhook Integration](webhook.md) for external service integration
- Set up [Logging & Monitoring](logging.md) to track task execution
- Deploy your application using [Kubernetes](deployment.md) for scalable task processing