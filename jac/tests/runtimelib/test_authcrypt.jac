import hashlib;
import hmac;
import from base64 { urlsafe_b64encode }
import from json { dumps }
import from jaclang.server.serving.authcrypt { JWTError, jwt_decode, jwt_encode }

glob SECRET: str = "test-jwt-json-shapes";


def _signed_token(header: any, payload: any) -> str {
    head = urlsafe_b64encode(dumps(header).encode()).decode("ascii").rstrip("=");
    body = urlsafe_b64encode(dumps(payload).encode()).decode("ascii").rstrip("=");
    signing_input = f"{head}.{body}".encode("ascii");
    signature = hmac.new(SECRET.encode(), signing_input, hashlib.sha256).digest();
    sig = urlsafe_b64encode(signature).decode("ascii").rstrip("=");
    return f"{head}.{body}.{sig}";
}


test "jwt rejects non-object headers and payloads" {
    for value in [[], "claims", 42, True, None] {
        for token in [
            _signed_token(value, {}),
            _signed_token({"alg": "HS256"}, value)
        ] {
            with testraises(JWTError) as exc {
                jwt_decode(token, SECRET);
            }
            assert str(exc.value) == "malformed token";
        }
    }
}


test "jwt rejects the malformed header from issue 9885" {
    with testraises(JWTError) as exc {
        jwt_decode("W10.e30.AA", SECRET);
    }
    assert str(exc.value) == "malformed token";
}


test "jwt still accepts object claims" {
    for payload in [{}, {"sub": "alice", "roles": ["reader"]}] {
        assert jwt_decode(jwt_encode(payload, SECRET), SECRET) == payload;
    }
}
