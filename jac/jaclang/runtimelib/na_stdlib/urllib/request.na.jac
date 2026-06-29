import os;

import from curl {
    def curl_easy_init -> int;  def curl_easy_setopt(
        handle: int, option: int, *rest: int
    ) -> int;  def curl_easy_perform(handle: int) -> int;  def curl_easy_cleanup(
        handle: int
    ) -> None;
}

import from c {
    def fopen(path: str, mode: str) -> int;  def fclose(stream: int) -> int;  def remove(
        path: str
    ) -> int;
}

glob _CURLOPT_WRITEDATA: int = 10001,
     _CURLOPT_URL: int = 10002,
     _CURLOPT_FOLLOWLOCATION: int = 52,
     _CURLOPT_HEADERDATA: int = 10029;

glob _CURLE_OK: int = 0;


obj:pub HTTPResponse {
    has status: int,
        body_length: int,
        reason: str,
        url: str,
        body: bytes,
        header_names: list[str],
        header_values: list[str];
}


def _tmpdir -> str {
    d = os.getenv("TMPDIR");
    if len(d) == 0 {
        return "/tmp";
    }
    while len(d) > 1 and d[len(d) - 1] == "/" {
        d = d[:len(d) - 1];
    }
    return d;
}


def:pub urlopen(url: str) -> HTTPResponse {
    h = curl_easy_init();
    if h == 0 {
        raise Exception("urlopen: curl_easy_init failed");
    }

    stem = _tmpdir() + "/jac_urlopen_" + str(h);
    body_path = stem + ".body";
    hdr_path = stem + ".hdr";
    body_fp = fopen(body_path, "wb");
    hdr_fp = fopen(hdr_path, "wb");

    if body_fp is None or hdr_fp is None {
        if body_fp is not None {
            fclose(body_fp);
        }
        if hdr_fp is not None {
            fclose(hdr_fp);
        }
        curl_easy_cleanup(h);
        remove(body_path);
        remove(hdr_path);
        raise Exception("urlopen: cannot open temp file under " + _tmpdir());
    }

    curl_easy_setopt(h, _CURLOPT_URL, url);
    curl_easy_setopt(h, _CURLOPT_WRITEDATA, body_fp);
    curl_easy_setopt(h, _CURLOPT_HEADERDATA, hdr_fp);
    curl_easy_setopt(h, _CURLOPT_FOLLOWLOCATION, 1);

    rc = curl_easy_perform(h);

    fclose(body_fp);
    fclose(hdr_fp);
    curl_easy_cleanup(h);

    if rc != _CURLE_OK {
        remove(body_path);
        remove(hdr_path);
        raise Exception("urlopen: transport error (curl code " + str(rc) + ")");
    }

    hf = open(hdr_path, "r");
    hdr_text = hf.read();
    hf.close();
    bf = open(body_path, "rb");
    body = bf.read();
    bf.close();
    remove(body_path);
    remove(hdr_path);

    lines = hdr_text.split("\n");
    start: int = 0;
    scan: int = 0;
    for raw in lines {
        if raw.rstrip("\r").startswith("HTTP/") {
            start = scan;
        }
        scan += 1;
    }
    status: int = 0;
    reason: str = "";
    status_line = lines[start].rstrip("\r");
    sp1 = status_line.find(" ");
    if sp1 != -1 {
        after = status_line[sp1 + 1:];
        sp2 = after.find(" ");
        if sp2 == -1 {
            status = int(after);
        } else {
            status = int(after[:sp2]);
            reason = after[sp2 + 1:];
        }
    }
    names: list[str] = [];
    values: list[str] = [];
    j: int = start + 1;
    while j < len(lines) {
        line = lines[j].rstrip("\r");
        if len(line) == 0 {
            j += 1;
            continue;
        }
        colon = line.find(":");
        if colon != -1 {
            names.append(line[:colon].strip().lower());
            values.append(line[colon + 1:].strip());
        }
        j += 1;
    }

    return HTTPResponse(
        status=status,
        body_length=len(body),
        reason=reason,
        url=url,
        body=body,
        header_names=names,
        header_values=values
    );
}
