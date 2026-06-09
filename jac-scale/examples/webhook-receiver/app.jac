"""Minimal jac-scale webhook example.

Exposes a single signed webhook endpoint and shows the secure usage shape:
a per-key signing_secret is returned once at key creation, the caller HMACs
`f"{timestamp}.".encode() + body` with it, and the request carries the
api_key, signature and timestamp in three headers. Use allowed_walkers to
scope an api key to specific webhook walkers.

Run:
    jac start app.jac --port 8000

1. Register and log in:
    curl -X POST localhost:8000/user/register \
        -H 'Content-Type: application/json' \
        -d '{"identities":[{"type":"username","value":"alice"}],
             "credential":{"type":"password","password":"pw"}}'

    TOKEN=$(curl -s -X POST localhost:8000/user/login \
        -H 'Content-Type: application/json' \
        -d '{"identity":{"type":"username","value":"alice"},
             "credential":{"type":"password","password":"pw"}}' \
        | jq -r '.[1].data.token')

2. Create a scoped api key (returns api_key + signing_secret ONCE):
    curl -X POST localhost:8000/api-key/create \
        -H "Authorization: Bearer $TOKEN" \
        -H 'Content-Type: application/json' \
        -d '{"name":"stripe","expiry_days":30,"allowed_walkers":"PaymentReceived"}'

3. Call the webhook (see call_webhook.py for the signing step)."""

@restspec(protocol=APIProtocol.WEBHOOK)
walker PaymentReceived {
    has payment_id: str,
        order_id: str,
        amount: float,
        currency: str = "USD";

    can process with Root entry {
        report {
            "status": "success",
            "payment_id": self.payment_id,
            "order_id": self.order_id,
            "amount": self.amount,
            "currency": self.currency
        };
    }
}
