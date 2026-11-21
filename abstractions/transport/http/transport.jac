"""The standard transport: requests carried over HTTP, a call's reply
as JSON and a stream's events as they are made (`text/event-stream`), and the
server that answers them.

The server answers each call on a thread of its own, so a call that waits (for
a model, for an event another call makes) holds no other up, and a stream
endpoint's events go out as it makes them. The threads take turns as a
program's own do (the runtime's Jac lock): one runs at a time, and gives way
where it waits. Its loop accepts and reads requests, and runs what the
program has for it between them."""

import http.client;
import re;
import select;
import socket;
import threading;
import time;
import urllib.request;
import from urllib.error { HTTPError }
import from common.contract { Host }
import from transport.contract {
    CannotListen,
    Claim,
    Request,
    Response,
    Tick,
    Transport,
    json_fail,
}

# The most a request's head and body may be.
glob MAX_HEAD: int = 1048576,
     MAX_BODY: int = 16777216,
     # The most connections open at once: past it, the one open longest is
     # let go for the next. (select() watches descriptors below 1024.)
     MAX_CONNECTIONS: int = 512,
     # How long a connection may take to send its request.
     REQUEST_SECONDS: float = 60.0,
     # How long a refused request's client may go on sending after its answer.
     LINGER_SECONDS: float = 2.0,
     # The most calls answered at once: one past it waits for a thread.
     MAX_CALLS: int = 256,
     # How long a thread that answers calls waits for one before it ends.
     IDLE_SECONDS: float = 30.0,
     # How long a stream may say nothing before the server says it is still
     # there: a comment, which a reader passes over.
     KEEPALIVE_SECONDS: float = 15.0;

"""A request the server won't read: answered with `status`, saying `detail`,
and its connection closed."""
obj Refused(Exception) {
    has status: int,
        detail: str;
}

"""The request `buf` holds, once all of it has come; None until then. Raises
Refused for one the server won't read, with the status that says why."""
def parse_request(buf: bytes) -> Request | None {
    if b"\r\n\r\n" not in buf {
        if len(buf) > MAX_HEAD {
            raise Refused(status=431, detail="the request's head is too large");
        }
        return None;
    }
    at = buf.index(b"\r\n\r\n");
    if at > MAX_HEAD {
        raise Refused(status=431, detail="the request's head is too large");
    }
    head = buf[0:at].decode("latin-1").split("\r\n");
    first = head[0].split(" ");
    if len(first) != 3 or not first[1].startswith("/") or not first[2].startswith("HTTP/1.") {
        raise Refused(status=400, detail="a malformed request line");
    }
    headers: dict[str, str] = {};
    for line in head[1:len(head)] {
        (k, colon, v) = line.partition(":");
        if colon == "" or k.strip() == "" {
            raise Refused(status=400, detail="a malformed header");
        }
        headers[k.strip().lower()] = v.strip();
    }
    if "transfer-encoding" in headers {
        # Only a body whose length its head gives is read.
        if headers["transfer-encoding"].lower() == "chunked" {
            raise Refused(status=411, detail="a body is read by its Content-Length, not in chunks");
        }
        raise Refused(status=501, detail="a body is read by its Content-Length alone");
    }
    length = headers.get("content-length", "0");
    if re.fullmatch("[0-9]{1,18}", length) is None {
        raise Refused(status=400, detail="a malformed Content-Length");
    }
    need = int(length);
    if need > MAX_BODY {
        raise Refused(status=413, detail="the request's body is too large");
    }
    body = buf[at + 4:len(buf)];
    if len(body) < need {
        return None;
    }
    (path, _, query) = first[1].partition("?");
    return Request(method=first[0], path=path, query=query, headers=headers, body=body[0:need]);
}

"""Whether the client of the request `buf` holds, whole, reads interim
replies, which one waiting for a call that takes long is sent: HTTP/1.0's
does not."""
def reads_interim(buf: bytes) -> bool {
    return not buf[0:buf.index(b"\r\n")].endswith(b" HTTP/1.0");
}

