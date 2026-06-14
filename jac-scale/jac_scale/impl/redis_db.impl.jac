"""Redis implementation for RedisDb."""
import json;
import from jac_scale._db_helpers { _validate_not_read_only }

"""Generate Redis key in format: {db_name}:{col_name}:{key}."""
def _redis_key(db_name: str, col_name: str, key: str) -> str {
    return f"{db_name}:{col_name}:{key}";
}

# Lua script kept at module scope so redis-py can cache its SHA after the first
# EVAL; subsequent calls send EVALSHA, avoiding round-trips of the script body.
glob _DELETE_IF_EQUALS_LUA: str = '''
if redis.call('GET', KEYS[1]) == ARGV[1] then
    return redis.call('DEL', KEYS[1])
else
    return 0
end
''';

impl RedisDb._get_redis_key(col_name: str, key: str) -> str {
    return _redis_key(self.db_name, col_name, key);
}

impl RedisDb.get(key: str, col_name: str = 'default') -> dict | None {
    redis_key = self._get_redis_key(col_name, key);
    if (data := self.client.get(redis_key)) {
        return json.loads(data);
    }
    return None;
}

impl RedisDb.set(key: str, value: dict, col_name: str = 'default') -> str {
    _validate_not_read_only(col_name);
    redis_key = self._get_redis_key(col_name, key);
    self.client.set(redis_key, json.dumps(value));
    return key;
}

impl RedisDb.delete(key: str, col_name: str = 'default') -> int {
    _validate_not_read_only(col_name);
    return self.client.delete(self._get_redis_key(col_name, key));
}

impl RedisDb.exists(key: str, col_name: str = 'default') -> bool {
    return self.client.exists(self._get_redis_key(col_name, key)) > 0;
}

impl RedisDb.set_with_ttl(
    key: str, value: dict, ttl: int, col_name: str = 'default'
) -> bool {
    _validate_not_read_only(col_name);
    return self.client.setex(
        self._get_redis_key(col_name, key), ttl, json.dumps(value)
    );
}

impl RedisDb.incr(key: str, col_name: str = 'default') -> int {
    return self.client.incr(self._get_redis_key(col_name, key));
}

impl RedisDb.expire(key: str, seconds: int, col_name: str = 'default') -> bool {
    return self.client.expire(self._get_redis_key(col_name, key), seconds);
}

impl RedisDb.set_nx_with_ttl(
    key: str, value: dict, ttl: int, col_name: str = 'default'
) -> bool {
    _validate_not_read_only(col_name);
    result = self.client.set(
        self._get_redis_key(col_name, key), json.dumps(value), nx=True, ex=ttl
    );
    return bool(result);
}

impl RedisDb.delete_if_equals(
    key: str, expected_value: dict, col_name: str = 'default'
) -> bool {
    _validate_not_read_only(col_name);
    result = self.client.eval(
        _DELETE_IF_EQUALS_LUA,
        1,
        self._get_redis_key(col_name, key),
        json.dumps(expected_value)
    );
    return int(result) == 1;
}

# Redis stores keys as "{db_name}:{col_name}:{original_key}" — exactly two prefix
# segments — so split on at most two colons and keep the remainder. Using
# split(':', 2)[2] (rather than split(':')[-1]) preserves original keys that
# themselves contain ':', e.g. "session:user1" stays "session:user1" instead of
# being silently truncated to "user1".
impl RedisDb.scan_keys(pattern: str, col_name: str = 'default') -> list[str] {
    full_pattern = self._get_redis_key(col_name, pattern);
    keys = [];
    for key in self.client.scan_iter(match=full_pattern) {
        key_str = key.decode('utf-8') if isinstance(key, bytes) else key;
        keys.append(key_str.split(':', 2)[2]);
    }
    return keys;
}

impl RedisDb.find_by_id(col_name: str, id: str) -> dict | None {
    return self.get(id, col_name);
}

impl RedisDb.delete_by_id(col_name: str, id: str) -> DeleteResult {
    deleted = self.delete(id, col_name);
    return DeleteResult(deleted_count=deleted);
}
