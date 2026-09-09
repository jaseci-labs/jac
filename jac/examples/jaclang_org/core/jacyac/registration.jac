import from "@jac/runtime" { __getApiBaseUrl }
import from "@noble/hashes/sha2.js" { sha256 }
import from "@noble/hashes/utils.js" { utf8ToBytes, bytesToHex }
import from core.async_utils { sleep }

async def:pub register_with_challenge(username: str, password: str) -> str {
    base = __getApiBaseUrl();
    response = await fetch(base + "/user/register/challenge", {"method": "POST"});
    if not response.ok {
        details: any = await response.json();
        return str(details.error.message)
            if details.error?.message
            else "Verification is unavailable. Please try again.";
    }
    envelope: any = await response.json();
    data = envelope.data;
    if not data {
        return "Could not start verification. Please try again.";
    }
    proof: any = None;
    if data.required {
        challenge = data.challenge;
        if not challenge or challenge.max_number > 100000 {
            return "Invalid verification challenge. Please try again.";
        }
        deadline = Date.now() + challenge.expires_in * 1000;
        for number in range(challenge.max_number + 1) {
            digest = bytesToHex(sha256(utf8ToBytes(challenge.salt + str(number))));
            if digest == challenge.target {
                proof = {"token": challenge.token, "number": number};
                break;
            }
            if number % 500 == 0 {
                await sleep(0);
                if Date.now() >= deadline {
                    return "Verification expired. Please try again.";
                }
            }
        }
        if proof is None {
            return "Verification failed. Please try again.";
        }
    }
    result = await fetch(
        base + "/user/register",
        {
            "method": "POST",
            "headers": {"Content-Type": "application/json"},
            "body": JSON.stringify(
                {
                    "identities": [{"type": "username", "value": username}],
                    "credential": {"type": "password", "password": password},
                    "challenge": proof
                }
            )
        }
    );
    if result.ok {
        return "";
    }
    details: any = await result.json();
    if details.error and details.error.message {
        return str(details.error.message);
    }
    return "Registration failed. Try again with a fresh verification or a different username.";
}
