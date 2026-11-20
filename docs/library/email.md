---
description: The native email package and quopri - messages, their headers and MIME parts, the parsers and generators, the policies, addresses and dates - with what each module has and how a statically typed program reads a message.
keywords: email, email.message, email.message.EmailMessage, EmailMessage, email.message.Message, email.message_from_string, email.message_from_bytes, email.parser, email.generator, email.policy, email.header, email.headerregistry, email.utils, email.utils.parseaddr, email.utils.formataddr, email.utils.parsedate_to_datetime, email.mime, MIMEText, MIMEMultipart, email.charset, email.errors, quopri, quopri.encodestring, quopri.decodestring, MIME, quoted-printable
---
# email and quopri

The `email` package is native: all of CPython 3.15's, written in Jac, with CPython's behavior
(see [The library](index.md), `jac docs library`). A program builds a message, parses one
from text or bytes, and writes one back, under either of CPython's two models: `EmailMessage`
and the email policies, or `Message` and `compat32`.

```jac
import email;
import email.header;
import email.policy;
import email.utils;
import quopri;
import from email.message { EmailMessage }

with entry {
    msg = EmailMessage();
    msg["From"] = "Ada Lovelace <ada@example.org>";
    msg["To"] = "bo@example.org, Cy <cy@example.org>";
    msg["Subject"] = "Résumé";
    msg["Date"] = "Sat, 07 Nov 2026 12:30:00 +0000";
    msg.set_content("Attached.\n");
    msg.add_attachment(b"%PDF-1.7", maintype="application", subtype="pdf", filename="cv.pdf");
    print(msg.get_content_type(), msg.is_multipart(), len(list(msg.iter_parts())));
    back = email.message_from_bytes(msg.as_bytes(), policy=email.policy.default);
    print(back["Subject"], "|", back["To"].addresses[1].display_name);
    print(back["Date"].datetime.year);
    for part in back.walk() {
        print(part.get_content_type(), part.get_filename());
    }
    if isinstance(back, EmailMessage) {
        body = back.get_body();
        print(repr(body.get_content()), [p.get_filename() for p in back.iter_attachments()]);
    }
    old = email.message_from_string("Subject: =?utf-8?q?R=C3=A9sum=C3=A9?=\n\nbody\n");
    print(old["Subject"], email.header.decode_header(old["Subject"]), repr(old.get_payload()));
    print(email.utils.parseaddr("Ada Lovelace <ada@example.org>"));
    print(email.utils.formataddr(("Bo, Jr.", "bo@example.org")));
    print(email.utils.parsedate_to_datetime("Sat, 07 Nov 2026 12:30:00 +0000").isoformat());
    print(quopri.encodestring("Résumé = done".encode()), quopri.decodestring(b"R=C3=A9sum=C3=A9"));
}
```

```output
multipart/mixed True 2
Résumé | Cy
2026
multipart/mixed None
text/plain None
application/pdf cv.pdf
'Attached.\n' ['cv.pdf']
=?utf-8?q?R=C3=A9sum=C3=A9?= [(b'R\xc3\xa9sum\xc3\xa9', 'utf-8')] 'body\n'
('Ada Lovelace', 'ada@example.org')
"Bo, Jr." <bo@example.org>
2026-11-07T12:30:00+00:00
b'R=C3=A9sum=C3=A9 =3D done' b'R\xc3\xa9sum\xc3\xa9'
```

## What is there