# A socket is `any` here: on cpython it's CPython's, whose classes can't be
# named as types yet.
def write_response(conn: any, r: Response) {
    lines = [
        "HTTP/1.1 " + str(r.status) + " " + http.client.responses.get(r.status, ""),
        "Content-Type: " + r.ctype,
        "Content-Length: " + str(len(r.body)),
        "Connection: close",
    ];
    for (k, v) in r.headers.items() {
        lines.append(k + ": " + v);
    }
    conn.sendall(("\r\n".join(lines) + "\r\n\r\n").encode("latin-1") + r.body);
}

"""What `handle` answers `req`: a failure of its own is the server's (500),
and says nothing of what failed."""
def respond(handle: Callable[[Request], Response], req: Request) -> Response {
    try {
        return handle(req);
    } except Exception as e {
        print("request " + req.path + " failed: " + str(e));
        return json_fail(500, "failed", "the server failed to answer");
    }
}

"""A connection a client is waiting on: a stream being sent, or a call
that has not been answered yet (`interim`). Its connection, what holds it
while something is written to it, and when something last was."""
obj Sending {
    has conn: any,
        turn: any,
        last: float,
        interim: bool = False;
}

"""The threads that answer calls: as many as there are calls being answered,
and no more. A call is handed to one that waits, and a thread is started only
when every one of them has a call (a thread costs a heap of its own), up to
MAX_CALLS; one that has waited IDLE_SECONDS for a call ends.

Nothing the loop's thread made is handed to a call's thread to drop. A block
one thread frees goes to that thread's heap and never back to the heap it
came from, so what the loop made for each request, dropped by the thread that
answered it, would be memory the loop never had again. A call is handed over
as numbers: its connection's descriptor, of which its thread makes a socket
of its own, and a ticket for its request's bytes, which stay the loop's: the
call's thread reads its own Request out of them, and the loop drops them."""
obj Calls {
    # (Given a call's connection, its request, and whether its client reads
    # interim replies.)
    has answer: Callable[[any, Request, bool], None],
        turn: any = threading.Condition(),
        # Each call waiting for a thread: its descriptor, then its ticket.
        queued: list[int] = [],
        # Each request's bytes by its ticket, and the tickets whose bytes
        # their calls' threads have read.
        held: dict[int, bytes] = {},
        read: list[int] = [],
        tickets: int = 0,
        threads: int = 0,
        # The calls taken that are not yet answered.
        open: int = 0;

    """Have a thread answer the request `request` holds, whole, on the
    connection whose descriptor is `descriptor`: the loop's to ask."""
    def take(descriptor: int, request: bytes) {
        with self.turn {
            self.tickets += 1;
            self.held[self.tickets] = request;
            self.queued.append(descriptor);
            self.queued.append(self.tickets);
            self.open += 1;
            if self.open > self.threads and self.threads < MAX_CALLS {
                self.threads += 1;
                threading.Thread(target=self.work, daemon=True).start();
            } else {
                self.turn.notify();
            }
        }
    }

    """Drop the bytes of the requests their calls' threads have read: the
    loop's to do, as it turns."""
    def settle {
        with self.turn {
            for ticket in self.read {
                del self.held[ticket];
            }
            self.read.clear();
        }
    }

    """A call was answered: its thread is as good as free."""
    def answered {
        with self.turn {
            self.open -= 1;
        }
    }

    """A thread's life: the calls it is handed, one after another."""
    def work {
        forever {
            descriptor = -1;
            ticket = 0;
            with self.turn {
                while len(self.queued) == 0 {
                    # (Woken for a call another thread took first, it waits
                    # on: only one that waited the whole time ends.)
                    if not self.turn.wait(IDLE_SECONDS) and len(self.queued) == 0 {
                        self.threads -= 1;
                        return;
                    }
                }
                descriptor = self.queued.pop(0);
                ticket = self.queued.pop(0);
            }
            conn = socket.socket(fileno=descriptor);
            conn.settimeout(10.0);
            req: Request | None = None;
            interim = True;
            try {
                req = parse_request(self.held[ticket]);
                interim = reads_interim(self.held[ticket]);
                if req is not None {
                    req.client = str(conn.getpeername()[0]);
                }
            } except Exception as e {
                # (The loop read it as a whole request: this is not reached.)
                print("request failed: " + str(e));
            }
            with self.turn {
                self.read.append(ticket);
            }
            if req is None {
                self.answered();
                conn.close();
            } else {
                self.answer(conn, req, interim);
            }
        }
    }
}

