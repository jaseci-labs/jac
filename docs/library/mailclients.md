---
description: The native mail and file transfer clients - smtplib, poplib, imaplib and ftplib - what each has, how a command's reply comes back, the TLS forms, and how they differ from CPython's.
keywords: smtplib, smtplib.SMTP, smtplib.SMTP_SSL, smtplib.LMTP, smtplib.SMTPException, sendmail, send_message, poplib, poplib.POP3, poplib.POP3_SSL, poplib.error_proto, imaplib, imaplib.IMAP4, imaplib.IMAP4_SSL, imaplib.IMAP4_stream, imaplib.error, ftplib, ftplib.FTP, ftplib.FTP_TLS, ftplib.error_perm, ftplib.error_temp, retrbinary, storbinary, SMTP, POP3, IMAP, FTP, mail clients
---
# smtplib, poplib, imaplib and ftplib

Four native modules are clients of the mail protocols and of FTP, each with the names and
behavior of CPython 3.15's module of the same name (see [The library](index.md),
`jac docs library`):

| Module | What it has |
|---|---|
| `smtplib` | `SMTP`, `SMTP_SSL` and `LMTP`: sending mail, with ESMTP, authentication and STARTTLS |
| `poplib` | `POP3` and `POP3_SSL`: reading a mailbox, message by message |
| `imaplib` | `IMAP4`, `IMAP4_SSL` and `IMAP4_stream`: mailboxes on a server, their messages, searches and flags |
| `ftplib` | `FTP` and `FTP_TLS`: listing, fetching and storing files |

They are written over [socket and ssl](socket.md), and `smtplib` sends what the
[email](email.md) package builds. Each client connects as it is made, or with `connect`, and
each command is a method that sends a line and returns the server's reply; a reply that
refuses raises the module's exception.

