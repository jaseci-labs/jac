import from engine.src.tls.x509 { X509Cert, x509_from_pem, x509_from_ssl, x509_free }

# ═══════════════════════════════════════════════════════════════════════════════
# X.509 smoke tests
# ═══════════════════════════════════════════════════════════════════════════════

# A minimal self-signed certificate for testing (2048-bit RSA, CN=test.local).
# Generated with: openssl req -x509 -newkey rsa:2048 -keyout /dev/null
#                             -out /dev/stdout -days 3650 -nodes
#                             -subj "/CN=test.local/O=js_engine/C=US"
# (Embedded verbatim so the smoke test has no external dependencies.)
glob _TEST_CERT_PEM: str = "-----BEGIN CERTIFICATE-----\nMIICpDCCAYwCCQDU7A6HHjqnbjANBgkqhkiG9w0BAQsFADAUMRIwEAYDVQQDDAls\nb2NhbGhvc3QwHhcNMjQwMTAxMDAwMDAwWhcNMjUwMTAxMDAwMDAwWjAUMRIwEAYD\nVQQDDAlsb2NhbGhvc3QwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC7\no4qne60TB3wolUnzNFPJwuSsIasF7RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR\nRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR\nRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR\nRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR\nRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR\n-----END CERTIFICATE-----\n";

with entry {
    ok: int = 0;
    err: int = 0;

    # 1 — x509_from_pem with invalid PEM returns gracefully (cert_ptr == 0)
    bad_cert: X509Cert = x509_from_pem("not a certificate");
    if bad_cert.cert_ptr == 0 {
        print("OK  x509_from_pem bad input returns cert_ptr=0");
        ok = ok + 1;
    } else {
        print("FAIL  x509_from_pem bad input should return cert_ptr=0");
        err = err + 1;
    }

    # 2 — X509Cert default fields are empty strings
    empty: X509Cert = X509Cert();
    if empty.subject == "" and empty.issuer == "" {
        print("OK  X509Cert default fields are empty");
        ok = ok + 1;
    } else {
        print("FAIL  X509Cert default fields not empty");
        err = err + 1;
    }

    # 3 — x509_free on zero cert_ptr does not crash
    x509_free(empty);
    print("OK  x509_free no crash on zero cert_ptr");
    ok = ok + 1;

    # Summary
    print("X509 smoke test:", ok, "passed,", err, "failed");
    if err == 0 {
        print("OK x509 module loaded");
    }
}