"""Answer `req` on `conn` and close it: a call's whole life, on a thread of
its own. A stream's events are sent each as it is made, to a client that is
told nothing of their length and reads until the connection closes; one whose
client has gone is closed where it paused."""
def answer_on(
    conn: any,
    req: Request,
    interim: bool,
    handle: Callable[[Request], Response],
    sending: dict[int, Sending],
    calls: Calls,
) {
    told = False;
    try {
        # While its endpoint runs, its client is told every KEEPALIVE_SECONDS
        # that the call is still being answered (keep_alive), so a caller
        # gives up on a server that has gone silent, not on a call that takes
        # long. Nothing is told it once its reply is to be written.
        waiting = Sending(conn=conn, turn=threading.Lock(), last=time.time(), interim=True);
        if interim {
            sending[id(waiting)] = waiting;
        }
        try {
            r = respond(handle, req);
        } finally {
            with waiting.turn {
                sending.pop(id(waiting), None);
            }
        }
        events = r.events;
        if events is None {
            # (Said before its reply is written: the client's next request
            # may come before this thread runs again.)
            told = True;
            calls.answered();
            write_response(conn, r);
        } else {
            lines = [
                "HTTP/1.1 " + str(r.status) + " " + http.client.responses.get(r.status, ""),
                "Content-Type: text/event-stream",
                "Cache-Control: no-cache",
                "X-Accel-Buffering: no",
                "Connection: close",
            ];
            for (k, v) in r.headers.items() {
                lines.append(k + ": " + v);
            }
            conn.sendall(("\r\n".join(lines) + "\r\n\r\n").encode("latin-1"));
            s = Sending(conn=conn, turn=threading.Lock(), last=time.time());
            sending[id(s)] = s;
            try {
                for event in events {
                    with s.turn {
                        conn.sendall(event);
                        s.last = time.time();
                    }
                }
            } finally {
                del sending[id(s)];
                # Ended, or its client went: closed where it paused, so
                # what the endpoint owes there runs.
                events.close();
            }
        }
    } except OSError as gone {
        # The client went or stalled: nothing more is owed it.
        print("request " + req.path + ": its client went: " + str(gone));
    } except Exception as e {
        print("request " + req.path + " failed: " + str(e));
    }
    if not told {
        calls.answered();
    }
    try {
        conn.close();
    } except OSError {
        # (Closed already.)
    }
}

"""Tell the reader of each stream that has said nothing for
KEEPALIVE_SECONDS that it is still there, and the caller of each call that
has not been answered for as long that it is being answered (an interim
reply, which a client passes over), where that takes no waiting."""
def keep_alive(sending: dict[int, Sending], now: float) {
    for s in list(sending.values()) {
        if now - s.last < KEEPALIVE_SECONDS or not s.turn.acquire(False) {
            continue;
        }
        try {
            (_, ready, _) = select.select([], [s.conn.fileno()], [], 0.0);
            if len(ready) > 0 {
                s.conn.sendall(
                    b"HTTP/1.1 100 Continue\r\n\r\n" if s.interim else b": still here\n\n"
                );
            }
            s.last = now;
        } except Exception {
            # (Its client has gone: the stream's own thread finds out.)
            s.last = now;
        } finally {
            s.turn.release();
        }
    }
}

"""Each event of the stream reply `r`, whole, as it comes: one cut short ends
as it was cut."""
def events_of(r: any) -> Iterator[bytes] {
    with r {
        event = b"";
        forever {
            line: bytes = r.readline();
            if len(line) == 0 {
                return;
            }
            event = event + line;
            if line == b"\n" or line == b"\r\n" {
                yield event;
                event = b"";
            }
        }
    }
}

