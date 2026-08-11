import from urllib.parse { parse_qs }
import from jaclang.runtimelib.serving.datatypes { HTTPError, Request, UploadFile }


glob MAX_PARTS: int = 1000;


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

def parse_multipart(request: Request) {
    content_type = request.headers.get('Content-Type') or '';
    boundary = _content_type_param(content_type, 'boundary');
    if not boundary {
        raise HTTPError(status_code=400, detail='Missing multipart boundary');
    }
    delim = b'--' + boundary.encode('latin-1');
    body = request.body;
    if not body.startswith(delim) {
        start = body.find(b'\r\n' + delim);
        if start < 0 {
            raise HTTPError(status_code=400, detail='Malformed multipart body');
        }
        body = body[start + 2:];
    }
    sections = body.split(b'\r\n' + delim);
    first = sections[0];
    if first.startswith(delim) {
        sections[0] = first[len(delim):];
    }
    count = 0;
    for section in sections {
        part = section;
        if part in (b'', b'--', b'--\r\n', b'\r\n') {
            continue;
        }
        if part.startswith(b'--') {
            break;
        }
        if part.startswith(b'\r\n') {
            part = part[2:];
        }
        count += 1;
        if count > MAX_PARTS {
            raise HTTPError(status_code=413, detail='Too many multipart parts');
        }
        (header_blob, sep, content) = part.partition(b'\r\n\r\n');
        if not sep {
            continue;
        }
        headers = _parse_part_headers(header_blob);
        disposition = headers.get('content-disposition', '');
        name = _content_type_param(disposition, 'name');
        if not name {
            continue;
        }
        filename = _content_type_param(disposition, 'filename');
        if filename is not None {
            upload = UploadFile(
                filename=filename,
                content_type=headers.get('content-type', 'application/octet-stream'),
                body=content
            );
            request.upload_files.setdefault(name, []).append(upload);
        } else {
            request.form_fields.setdefault(name, []).append(
                content.decode('utf-8', errors='replace')
            );
        }
    }
}

def parse_urlencoded_form(request: Request) {
    decoded = request.body.decode('utf-8', errors='replace');
    for (key, values) in parse_qs(decoded, keep_blank_values=True).items() {
        request.form_fields.setdefault(key, []).extend(values);
    }
}
