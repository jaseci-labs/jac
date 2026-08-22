"""Standalone SipHash secret bootstrap probes."""
import from pyhash { hash_secret_keys_from_seed, str_hash_text, bytes_hash_data, }

test "pyhash: PYTHONHASHSEED LCG derives SipHash keys" {
    (k0, k1) = hash_secret_keys_from_seed(42);
    assert k0 == 0xdc504fd368cd90af , k0;
    assert k1 == 0xb920bb9ffe99e9c1 , k1;
    (z0, z1) = hash_secret_keys_from_seed(0);
    assert z0 == 0 , z0;
    assert z1 == 0 , z1;
}

test "pyhash: empty buffer hash is zero" {
    assert str_hash_text("") == 0;
    assert bytes_hash_data([]) == 0;
}
