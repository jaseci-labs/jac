impl __utf8Bytes(text: str) -> list[int] {
    s: any = text;
    out: list[int] = [];
    i = 0;
    while i < len(text) {
        code: int = s.codePointAt(i);
        if code < 0x80 {
            out.append(code);
        } elif code < 0x800 {
            out.append(0xC0 | (code >> 6));
            out.append(0x80 | (code & 0x3F));
        } elif code < 0x10000 {
            out.append(0xE0 | (code >> 12));
            out.append(0x80 | ((code >> 6) & 0x3F));
            out.append(0x80 | (code & 0x3F));
        } else {
            out.append(0xF0 | (code >> 18));
            out.append(0x80 | ((code >> 12) & 0x3F));
            out.append(0x80 | ((code >> 6) & 0x3F));
            out.append(0x80 | (code & 0x3F));
        }
        i += 2 if code >= 0x10000 else 1;
    }
    return out;
}

impl __shr32(x: int, n: int) -> int {
    return (x >> n) & ((1 << (32 - n)) - 1);
}

impl __rotr32(x: int, n: int) -> int {
    return __shr32(x, n) | (x << (32 - n));
}

impl __hex32(x: int) -> str {
    word: any = x + 4294967296 if x < 0 else x;
    return word.toString(16).padStart(8, "0");
}

impl __sha256Hex(text: str) -> str {
    msg = __utf8Bytes(text);
    bit_len = len(msg) * 8;
    msg.append(0x80);
    while len(msg) % 64 != 56 {
        msg.append(0);
    }
    high: any = Math.floor(bit_len / 4294967296);
    for shift in [24, 16, 8, 0] {
        msg.append((high >> shift) & 0xFF);
    }
    for shift in [24, 16, 8, 0] {
        msg.append((bit_len >> shift) & 0xFF);
    }
    h: list[int] = [
        0x6a09e667 | 0,
        0xbb67ae85 | 0,
        0x3c6ef372 | 0,
        0xa54ff53a | 0,
        0x510e527f | 0,
        0x9b05688c | 0,
        0x1f83d9ab | 0,
        0x5be0cd19 | 0
    ];
    off = 0;
    while off < len(msg) {
        w: list[int] = [];
        i = 0;
        while i < 16 {
            j = off + i * 4;
            w.append(
                (msg[j] << 24) | (msg[j + 1] << 16) | (msg[j + 2] << 8) | msg[j + 3]
            );
            i += 1;
        }
        while i < 64 {
            x = w[i - 15];
            y = w[i - 2];
            s0 = __rotr32(x, 7) ^ __rotr32(x, 18) ^ __shr32(x, 3);
            s1 = __rotr32(y, 17) ^ __rotr32(y, 19) ^ __shr32(y, 10);
            w.append((w[i - 16] + s0 + w[i - 7] + s1) | 0);
            i += 1;
        }
        a = h[0];
        b = h[1];
        c = h[2];
        d = h[3];
        e = h[4];
        f = h[5];
        g = h[6];
        k = h[7];
        i = 0;
        while i < 64 {
            big1 = __rotr32(e, 6) ^ __rotr32(e, 11) ^ __rotr32(e, 25);
            choose = (e & f) ^ ((e ^ -1) & g);
            t1 = (k + big1 + choose + __SHA256_K[i] + w[i]) | 0;
            big0 = __rotr32(a, 2) ^ __rotr32(a, 13) ^ __rotr32(a, 22);
            majority = (a & b) ^ (a & c) ^ (b & c);
            t2 = (big0 + majority) | 0;
            k = g;
            g = f;
            f = e;
            e = (d + t1) | 0;
            d = c;
            c = b;
            b = a;
            a = (t1 + t2) | 0;
            i += 1;
        }
        h[0] = (h[0] + a) | 0;
        h[1] = (h[1] + b) | 0;
        h[2] = (h[2] + c) | 0;
        h[3] = (h[3] + d) | 0;
        h[4] = (h[4] + e) | 0;
        h[5] = (h[5] + f) | 0;
        h[6] = (h[6] + g) | 0;
        h[7] = (h[7] + k) | 0;
        off += 64;
    }
    hex = "";
    for word in h {
        hex += __hex32(word);
    }
    return hex;
}

impl __solveRegistrationChallenge(base_url: str) -> dict[str, any] {
    unavailable = "Verification is unavailable. Please try again.";
    try {
        response = await fetch(
            f"{base_url}/user/register/challenge", {"method": "POST"}
        );
    } except Exception {
        return {"error": unavailable, "status": 0};
    }
    status = int(response.status);
    payload: any = None;
    try {
        payload = JSON.parse(await response.text());
    } except Exception {
        payload = None;
    }
    if not response.ok {
        problem: any = payload.error if payload else None;
        message: any = problem.message if problem else None;
        return {"error": str(message) if message else unavailable, "status": status};
    }
    data: any = payload.data if payload else None;
    if not data {
        return {"error": unavailable, "status": status};
    }
    if not data.required {
        return {"challenge": None};
    }
    challenge: any = data.challenge;
    if not challenge
        or not challenge.token
        or not challenge.salt
        or not challenge.target
        or not Number.isInteger(challenge.max_number) {
        return {
            "error": "The server sent an invalid verification challenge.",
            "status": status
        };
    }
    deadline = Date.now() + Number(challenge.expires_in or 0) * 1000;
    number = 0;
    while number <= challenge.max_number {
        if __sha256Hex(challenge.salt + str(number)) == challenge.target {
            return {"challenge": {"token": challenge.token, "number": number}};
        }
        if number % 1000 == 999 {
            await Reflect.construct(
                Promise, [lambda (resolve: any) { setTimeout(resolve, 0); }]
            );
            if Date.now() >= deadline {
                return {
                    "error": "Verification expired. Please try again.",
                    "status": 0
                };
            }
        }
        number += 1;
    }
    return {"error": "Verification failed. Please try again.", "status": 0};
}
