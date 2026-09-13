"""The embedded interpreter returns sparse compiler working memory to the OS."""
import json;
import os;
import subprocess;
import sys;
import from unittest { SkipTest }

glob SPARSE_HEAP: str = '''
import gc, json
from pathlib import Path

def rss():
    return int(next(line for line in Path('/proc/self/status').read_text().splitlines()
                    if line.startswith('VmRSS:')).split()[1])

gc.collect()
baseline = rss()
# Small, persistent objects interspersed with transient syntax nodes pin
# pymalloc's entire 1 MiB arenas, even after almost every object is freed.
transient = [bytearray(400) for _ in range(500000)]
survivors = transient[::1500]
peak = rss()
del transient
gc.collect()
print(json.dumps(dict(baseline=baseline, peak=peak, remaining=rss(),
                     survivors=len(survivors))))
''';

test "sparse survivors do not pin a released compiler sized heap" {
    if sys.platform != 'linux' {
        raise SkipTest('current resident memory is measured through /proc');
    }
    env = dict(os.environ);
    env.pop('MIMALLOC_PURGE_DELAY', None);
    result = subprocess.run(
        [sys.executable, '-c', SPARSE_HEAP],
        capture_output=True,
        text=True,
        env=env,
        timeout=30
    );
    assert result.returncode == 0 , result.stderr;
    memory = json.loads(result.stdout);
    working = memory['peak'] - memory['baseline'];
    retained = memory['remaining'] - memory['baseline'];
    assert memory['survivors'] > 0 and working > 128 * 1024 , memory;
    assert retained < working / 2 , (
        f'released objects left {retained} KiB resident from {working} KiB of working memory'
    );
}