| Module | What it has |
|---|---|
| `email` | `message_from_string`, `message_from_bytes`, `message_from_file`, `message_from_binary_file`, each taking `_class` and `policy=` |
| `email.message` | `Message` (the `compat32` model), `MIMEPart` and `EmailMessage`: headers by name, `get_all`, `add_header`, `replace_header`, `get_content_type`, `get_param`, `get_filename`, `get_payload`, `set_payload`, `attach`, `walk`, `as_string`, `as_bytes`; and `get_body`, `iter_parts`, `iter_attachments`, `get_content`, `set_content`, `add_attachment`, `add_related`, `add_alternative`, `make_mixed`, ... |
| `email.parser`, `email.feedparser` | `Parser`, `HeaderParser`, `BytesParser`, `BytesHeaderParser`; `FeedParser`, `BytesFeedParser`, fed a message piece by piece |
| `email.generator` | `Generator`, `BytesGenerator`, `DecodedGenerator` |
| `email.policy` | `EmailPolicy` and `default`, `strict`, `SMTP`, `SMTPUTF8`, `HTTP`; `Policy`, `Compat32`, `compat32`; `clone(...)` |
| `email.headerregistry` | `Address`, `Group`, `HeaderRegistry` and the header classes an email policy makes: an address header has `addresses`, a date header `datetime`, a MIME header `params` |
| `email.header` | `Header`, `decode_header`, `make_header` |
| `email.utils` | `parseaddr`, `getaddresses`, `formataddr`, `parsedate`, `parsedate_tz`, `parsedate_to_datetime`, `formatdate`, `format_datetime`, `localtime`, `mktime_tz`, `make_msgid`, `quote`, `unquote`, and the RFC 2231 functions |
| `email.mime.text`, `email.mime.multipart`, `email.mime.base`, `email.mime.application`, `email.mime.audio`, `email.mime.image`, `email.mime.message`, `email.mime.nonmultipart` | `MIMEText`, `MIMEMultipart` and the other classes that build a `compat32` message part by part |
| `email.contentmanager`, `email.charset`, `email.encoders`, `email.errors`, `email.iterators`, `email.base64mime`, `email.quoprimime` | The content manager of `get_content` and `set_content`; `Charset`; the transfer encoders; the exceptions and the defects a parser records; `body_line_iterator`, `typed_subpart_iterator`; the two encodings' functions |
| `quopri` | `encodestring(s, quotetabs=False, header=False)`, `decodestring(s, header=False)`, and `encode` and `decode` between binary files |

A parser records what is wrong with a message in its `defects` and goes on, as CPython's does;
under `email.policy.strict` it raises the defect instead.

```jac
import email;
import email.errors;
import email.header;
import email.policy;
import from email.mime.multipart { MIMEMultipart }
import from email.mime.text { MIMEText }

with entry {
    m = MIMEMultipart("alternative");
    m["Subject"] = email.header.Header("Résumé", "utf-8");
    m.attach(MIMEText("plain\n", "plain"));
    m.attach(MIMEText("<p>html</p>\n", "html"));
    print(m["Subject"].encode(), [p.get_content_subtype() for p in m.get_payload()]);
    bad = email.message_from_string("X: 1\nnot a header\n\nb", policy=email.policy.default);
    print([type(d).__name__ for d in bad.defects], bad["X"]);
    try {
        email.message_from_string("X: 1\nnot a header\n\nb", policy=email.policy.strict);
    } except email.errors.MessageDefect as e {
        print("raised", type(e).__name__);
    }
}
```

```output
=?utf-8?b?UsOpc3Vtw6k=?= ['plain', 'html']
['MissingHeaderBodySeparatorDefect'] 1
raised MissingHeaderBodySeparatorDefect
```

## Differences from CPython

- **A header is read as an `any`.** What `msg["To"]` gives depends on the message's policy, a
  value and not a type: a `str` or a `Header` under `compat32`, a header object under an email
  policy. So its attributes (`.addresses`, `.datetime`) are looked up as the program runs, and
  one it lacks raises `AttributeError` there.
- **A parsed message is typed `Message`.** `message_from_string` and its siblings, and the
  parsers, return a `Message`, whatever the policy; under an email policy the object is an
  `EmailMessage`. Narrow it with `isinstance(m, EmailMessage)` before calling `get_body`,
  `get_content` or `iter_attachments`, as above, or declare it `any`. The parts `walk`,
  `iter_parts` and `iter_attachments` give are typed `Message` too.
- **A header object is not a `str`.** An email policy's header (`msg["Subject"]`) holds its text,
  compares, hashes and prints as it, and has `str`'s methods (`h.lower()`), but
  `isinstance(h, str)` is `False`, and it does not fit a parameter typed `str`: pass `str(h)`.
  Its class is named for its kind (`UniqueAddressHeader`), not made as the program runs.
- **`email.header.make_header(decode_header(h))` does not compile yet** (E1053): the two
  functions name their pairs' types differently. Decode the pairs `decode_header` gives.
- **`email.utils.localtime`, `formatdate` and `make_msgid` read the clock**, and `make_msgid`
  the host's name, as CPython's do.

## Where to go next

- Sending a message and reading a mailbox: [smtplib, poplib and imaplib](mailclients.md).
- Text encodings of bytes: [base64 and binascii](base64.md), [codecs](codecs.md).
- Dates and time zones: [datetime](datetime.md).
- Every native module: [Standard-library modules](stdlib.md).
