"""Native HTTP probes compared with prim_urllib_host.jac over one loopback server."""

import os;
import from urllib.request { urlopen }

def urlopen_status_na -> int {
    base = "http://127.0.0.1:" + os.getenv("JAC_URLLIB_TEST_PORT", "");
    resp = urlopen(base + "/hello");
    return resp.status;
}

def urlopen_body_length_na -> int {
    base = "http://127.0.0.1:" + os.getenv("JAC_URLLIB_TEST_PORT", "");
    resp = urlopen(base + "/hello");
    return resp.body_length;
}

def urlopen_redirect_status_na -> int {
    base = "http://127.0.0.1:" + os.getenv("JAC_URLLIB_TEST_PORT", "");
    resp = urlopen(base + "/redirect");
    return resp.status;
}

def urlopen_redirect_body_length_na -> int {
    base = "http://127.0.0.1:" + os.getenv("JAC_URLLIB_TEST_PORT", "");
    resp = urlopen(base + "/redirect");
    return resp.body_length;
}