Each has its TLS form: a class that speaks TLS from the start (`SMTP_SSL`, `POP3_SSL`,
`IMAP4_SSL`) and a command that turns it on (`starttls`, `stls`, `FTP_TLS`'s `auth`). As in
CPython, a client given no [ssl](socket.md#ssl) context does not check the server's
certificate: pass `context=ssl.create_default_context()` (`ssl_context=` to `imaplib`) to
verify it against the system's CA certificates.

The example below is its own server, so that it needs no network: a thread that answers each
command from a table ([threading](threading.md)).

```jac
import ftplib;
import imaplib;
import poplib;
import smtplib;
import socket;
import threading;
import from email.message { EmailMessage }

glob HOST: str = "127.0.0.1";

"""A server for one connection: it sends `greeting`, then answers each line
it reads with the reply `replies` has for the line's command, which is its
first word, or its second after an IMAP tag (the tag takes the place of
`%T` in the reply)."""
def serve(
    listener: socket.socket, greeting: bytes, replies: dict[bytes, bytes], seen: list[str]
) -> None {
    (conn, _peer) = listener.accept();
    conn.sendall(greeting);
    with conn.makefile("rb") as lines {
        for line in lines {
            words = line.split();
            for word in words[:2] {
                if word.upper() in replies {
                    seen.append(word.upper().decode());
                    conn.sendall(replies[word.upper()].replace(b"%T", words[0]));
                    break;
                }
            }
        }
    }
    conn.close();
    listener.close();
}

"""Start such a server on a port of this machine: the port, the thread and
the commands it will have seen."""
def start(greeting: bytes, replies: dict[bytes, bytes]) -> tuple[int, threading.Thread, list[str]] {
    listener = socket.create_server((HOST, 0));
    port: int = listener.getsockname()[1];
    seen: list[str] = [];
    t = threading.Thread(target=serve, args=(listener, greeting, replies, seen));
    t.start();
    return (port, t, seen);
}

with entry {
    msg = EmailMessage();
    msg["From"] = "ada@example.org";
    msg["To"] = "bo@example.org";
    msg["Subject"] = "Lunch";
    msg.set_content("Noon?\n");
    (port, t, seen) = start(
        b"220 mail.example.org ESMTP\r\n",
        {
            b"EHLO": b"250-mail.example.org\r\n250 SIZE 1000000\r\n",
            b"MAIL": b"250 sender ok\r\n",
            b"RCPT": b"250 recipient ok\r\n",
            b"DATA": b"354 end with a dot\r\n",
            b".": b"250 queued\r\n",
            b"NOOP": b"250 ok\r\n",
            b"QUIT": b"221 bye\r\n",
        },
    );
    with smtplib.SMTP(HOST, port, local_hostname="client.example.org", timeout=5.0) as smtp {
        print(smtp.send_message(msg), smtp.has_extn("size"), smtp.esmtp_features, smtp.noop());
    }
    t.join();
    print(seen);
    (port, t, seen) = start(
        b"+OK POP3 ready\r\n",
        {
            b"USER": b"+OK\r\n",
            b"PASS": b"+OK logged in\r\n",
            b"STAT": b"+OK 2 320\r\n",
            b"RETR": b"+OK 27 octets\r\nSubject: Lunch\r\n\r\nNoon?\r\n.\r\n",
            b"QUIT": b"+OK bye\r\n",
        },
    );
    pop = poplib.POP3(HOST, port, timeout=5.0);
    print(pop.getwelcome(), pop.user("ada"), pop.pass_("secret"), pop.stat());
    print(pop.retr(1), pop.quit());
    t.join();
    (port, t, seen) = start(
        b"* OK [CAPABILITY IMAP4rev1] IMAP ready\r\n",
        {
            b"LOGIN": b"* CAPABILITY IMAP4rev1\r\n%T OK LOGIN completed\r\n",
            b"SELECT": b"* 3 EXISTS\r\n%T OK [READ-WRITE] SELECT completed\r\n",
            b"SEARCH": b"* SEARCH 2 3\r\n%T OK SEARCH completed\r\n",
            b"LOGOUT": b"* BYE logging out\r\n%T OK LOGOUT completed\r\n",
        },
    );
    imap = imaplib.IMAP4(HOST, port, timeout=5.0);
    print(imap.login("ada", "secret"), imap.state);
    try {
        imap.search(None, "UNSEEN");
    } except imaplib.error as e {
        print("imaplib.error:", e);
    }
    print(imap.select(), imap.search(None, "UNSEEN"), imap.logout());
    t.join();
    (port, t, seen) = start(
        b"220 FTP ready\r\n",
        {
            b"USER": b"331 password, please\r\n",
            b"PASS": b"230 logged in\r\n",
            b"PWD": b'257 "/home/ada" is the current directory\r\n',
            b"SIZE": b"213 1024\r\n",
            b"CWD": b"550 no such directory\r\n",
            b"QUIT": b"221 bye\r\n",
        },
    );
    ftp = ftplib.FTP(timeout=5.0);
    print(ftp.connect(HOST, port), ftp.login("ada", "secret"), ftp.pwd(), ftp.size("notes.txt"));
    try {
        ftp.cwd("/missing");
    } except ftplib.error_perm as e {
        print("error_perm:", e);
    }
    print(ftp.quit(), ftplib.parse227("227 Entering Passive Mode (10,0,0,7,19,137)"));
    t.join();
}
```

```output
{} True {'size': '1000000'} (250, b'ok')
['EHLO', 'MAIL', 'RCPT', 'DATA', '.', 'NOOP', 'QUIT']
b'+OK POP3 ready' b'+OK' b'+OK logged in' (2, 320)
(b'+OK 27 octets', [b'Subject: Lunch', b'', b'Noon?'], 25) b'+OK bye'
('OK', [b'LOGIN completed']) AUTH
imaplib.error: command SEARCH illegal in state AUTH, only allowed in states SELECTED
('OK', [b'3']) ('OK', [b'2 3']) ('BYE', [b'logging out'])
220 FTP ready 230 logged in /home/ada 1024
error_perm: 550 no such directory
221 bye ('10.0.0.7', 5001)
```

## smtplib

`SMTP(host="", port=0, local_hostname=None, timeout=..., source_address=None)` connects when
it is given a host and reads the greeting; `SMTP_SSL(host, port, ..., context=None)` is the same
over TLS from the start, and `LMTP` the local delivery protocol, over TCP or, on Linux and
macOS, a Unix socket. A reply is `(code, text)`, the text `bytes`.

| Name | What it is |
|---|---|
| `sendmail(from_addr, to_addrs, msg, mail_options=(), rcpt_options=())` | A whole transaction: `EHLO` if none was sent, `MAIL`, a `RCPT` for each recipient, `DATA`. `msg` is `bytes`, or a `str` sent as ASCII with its line ends made CRLF. It returns the recipients refused, each with its reply, and raises `SMTPRecipientsRefused` when all were |
| `send_message(msg, from_addr=None, to_addrs=None, ...)` | The same for an `email.message.Message`, the sender and the recipients read from its headers; `Bcc` is not sent |
| `login(user, password, *, initial_response_ok=True)`, `auth(mechanism, authobject)` | Authentication by the first of `CRAM-MD5`, `PLAIN` and `LOGIN` the server has, or by a mechanism of the program's own |
| `starttls(*, context=None)` | The rest of the session over TLS |
| `helo`, `ehlo`, `has_extn`, `esmtp_features`, `mail`, `rcpt`, `data`, `rset`, `noop`, `verify`, `expn`, `help`, `docmd`, `quit`, `close`, `set_debuglevel`, `with` | The commands one at a time, and the session |
| `SMTPException` and `SMTPServerDisconnected`, `SMTPResponseException` (`smtp_code`, `smtp_error`), `SMTPSenderRefused`, `SMTPRecipientsRefused`, `SMTPDataError`, `SMTPConnectError`, `SMTPHeloError`, `SMTPAuthenticationError`, `SMTPNotSupportedError` | The exceptions, each an `OSError` |
| `quoteaddr`, `quotedata`, `SMTP_PORT`, `SMTP_SSL_PORT`, `LMTP_PORT` | As CPython's |

## poplib

`POP3(host, port=110, timeout=...)` connects and reads the greeting, and
`POP3_SSL(host, port=995, *, timeout=..., context=None)` does so over TLS. A short reply is
its status line, as `bytes`; a long one is `(status, lines, octets)`. A reply that does not
start with `+` raises `error_proto`.

`user`, `pass_`, `apop` and `rpop` log in; `stat()` gives `(messages, octets)`; `list`, `uidl`,
`retr(which)`, `top(which, howmuch)` and `dele(which)` read and mark messages; `capa()` gives
the server's capabilities as a dict, `utf8()` and `stls(context=None)` turn on UTF-8 and TLS,
and `noop`, `rset`, `quit` and `close` are the session's.

## imaplib

`IMAP4(host="", port=143, timeout=None)` connects and reads the greeting;
`IMAP4_SSL(host="", port=993, *, ssl_context=None, timeout=None)` does so over TLS, and
`IMAP4_stream(command)` talks to the standard input and output of a command. Every IMAP
command is a method of its name in lower case, which returns `(type, data)`: the type is
`"OK"` or `"NO"` (`"BYE"` for `logout`), and the data a list of `bytes`, or of
`(header, literal)` pairs for a reply with a literal.

| Name | What it is |
|---|---|
| `login`, `login_cram_md5`, `authenticate(mechanism, authobject)`, `starttls(ssl_context=None)`, `logout`, `capability`, `enable`, `noop` | The session; `state` is `NONAUTH`, `AUTH`, `SELECTED` or `LOGOUT`, and a command the state does not allow raises `error` |
| `select(mailbox="INBOX", readonly=False)`, `unselect`, `close`, `list`, `lsub`, `status`, `create`, `delete`, `rename`, `subscribe`, `unsubscribe`, `namespace` | Mailboxes |
| `search(charset, *criteria)`, `fetch(message_set, message_parts)`, `store(message_set, command, flags)`, `copy`, `append`, `expunge`, `sort`, `thread`, `uid(command, *args)`, `check`, `partial` | Messages |
| `getacl`, `setacl`, `deleteacl`, `myrights`, `getquota`, `getquotaroot`, `setquota`, `getannotation`, `setannotation`, `proxyauth`, `xatom` | The ACL, QUOTA and ANNOTATION extensions, and any other command |
| `idle(duration=None)` | An `Idler`, a `with` block in which the server's news is iterated as it comes; `burst(interval=0.1)` gives what has come together |
| `response(code)`, `recent`, `socket`, `shutdown`, `print_log`, `with` | The untagged replies kept, and the connection |
| `error`, `abort`, `readonly` | A mistake of the program's; a failure of the server or the connection, a kind of `error`; a mailbox become read-only, a kind of `abort` |
| `Internaldate2tuple`, `Time2Internaldate`, `ParseFlags`, `Int2AP`, `Commands`, `IMAP4_PORT`, `IMAP4_SSL_PORT` | As CPython's |

## ftplib

`FTP(host="", user="", passwd="", acct="", timeout=..., source_address=None, *, encoding="utf-8")`
connects when it is given a host and logs in when it is given a user;
`FTP_TLS(..., context=None)` secures the control connection before it logs in, and the data
connections after `prot_p()`. A reply is a `str` that starts with its three-digit code. A 4xx
reply raises `error_temp`, a 5xx one `error_perm`, and one that is no reply `error_proto`, each
an `Error`.

| Name | What it is |
|---|---|
| `connect(host="", port=0, timeout=..., source_address=None)`, `login(user="", passwd="", acct="")`, `getwelcome`, `quit`, `close`, `set_pasv(val)`, `set_debuglevel`, `with` | The session. Transfers are passive unless `set_pasv(False)` |
| `retrbinary(cmd, callback, blocksize=8192, rest=None)`, `retrlines(cmd, callback=None)` | Fetch a file (`"RETR name"`) or a listing, each block or line given to `callback` |
| `storbinary(cmd, fp, blocksize=8192, callback=None, rest=None)`, `storlines(cmd, fp, callback=None)` | Store a binary file's blocks, or its lines (`"STOR name"`) |
| `nlst(*args)`, `dir(*args)`, `mlsd(path="", facts=[])` | A directory's names, its listing, and its entries with their facts |
| `cwd`, `pwd`, `mkd`, `rmd`, `rename`, `delete`, `size`, `sendcmd`, `voidcmd`, `abort`, `transfercmd`, `ntransfercmd` | Directories and files, any other command, and a data connection of the program's own |
| `auth`, `prot_p`, `prot_c`, `ccc` | `FTP_TLS`'s: TLS on the control connection, on the data connections, and off again |
| `parse150`, `parse227`, `parse229`, `parse257`, `ftpcp`, `FTP_PORT` | As CPython's |

## Differences from CPython

- **`imaplib`'s exceptions are classes of the module**: `imaplib.error`, `imaplib.abort` and
  `imaplib.readonly`. CPython's are members of the class (`imaplib.IMAP4.error`), which a Jac
  class cannot hold yet (E1030): a program moved from Python writes `except imaplib.error`.
- **An IMAP command is called by its lower-case name.** CPython also answers the upper-case
  one (`M.SELECT()`), through `__getattr__`; here it is E1030.
- **`ftplib.all_errors` is not there** (E1145): it is a tuple of exception classes. Catch
  `ftplib.Error`, `OSError` and `EOFError`.
- **`imaplib.IMAP4_stream` is for Linux and macOS.** A program that names it does not compile
  for Windows.
- **`IMAP4.mustquote`, `IMAP4_SSL.sslobj` and `IMAP4_SSL.ssl` are left out**: CPython's classes
  have no such members either. `IMAP4_SSL.socket()` gives the `ssl.SSLSocket`.

```jac
# expect: E1145
import ftplib;

with entry {
    print(ftplib.all_errors);
}
```

## Where to go next

- Building and parsing the messages: [email](email.md).
- Sockets and TLS contexts: [socket, socketserver and ssl](socket.md).
- `ftp:` URLs opened in one call: [urllib](urllib.md).
- Log records sent as mail, by `logging.handlers.SMTPHandler` over `smtplib`:
  [logging](logging.md).
- Every native module: [Standard-library modules](stdlib.md).
