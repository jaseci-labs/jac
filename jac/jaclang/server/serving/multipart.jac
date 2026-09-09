import io;
import tempfile;
import from urllib.parse { parse_qs }
import from jaclang.server.serving.datatypes { HTTPError, Request, UploadFile }


glob MAX_PARTS: int = 1000,
     MAX_PART_HEADER_BYTES: int = 16384,
     MAX_FIELD_BYTES: int = 1048576,
     CHUNK_BYTES: int = 65536,
     DEFAULT_SPOOL_BYTES: int = 1048576;


def _content_type_param(header_value: str, param: str) -> (str | None) {
    for chunk in header_value.split(';') {
        piece = chunk.strip();
        if piece.lower().startswith(f"{param}=") {
            value = piece[len(param) + 1:].strip();
            if len(value) >= 2 and value[0] == '"' and value[-1] == '"' {
                value = value[1:-1];
            }
            return value;
        }
    }
    return None;
}

def _parse_part_headers(raw: bytes) -> dict[str, str] {
    headers: dict[str, str] = {};
    for line in raw.split(b'\r\n') {
        if b':' not in line {
            continue;
        }
        (name, _, value) = line.partition(b':');
        headers[name.decode('latin-1').strip().lower()] = value.decode(
            'latin-1'
        ).strip();
    }
    return headers;
}


obj _PartReader {
    has source: any,
        delim: bytes,
        buf: bytes = b'',
        eof: bool = False,
        finished: bool = False;

    def _fill -> bool {
        if self.eof {
            return False;
        }
        chunk = self.source.read(CHUNK_BYTES);
        if not chunk {
            self.eof = True;
            return False;
        }
        self.buf += chunk;
        return True;
    }

    def _consume_delimiter_tail {
        while len(self.buf) < 2 and self._fill() {}
        if self.buf.startswith(b'--') {
            self.finished = True;
            self.buf = b'';
            return;
        }
        if self.buf.startswith(b'\r\n') {
            self.buf = self.buf[2:];
            return;
        }
        if self.buf.startswith(b'\n') {
            self.buf = self.buf[1:];
            return;
        }
        raise HTTPError(status_code=400, detail='Malformed multipart body');
    }

    def skip_preamble {
        first = self.delim;
        while True {
            idx = self.buf.find(first);
            if idx >= 0 {
                self.buf = self.buf[idx + len(first):];
                self._consume_delimiter_tail();
                return;
            }
            keep = len(first) - 1;
            if len(self.buf) > keep {
                self.buf = self.buf[-keep:];
            }
            if not self._fill() {
                raise HTTPError(status_code=400, detail='Malformed multipart body');
            }
        }
    }

    def read_part_headers -> dict[str, str] {
        while True {
            idx = self.buf.find(b'\r\n\r\n');
            if idx >= 0 {
                raw = self.buf[:idx];
                self.buf = self.buf[idx + 4:];
                return _parse_part_headers(raw);
            }
            if len(self.buf) > MAX_PART_HEADER_BYTES {
                raise HTTPError(
                    status_code=431, detail='Multipart part headers too large'
                );
            }
            if not self._fill() {
                raise HTTPError(status_code=400, detail='Malformed multipart body');
            }
        }
    }

    def copy_part_body(sink: any, cap: int = 0) -> int {
        marker = b'\r\n' + self.delim;
        written = 0;
        while True {
            idx = self.buf.find(marker);
            if idx >= 0 {
                piece = self.buf[:idx];
                if cap and written + len(piece) > cap {
                    raise HTTPError(
                        status_code=413, detail='Multipart field too large'
                    );
                }
                sink.write(piece);
                written += len(piece);
                self.buf = self.buf[idx + len(marker):];
                self._consume_delimiter_tail();
                return written;
            }
            keep = len(marker) - 1;
            if len(self.buf) > keep {
                piece = self.buf[:-keep];
                if cap and written + len(piece) > cap {
                    raise HTTPError(
                        status_code=413, detail='Multipart field too large'
                    );
                }
                sink.write(piece);
                written += len(piece);
                self.buf = self.buf[-keep:];
            }
            if not self._fill() {
                raise HTTPError(status_code=400, detail='Malformed multipart body');
            }
        }
    }
}


def parse_multipart(request: Request, spool_bytes: int = DEFAULT_SPOOL_BYTES) {
    content_type = request.headers.get('Content-Type') or '';
    boundary = _content_type_param(content_type, 'boundary');
    if not boundary {
        raise HTTPError(status_code=400, detail='Missing multipart boundary');
    }
    source: any = request.body_file;
    if source is None {
        source = io.BytesIO(request.body);
    }
    source.seek(0);
    reader = _PartReader(source=source, delim=b'--' + boundary.encode('latin-1'));
    reader.skip_preamble();
    count = 0;
    while not reader.finished {
        count += 1;
        if count > MAX_PARTS {
            raise HTTPError(status_code=413, detail='Too many multipart parts');
        }
        headers = reader.read_part_headers();
        disposition = headers.get('content-disposition', '');
        name = _content_type_param(disposition, 'name');
        filename = _content_type_param(disposition, 'filename');
        if filename is not None {
            spool = tempfile.SpooledTemporaryFile(max_size=max(0, spool_bytes));
            size = reader.copy_part_body(spool);
            spool.seek(0);
            if name {
                request.upload_files.setdefault(name, []).append(
                    UploadFile(
                        filename=filename,
                        content_type=headers.get(
                            'content-type', 'application/octet-stream'
                        ),
                        _file=spool,
                        _size=size
                    )
                );
            } else {
                spool.close();
            }
        } else {
            field = io.BytesIO();
            reader.copy_part_body(field, cap=MAX_FIELD_BYTES);
            if name {
                request.form_fields.setdefault(name, []).append(
                    field.getvalue().decode('utf-8', errors='replace')
                );
            }
        }
    }
}

def parse_urlencoded_form(request: Request) {
    decoded = request.body.decode('utf-8', errors='replace');
    for (key, values) in parse_qs(decoded, keep_blank_values=True).items() {
        request.form_fields.setdefault(key, []).extend(values);
    }
}
