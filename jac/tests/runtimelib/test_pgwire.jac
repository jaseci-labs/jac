"""Unit tests for jac's minimal Postgres wire client (epic #7945).

Offline: SCRAM-SHA-256 math pinned to the RFC 7677 test vector, named
parameter conversion, array literal encoding, and error-field parsing.
The live protocol (trust auth over unix sockets) is exercised end to end
by the pg-session parity suite; SCRAM-over-TCP is covered by the k8s path.
"""

import from jaclang.runtimelib.pgwire {
    _array_literal,
    _named_to_positional,
    _parse_error_fields,
    _scram_proofs
}


test "scram-sha-256 matches the RFC 7677 test vector" {
    client_first_bare = "n=user,r=rOprNGfwEbeRWgbNEkqO";
    server_first = (
        "r=rOprNGfwEbeRWgbNEkqO%hvYDpWUa2RaTCAfuxFIlj)hNlF$k0,"
        "s=W22ZaJ0SNY7soEsUEjb6gQ==,i=4096"
    );
    (client_final_wo, proof, server_sig) = _scram_proofs(
        "pencil", server_first, client_first_bare
    );
    assert client_final_wo
        == ("c=biws,r=rOprNGfwEbeRWgbNEkqO%hvYDpWUa2RaTCAfuxFIlj)hNlF$k0");
    assert proof == "dHzbZapWIk4jUhN+Ute9ytag9zjfMHgsqmmiz7AndVQ=";
    assert server_sig == "6rriTRBi23WpRR/wtup+mMhUZUn/dB5nLTJRsjl95G4=";
}


test "named params convert to positional, sharing repeated slots" {
    (sql, args) = _named_to_positional(
        "UPDATE t SET a = :v, b = :v WHERE id = :i AND k = 'lit:x' "
        "AND j = CAST(:v AS jsonb)::text",
        {'v': 'val', 'i': 7}
    );
    assert sql
        == (
            "UPDATE t SET a = $1, b = $1 WHERE id = $2 AND k = 'lit:x' "
            "AND j = CAST($1 AS jsonb)::text"
        );
    assert args == ['val', 7];
}


test "placeholders inside quotes and unknown names are untouched" {
    (sql, args) = _named_to_positional(
        "SELECT ':notaparam', \":alsonot\", :real FROM x WHERE t = ':real'", {'real': 1}
    );
    assert sql == ("SELECT ':notaparam', \":alsonot\", $1 FROM x WHERE t = ':real'");
    assert args == [1];
}


test "array literal escapes quotes and backslashes" {
    lit = _array_literal(['plain', 'has"quote', 'back\\slash']);
    assert lit == '{"plain","has\\"quote","back\\\\slash"}';
}


test "error fields parse into the sqlstate dict shape" {
    payload = b'SERROR\x00C40001\x00Mdeadlock\x00\x00';
    fields = _parse_error_fields(payload);
    assert fields == {'S': 'ERROR', 'C': '40001', 'M': 'deadlock'};
}