"""An address this transport took for its program: the socket that listens
there, which the loop takes connections from."""
obj Bound(Claim) {
    # (A socket is `any`: on cpython it is CPython's, whose classes can't be
    # named as types yet.)
    has sock: any;
}

obj HttpTransport(Transport) {
    # Work for the loop to do on its own thread, the one the program started
    # on, and the pair of sockets that wakes the loop for it, once it listens.
    has work: list[Callable[[], None]] postinit;
    has wake: list[any] postinit;

    def postinit {
        self.work = [];
        self.wake = [];
    }

    """Nothing to open: it asks nothing of the program, and takes its address
    when it is told to (`claim`)."""
    def open(host: dyn Host) {}

    """`r`, sent to the app at `address` (`http://host:port`): its reply. A
    status that says the request failed is still a reply."""
    def send(address: str, r: Request, seconds: float) -> Response {
        req = urllib.request.Request(
            address.rstrip("/") + r.path + ("?" + r.query if r.query != "" else ""),
            data=(r.body if r.method != "GET" else None),
            headers=r.headers,
            method=r.method,
        );
        got: any = None;
        try {
            got = urllib.request.urlopen(req, timeout=seconds);
        } except HTTPError as e {
            return Response(status=e.code, body=e.read());
        }
        status: int = got.status;
        ctype: str = got.headers.get("content-type", "");
        if ctype.startswith("text/event-stream") {
            return Response(status=status, ctype=ctype, events=events_of(got));
        }
        with got {
            body: bytes = got.read();
            return Response(status=status, ctype=ctype, body=body);
        }
    }

    def serving -> bool {
        return len(self.wake) == 2;
    }

    """A request over HTTP names any path."""
    def serves_paths -> bool {
        return True;
    }

    def on_loop(work: Callable[[], None]) {
        self.work.append(work);
        if len(self.wake) == 2 {
            self.wake[1].send(b"!");
        }
    }

    """A socket listening at `address` (`host:port`; port 0, one the system
    picks). CannotListen where it can't: an address that is not a host and a
    port, with the system's reason where the system refused it."""
    def claim(address: str) -> Claim {
        (host, colon, port_text) = address.rpartition(":");
        if colon == "" or not port_text.isascii() or not port_text.isdigit() {
            raise CannotListen(reason="an address is a host and a port, as 127.0.0.1:8000");
        }
        port = int(port_text);
        if port > 65535 {
            raise CannotListen(reason="a port is a number from 0 to 65535");
        }
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM);
        try {
            s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1);
            s.bind((host, port));
            s.listen(128);
        } except OSError as e {
            s.close();
            said = e.strerror;
            raise CannotListen(reason=said if said is not None else str(e));
        }
        return Bound(sock=s);
    }

    """Serves `handle` at the address `claim` took. The loop takes
    connections and reads requests; each whole request is answered on a
    thread of its own (`answer_on`), at most MAX_CALLS at once. Nothing a
    client sends or does ends it: a request it won't read is refused with the
    status that says why, a connection that can't be taken is let be, at
    most MAX_CONNECTIONS are open with a request still to come, and each has
    REQUEST_SECONDS to send its request."""
    def listen(
        claim: Claim,
        handle: Callable[[Request], Response],
        ticks: list[Tick],
        listening: Callable[[int], None] | None,
    ) {
        s: any = (claim as Bound).sock;
        accepting: int = s.fileno();
        at = s.getsockname();
        bound: int = at[1];
        # Flushed: what starts the server reads it to learn the port (one the
        # system chose, for port 0). The address is the one the socket is
        # bound to: a host name's, as it resolved.
        print("listening on http://" + str(at[0]) + ":" + str(bound) + "/", flush=True);
        if listening is not None {
            listening(bound);
        }
        # (A pair of sockets, not a pipe: select watches only sockets on Windows.)
        ends = socket.socketpair();
        waker: any = ends[0];
        woken: int = waker.fileno();
        self.wake.append(waker);
        self.wake.append(ends[1]);
        sending: dict[int, Sending] = {};
        answering: list[Calls] = [];
        calls = Calls(
            answer=lambda (conn: any, req: Request, interim: bool) {
                answer_on(conn, req, interim, handle, sending, answering[0])
            },
        );
        answering.append(calls);
        now = time.time();
        for t in ticks {
            t.next_at = now;
        }
        socks: dict[int, any] = {};
        bufs: dict[int, bytes] = {};
        born: dict[int, float] = {};
        clients: dict[int, str] = {};
        # A refused request's connection, answered before all of it was read:
        # until when what more its client sends is read and let go, so the
        # client reads the answer rather than a reset (RFC 9112's closing).
        closing: dict[int, float] = {};

        """Forget connection `fd`, closing it unless a call has taken it."""
        def drop(fd: int, taken: bool = False) {
            if not taken {
                socks[fd].close();
            }
            del socks[fd];
            del bufs[fd];
            del born[fd];
            del clients[fd];
            if fd in closing {
                del closing[fd];
            }
        }

        while True {
            now = time.time();
            for t in ticks {
                if t.next_at <= now {
                    t.next_at = now + t.every;
                    try {
                        t.run();
                    } except Exception as e {
                        print(t.name + " failed: " + str(e));
                    }
                }
            }
            keep_alive(sending, now);
            calls.settle();
            while len(self.work) > 0 {
                work = self.work.pop(0);
                try {
                    work();
                } except Exception as e {
                    print("work on the loop failed: " + str(e));
                }
            }
            # A connection that says nothing costs nothing: only one with data is read.
            (ready, _, _) = select.select([accepting, woken] + list(socks.keys()), [], [], 0.5);
            for fd in ready {
                if fd == woken {
                    # (Work was asked for: done at the top of the next turn.)
                    waker.recv(4096);
                    continue;
                }
                if fd == accepting {
                    if len(socks) >= MAX_CONNECTIONS {
                        # The one open longest makes way.
                        drop(min(born.keys(), key=lambda (k: int) -> float { return born[k]; }));
                    }
                    try {
                        (conn, peer) = s.accept();
                        conn.settimeout(10.0);
                    } except OSError as e {
                        # Gone before it was taken, or no descriptor for it: one
                        # open longest makes way, and the loop goes on.
                        print("accept failed: " + str(e));
                        if len(socks) > 0 {
                            drop(
                                min(born.keys(), key=lambda (k: int) -> float { return born[k]; })
                            );
                        }
                        continue;
                    }
                    socks[conn.fileno()] = conn;
                    bufs[conn.fileno()] = b"";
                    born[conn.fileno()] = time.time();
                    clients[conn.fileno()] = str(peer[0]);
                    continue;
                }
                if fd not in socks {
                    # (Made way for another this turn.)
                    continue;
                }
                c = socks[fd];
                done = False;
                if fd in closing {
                    try {
                        done = len(c.recv(65536)) == 0;
                    } except OSError as e {
                        done = True;
                    }
                    if done {
                        drop(fd);
                    }
                    continue;
                }
                try {
                    chunk = c.recv(65536);
                    if len(chunk) == 0 {
                        done = True;
                    } else {
                        bufs[fd] = bufs[fd] + chunk;
                        if parse_request(bufs[fd]) is not None {
                            # The call's from here: its thread makes its own
                            # socket of the descriptor, and its own Request.
                            whole = bufs[fd];
                            drop(fd, taken=True);
                            calls.take(c.detach(), whole);
                        }
                    }
                } except Refused as no {
                    try {
                        write_response(
                            c,
                            Response(
                                status=no.status, ctype="text/plain", body=no.detail.encode("utf-8")
                            ),
                        );
                        c.shutdown(socket.SHUT_WR);
                        closing[fd] = time.time() + LINGER_SECONDS;
                    } except OSError as gone {
                        print("request refused, its client gone: " + str(gone));
                        done = True;
                    }
                } except Exception as e {
                    # The client went or stalled (an OSError): its connection goes.
                    print("request failed: " + str(e));
                    done = True;
                }
                if done {
                    drop(fd);
                }
            }
            now = time.time();
            for fd in list(socks.keys()) {
                if now - born[fd] > REQUEST_SECONDS or (fd in closing and now > closing[fd]) {
                    drop(fd);
                }
            }
        }
    }
}
