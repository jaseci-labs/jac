---
description: The native logging module and logging.handlers, as CPython's - loggers, handlers, filters, formatters, adapters, the file and rotating handlers - and what they leave out.
keywords: logging, logging.getLogger, logging.basicConfig, logging.Logger, logging.LoggerAdapter, logging.Handler, logging.StreamHandler, logging.FileHandler, logging.NullHandler, logging.Filter, logging.Formatter, logging.BufferingFormatter, logging.LogRecord, logging.getLevelName, logging.addLevelName, logging.disable, logging.shutdown, logging.lastResort, logging.DEBUG, logging.INFO, logging.WARNING, logging.ERROR, logging.CRITICAL, logging.handlers, logging.handlers.RotatingFileHandler, logging.handlers.TimedRotatingFileHandler, logging.handlers.WatchedFileHandler, logging.handlers.MemoryHandler, logging.handlers.BufferingHandler, logging.handlers.SysLogHandler, logging.handlers.HTTPHandler, logging.handlers.SMTPHandler, logging.handlers.QueueHandler, logging.handlers.QueueListener, logging.config
---
# logging

`logging` is CPython's `logging`: named loggers in a hierarchy, levels, handlers, filters,
formatters in the three styles (`%`, `{`, `$`), adapters, and `basicConfig`, with CPython's
records and output. `logging.handlers` has the handlers that write files (rotating by size or by
time, watched), that buffer in memory, and that send records on: to a syslog server, to a web
server, and through a queue to a thread. Both are native (see [The library](index.md),
`jac docs library`).

```jac
import logging;
import sys;

with entry {
    logging.basicConfig(
        level=logging.INFO, format="%(levelname)s %(name)s: %(message)s", stream=sys.stdout
    );
    logging.basicConfig(level=logging.DEBUG);  # nothing: the root logger is configured
    log = logging.getLogger("app.db");
    log.info("connected to %s:%d", "db.local", 5432);
    log.debug("not shown: below INFO");
    log.warning("slow query: %.1fs", 1.5);
    print(log.parent.name);  # no logger is named "app" yet
    app = logging.getLogger("app");
    print(log.parent is app);
    audit = logging.getLogger("audit");
    h = logging.StreamHandler(sys.stdout);
    h.setFormatter(logging.Formatter("audit %(levelname)s %(message)s"));
    audit.addHandler(h);
    audit.propagate = False;
    audit.error("denied");
    adapter = logging.LoggerAdapter(log, {"user": "ada"});
    adapter.info("as %s", adapter.extra["user"]);
    print(
        logging.getLevelName(logging.ERROR),
        logging.getLevelName(33),
        isinstance(h, logging.Handler),
    );
}
```

```output
INFO app.db: connected to db.local:5432
WARNING app.db: slow query: 1.5s
root
True
audit ERROR denied
INFO app.db: as ada
ERROR Level 33 True
```

Records pass as in CPython: a logger's effective level is its own or its nearest ancestor's; a
record goes to its logger's handlers and, while `propagate` is true, its ancestors'; a handler's
own level and its filters judge it after the logger's. A record that reaches no handler goes to
`lastResort`, which writes `WARNING` and above to standard error. The message is formatted with
its arguments (`msg % args`) only when a handler takes the record.

## Handlers and filters

`StreamHandler`, `FileHandler` and `NullHandler` are in `logging`; the rest in
`logging.handlers`. Each is a class, which a program's class inherits to make a handler of its
own (override `emit`). A `Filter` (or any class that overrides its `filter`) is added to a logger
or a handler.

```jac
import logging;
import logging.handlers;
import os;

class OnlyDb(logging.Filter) {
    override def filter(record: logging.LogRecord) -> bool {
        return record.name.startswith("app.db");
    }
}

with entry {
    log = logging.getLogger("app.db");
    log.setLevel(logging.INFO);
    rot = logging.handlers.RotatingFileHandler("app.log", maxBytes=20, backupCount=1);
    rot.addFilter(OnlyDb());
    logging.getLogger().addHandler(rot);
    for i in range(3) {
        log.info("record %d", i);
    }
    logging.getLogger("app.cache").warning("filtered out of app.log");
    rot.close();
    print(sorted(n for n in os.listdir(".") if n.startswith("app.log")));
}
```

```output
['app.log', 'app.log.1']
```

| Handler | What it does |
|---|---|
| `StreamHandler(stream=None)` | Writes to a stream: `sys.stderr` by default, or any object with `write` and `flush` |
| `FileHandler(filename, mode="a", encoding=None, delay=False, errors=None)` | Writes to a file |
| `NullHandler()` | Takes records and does nothing, for a library's logger |
| `handlers.RotatingFileHandler(filename, mode="a", maxBytes=0, backupCount=0, ...)` | Starts a new file when the next record would pass `maxBytes`, keeping `backupCount` old ones as `.1`, `.2`, ... |
| `handlers.TimedRotatingFileHandler(filename, when="h", interval=1, backupCount=0, ...)` | Starts a new file at each interval (`S`, `M`, `H`, `D`, `midnight`, `W0` to `W6`) |
| `handlers.WatchedFileHandler(filename, ...)` | Opens the file again when it has been moved or removed |
| `handlers.MemoryHandler(capacity, flushLevel=ERROR, target=None, flushOnClose=True)`, `handlers.BufferingHandler(capacity)` | Keeps records in `buffer` and hands them to `target` when full or at `flushLevel` |
| `handlers.SysLogHandler(address=("localhost", 514), facility=LOG_USER, socktype=None, timeout=None)` | Sends each record to a syslog server: over UDP, over TCP (`socktype=socket.SOCK_STREAM`), or to a Unix socket when `address` is a path (`"/dev/log"`) |
| `handlers.HTTPHandler(host, url, method="GET", secure=False, credentials=None, context=None)` | Sends each record's attributes to a web server as a form, by GET or POST, over HTTPS with `secure` |
| `handlers.SMTPHandler(mailhost, fromaddr, toaddrs, subject, credentials=None, secure=None, timeout=5.0)` | Mails each record through an SMTP server, `mailhost` a host or a `(host, port)` pair: it logs in with `credentials`, a `(user, password)` pair, after STARTTLS when `secure` is given. `getSubject(record)` gives the subject |
| `handlers.QueueHandler(queue)`, `handlers.QueueListener(queue, *handlers, respect_handler_level=False)` | Puts each record on a queue; the listener's thread (`start`, `stop`, or `with`) takes them off and gives them to its handlers |

## Differences from CPython

- **`Handler.handleError`**, called when a handler's `emit` fails, prints the error and the
  record's message and arguments to `sys.stderr`, as CPython does, without the call stack
  CPython prints between them: there are no frames to print it from.
- **A record does not know where it was logged from**: `pathname`, `lineno` and `funcName` are
  empty (or 0), as there are no frames to read them from.

## What is left out

`logging.handlers` leaves out, with E5142 and what to write instead: `SocketHandler` and
`DatagramHandler`, which send each record pickled (there is no native `pickle`; `SysLogHandler`
sends text over the same sockets); and `NTEventLogHandler`, which is pywin32's. The
`logging.config` module is not native yet (E5143).

```jac
# expect: E5142
import logging.handlers;

with entry {
    print(logging.handlers.SocketHandler);
}
```
