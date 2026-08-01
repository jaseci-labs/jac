def external_backend_secret_values(backends: dict[str, any]) -> dict[str, str] {
    values: dict[str, str] = {};
    for name in sorted(backends.keys()) {
        entry = dict(backends.get(name, {}) or {});
        if entry.get('source') != 'external' {
            continue;
        }
        values[str(entry['env'])] = str(entry['url']);
    }
    return values;
}


def custom_auth_env_entries(external_auth: dict[str, any]) -> list[dict[str, any]] {
    if str(external_auth.get('type', 'managed') or 'managed') != 'custom' {
        return [];
    }
    entries: list[dict[str, any]] = [{'name': 'JAC_AUTH_TYPE', 'value': 'custom'}];
    for pair in (
        ('issuer', 'JAC_AUTH_ISSUER'),
        ('jwks_url', 'JAC_AUTH_JWKS_URL'),
        ('audience', 'JAC_AUTH_AUDIENCE')
    ) {
        value = str(external_auth.get(pair[0], '') or '');
        if value {
            entries.append({'name': pair[1], 'value': value});
        }
    }
    return entries;
}
