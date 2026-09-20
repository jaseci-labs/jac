# Scale Scheduler & Background Jobs

> Part of the [Scale subsystem](jac-scale.md).

The scheduler runs walkers and functions on a timer instead of waiting for an HTTP request. You can declare schedules directly in code (static schedules) or create, change, and remove them at runtime through a REST API (dynamic jobs). Every schedule supports three trigger types: a fixed interval, a cron expression, or a one-shot date.

## Quick Start

Enable the scheduler intent in `jac.toml`:

```toml
[project]
name = "scheduler-demo"
version = "0.1.0"
entry-point = "main"

[scale.scheduler]
enabled = true
```

Decorate a walker or function with `@schedule` in `main.jac`:

```jac
glob tick_log: list = [];

@schedule(trigger=ScheduleTrigger.STATIC, interval=5)
def heartbeat -> None {
    tick_log.append("beat");
    print("heartbeat fired");
}
```

Install the scheduler dependencies (this pulls `apscheduler` into the project's `.jac/venv`), then start the server:

```bash
jac install
jac run --serve main.jac
```

The startup log confirms the subsystem is live and `heartbeat` begins firing every 5 seconds:

```
INFO - Initializing scheduler subsystem
INFO - Base Scheduler started with 1 static task(s)
INFO - APScheduler started (timezone=UTC)
INFO - Scheduler subsystem ready
```

!!! note
    Scheduled tasks run inside the server process. They execute under `jac run --serve`; a plain `jac run` executes your entry point once and exits without firing any schedules.

## The `@schedule` Decorator

`@schedule` works on both walkers and functions. `ScheduleTrigger` and `schedule` are builtins, so no import is needed.

```jac
@schedule(trigger=ScheduleTrigger.STATIC, interval=60)
walker SyncInventory {
    can run with Root entry {
        # runs every 60 seconds
    }
}
```

| Argument | Type | Meaning |
|----------|------|---------|
| `trigger` | `ScheduleTrigger.STATIC` or `ScheduleTrigger.DYNAMIC` | `STATIC` starts running as soon as the server boots. `DYNAMIC` marks the target as schedulable through the `/jobs` REST API. |
| `interval` | `float` | Seconds between runs. Runs land on whole multiples of the interval counted from the Unix epoch in UTC, so every replica agrees on the same ticks and the first run comes within one interval of boot (`interval=3600` runs on the hour). |
| `cron` | `str` | 5-field cron expression, evaluated in UTC. |
| `date` | `str` | One-shot fire time. A bare `"YYYY-MM-DD HH:MM:SS"` is read in the **server's local timezone** here, not UTC. Append an offset, `"2026-12-31 09:00:00+00:00"`, to pin it. |

A `STATIC` schedule needs exactly one of `interval`, `cron`, or `date`. A `DYNAMIC` target takes no timing arguments in code; the timing arrives later with each API call.

The server checks every `@schedule` when it starts and refuses to start, listing each offending target, if a schedule has no timing or more than one kind of it, an `interval` that is not a positive number of seconds, a `cron` expression it cannot honour (see [Cron Expressions](#cron-expressions)), a `date` that is not an ISO date-time, or timing arguments on a `DYNAMIC` target:

```
cannot start the server:
  - @schedule on 'bad_minute': cron '60 * * * *': minute value 60 is outside 0-59
  - @schedule on 'spin': interval must be a positive number of seconds, got 0
```

Scheduled walkers are spawned on a graph root when they fire, so they need an ability with a `Root entry`. Scheduled functions are called with no arguments.

## Static Schedules

Static schedules are part of the code. The server discovers them at startup, registers each one, and keeps firing them until the server stops.

```jac
# Every 5 seconds
@schedule(trigger=ScheduleTrigger.STATIC, interval=5)
def heartbeat -> None {
    print("heartbeat fired");
}

# Every day at 09:00 UTC
@schedule(trigger=ScheduleTrigger.STATIC, cron="0 9 * * *")
walker DailyReport {
    can run with Root entry {
        print("daily report walker fired");
    }
}

# Once, at a specific moment. The offset is explicit because a bare
# timestamp is read in the server's local timezone, not UTC.
@schedule(trigger=ScheduleTrigger.STATIC, date="2026-12-31 09:00:00+00:00")
def year_end_cleanup -> None {
    print("cleanup fired");
}
```

!!! warning
    A static `date` that has already passed by the time the server boots is not an error, since a restart after the date is normal. The server logs a warning naming the target and does not register it. Since a bare timestamp is read in the server's local timezone, a time meant as UTC can land in the past on a server running east of UTC. Pin the offset to avoid this.

Static tasks run as the system user. Use them for app-wide work such as cache warming, digests, and cleanup, not for per-user logic.

With a database configured, each tick of a static task runs on at most one replica: every replica computes the same ticks and claims each one in the database before running it, so a replica that boots, restarts, or is respawned later cannot run a tick that already ran. The claim comes before the run, so a replica that stops after claiming a tick has spent it and nothing retries that tick. A task that must not lose a run, such as billing, should pick up on its next tick whatever an earlier one left undone. Claims are made per service, so two services sharing one database can each have a task with the same name. If a claim cannot be made because the database is unreachable, that tick is skipped rather than run on every replica, and the server logs one warning per task until claims succeed again. Without a database there is no coordination and every replica fires its own copy.

## Cron Expressions

Cron schedules use the standard 5-field layout, always interpreted in UTC:

```
┌───────── minute (0-59)
│ ┌─────── hour (0-23)
│ │ ┌───── day of month (1-31)
│ │ │ ┌─── month (1-12)
│ │ │ │ ┌─ day of week (0=Monday ... 6=Sunday)
│ │ │ │ │
* * * * *
```

Each field accepts `*` (any), `*/n` (every n steps), `a-b` (range), and `a,b,c` (list). Every number must lie in the field's range. The server refuses to start on anything else, such as `60` in the minute field, a stepped range like `1-5/2`, or a day that never occurs in the listed months (`0 0 30 2 *`). A rare but real date is fine: `0 0 29 2 *` runs on the next February 29 however many years away it is.

| Expression | Meaning |
|------------|---------|
| `* * * * *` | Every minute |
| `*/15 * * * *` | Every 15 minutes |
| `0 9 * * *` | Daily at 09:00 UTC |
| `0 3 * * 0` | Every Monday at 03:00 UTC |
| `30 8 1 * *` | The 1st of every month at 08:30 UTC |
| `0 12 * * 0-4` | Weekdays (Mon-Fri) at 12:00 UTC |

!!! warning
    The day-of-week field is numeric and starts at Monday: `0` is Monday and `6` is Sunday. This differs from classic Unix cron, where `0` means Sunday.

## Dynamic Jobs via the REST API

Dynamic jobs let users and admins schedule work at runtime without redeploying. First, mark the walker or function as `DYNAMIC` in code:

```jac
@schedule(trigger=ScheduleTrigger.DYNAMIC)
walker SendDigest {
    can run with Root entry {
        print("digest walker fired");
    }
}

@schedule(trigger=ScheduleTrigger.DYNAMIC)
def cleanup_temp -> None {
    print("cleanup fired");
}
```

The decorator is an allowlist: only `DYNAMIC` targets can be scheduled through the API. Everything else is rejected, so clients can never turn arbitrary code into a background job.

### Get a Token

Every `/jobs` endpoint requires a Bearer token. Register once, then log in:

```bash
# Register
curl -X POST http://localhost:8000/user/register \
  -H 'Content-Type: application/json' \
  -d '{
    "identities": [{"type": "email", "value": "ops@example.com"}],
    "credential": {"type": "password", "password": "Secret123!"}
  }'

# Log in and capture the token
TOKEN=$(curl -s -X POST http://localhost:8000/user/login \
  -H 'Content-Type: application/json' \
  -d '{
    "identity": {"type": "email", "value": "ops@example.com"},
    "credential": {"type": "password", "password": "Secret123!"}
  }' | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['token'])")
```

### Create a Job

`POST /jobs` takes the target name plus one trigger spec:

```bash
# Run the SendDigest walker every 60 seconds
curl -X POST http://localhost:8000/jobs \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"walker_or_function": "SendDigest", "trigger": "interval", "interval": 60}'
```

A successful create returns `201` with the stored job:

```json
{
  "ok": true,
  "type": "response",
  "data": {
    "job_id": "7e540f18-bde5-48a4-9fa8-f627759f618f",
    "name": "SendDigest",
    "created_by": "35e1541f-3010-4828-8765-4df9139a65c9",
    "is_walker": true,
    "created_at": "2026-07-30T06:55:00.583399+00:00",
    "status": "active",
    "service": "main",
    "trigger": "interval",
    "interval": 60.0,
    "cron": null,
    "date": null
  },
  "error": null,
  "meta": {"extra": {"http_status": 201}}
}
```

The same endpoint handles cron and one-shot date jobs:

```bash
# Run cleanup_temp every night at 03:00 UTC
curl -X POST http://localhost:8000/jobs \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"walker_or_function": "cleanup_temp", "trigger": "cron", "cron": "0 3 * * *"}'

# Fire cleanup_temp once at a specific UTC datetime
curl -X POST http://localhost:8000/jobs \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"walker_or_function": "cleanup_temp", "trigger": "date", "date": "2026-12-31 09:00:00"}'
```

Scheduling a target that is not decorated with `@schedule(trigger=ScheduleTrigger.DYNAMIC)` fails with a `400`:

```json
{
  "ok": false,
  "type": "error",
  "data": null,
  "error": {
    "code": "INVALID_REQUEST",
    "message": "\"get_log\" does not have a @schedule decorator. Add @schedule(trigger=ScheduleTrigger.DYNAMIC) to enable dynamic scheduling."
  },
  "meta": {"extra": {"http_status": 400}}
}
```

### List, Inspect, Update, Delete

```bash
# List your jobs (admins see all jobs)
curl "http://localhost:8000/jobs?limit=10&offset=0" \
  -H "Authorization: Bearer $TOKEN"

# Fetch one job by id
curl http://localhost:8000/jobs/7e540f18-bde5-48a4-9fa8-f627759f618f \
  -H "Authorization: Bearer $TOKEN"

# Change the schedule: switch the interval job to every 15 minutes via cron
curl -X PUT http://localhost:8000/jobs/7e540f18-bde5-48a4-9fa8-f627759f618f \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"trigger": "cron", "cron": "*/15 * * * *"}'

# Remove the job
curl -X DELETE http://localhost:8000/jobs/7e540f18-bde5-48a4-9fa8-f627759f618f \
  -H "Authorization: Bearer $TOKEN"
```

The list response is paginated and scoped to the caller:

```json
{
  "ok": true,
  "type": "response",
  "data": {
    "jobs": [ /* job records */ ],
    "count": 2,
    "total": 2,
    "limit": 10,
    "offset": 0
  },
  "error": null,
  "meta": {"extra": {"http_status": 200}}
}
```

`GET /jobs` also accepts `trigger` (filter by `interval`, `cron`, or `date`) and, for admins, `created_by` (filter by user id) as query parameters.

### API Summary

| Method | Path | Purpose |
|--------|------|---------|
| `POST` | `/jobs` | Create a job for a `DYNAMIC` walker or function |
| `GET` | `/jobs` | List active jobs (paginated, filterable) |
| `GET` | `/jobs/{job_id}` | Fetch one job |
| `PUT` | `/jobs/{job_id}` | Replace the job's trigger spec |
| `DELETE` | `/jobs/{job_id}` | Delete the job |

### Ownership and Execution Identity

- Regular users see and manage only jobs they created. Admins can inspect, update, and delete any job.
- A dynamic walker job runs as the user who created it: the walker is spawned on that user's graph root, so per-user jobs operate on per-user data.
- If the creating user is later deleted, the job stops running and is marked `failed` instead of executing against a missing account.
- Static schedules, by contrast, always run as the system user.

### Error Reference

| HTTP | Code | When |
|------|------|------|
| `400` | `INVALID_REQUEST` | Missing trigger fields, a malformed cron expression, a target without the `@schedule` decorator, or a target that is not `DYNAMIC` |
| `401` | `UNAUTHORIZED` | Missing or invalid `Authorization` header |
| `404` | `NOT_FOUND` | Unknown walker/function name, or job id that does not exist (or belongs to another user) |
| `503` | `STORAGE_UNAVAILABLE` | The database job store is temporarily unreachable |
| `500` | `SCHEDULER_ERROR` | Unexpected internal failure |

!!! note
    A `date` string that does not parse passes request validation and only fails when the job is handed to the scheduling engine, so it currently surfaces as `500 SCHEDULER_ERROR` rather than `400`. Stick to the `"YYYY-MM-DD HH:MM:SS"` format shown above.

## Persistence and Run History

Where jobs live depends on the database connection, set as `url` under `[scale.database]` in `jac.toml` or via the `JAC_DB_URL` environment variable:

- **No reachable database**: jobs are held in memory. Dynamic jobs disappear when the server restarts and exist only on the replica that accepted the `POST`. There is also no duplicate-run protection: a schedule registered on more than one replica fires on every one of them, so this mode is for a single local server, not for multi-replica deployments.
- **Database configured** (provisioned automatically by `--scale` on Kubernetes): jobs are persisted to the document store under the `scheduled_jobs` collection, survive restarts, and are re-registered on boot. Each scheduled run of a job is claimed in the database by at most one replica, keyed by the time the run was scheduled for, so a run that starts late cannot repeat one another replica already made. As with static tasks, a replica that stops after claiming a run has spent it. A run that cannot be claimed because the database is unreachable is skipped rather than made on every replica. A job is recorded with the `service` that created it. `GET /jobs` lists jobs from every service that shares the database, each with its `service`, while a service schedules, reads, changes and deletes only its own jobs and answers `404` for the rest, which is how the fleet gateway finds the service that owns a job. A job with no `service`, written by an earlier release, belongs to whichever service serves its target.

Each execution updates the job record with run bookkeeping, visible via `GET /jobs/{job_id}`:

| Field | Meaning |
|-------|---------|
| `run_count` | Total number of completed runs |
| `last_run_at` | UTC timestamp of the most recent run |
| `last_status` | `succeeded` or `failed` |
| `last_error` | Error message from the last failed run, else `null` |

## Configuration Reference

All keys live under `[scale.scheduler]` in `jac.toml`:

```toml
[scale.scheduler]
enabled = true
collection = "scheduled_jobs"
thread_pool_size = 10
misfire_grace_time = 60
shutdown_timeout = 10
min_interval = 1.0
max_jobs_per_user = 25
```

| Key | Default | Meaning |
|-----|---------|---------|
| `enabled` | `None` | Install-time capability flag: declares that the project uses the scheduler so `jac install` resolves its dependencies (`apscheduler`). It is not a runtime switch; the server always starts the scheduler subsystem and registers `/jobs` and any static schedules. Static schedules run on the built-in scheduler and need no extra packages; dynamic jobs created through `/jobs` require `apscheduler` |
| `collection` | `"scheduled_jobs"` | Collection name for jobs in the database-backed job store |
| `thread_pool_size` | `10` | Worker threads available for concurrently firing jobs |
| `misfire_grace_time` | `60` | Seconds a late job may still fire after its scheduled time (for example after a restart) before the run is skipped |
| `shutdown_timeout` | `10` | Seconds to wait for in-flight jobs when the server stops |
| `system_user_password` | `"__no_login__"` | Password assigned to the internal `__system__` account that static tasks run as, created on first boot. The default is a sentinel; set a real value if you need to log in as that account |
| `user_exists_ttl` | `30.0` | Seconds the scheduler caches the creator-still-exists check for dynamic jobs before re-querying the user store |
| `min_interval` | `1.0` | Shortest interval a dynamic job may ask for, in seconds. `POST`/`PUT /jobs` answer `400` below it, and a stored row asking for less is clamped to it when scheduled. A value that is not a finite number above zero is reported at boot and the default is used, so the floor cannot be switched off by a typo |
| `max_jobs_per_user` | `25` | Active jobs one non-admin account may hold in one service. `POST /jobs` answers `429 QUOTA_EXCEEDED` at the cap; admins are exempt and `0` means unlimited. Each service counts only its own jobs, plus any job written before jobs recorded a service. The count and the write happen together in the job store, serialised per account and service, so concurrent requests cannot race past the cap. A value that is not a whole number of zero or more is reported at boot and the default is used, so a fractional typo cannot round down into `0` and lift the cap |

## Behavior Notes

- Cron fields, dynamic job triggers, and stored timestamps are all UTC. The one exception is a bare `date` string on `@schedule`, which is read in the server's local timezone; pin an offset there.
- A job never overlaps itself. If a run is still going when the next fire time arrives, the new run waits (`max_instances=1`).
- Every fire missed within `misfire_grace_time` runs on recovery, each claiming its own tick, so a replica that stalls makes up to `misfire_grace_time / interval` runs back to back before it catches up. Misses older than the grace window are dropped. Lower `misfire_grace_time` if a burst is worse for your job than a gap.
- Keep scheduled work idempotent where possible. Interval and cron jobs will run many times, and a restart near a fire time can produce a make-up run.
