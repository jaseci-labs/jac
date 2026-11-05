"""Probe the cache directory the way every launcher start does."""

import os;
import from jaclang.dist.fused.materialize { dir_writable }

with entry {
    print(dir_writable(os.environ.get("JAC_PROBE_DIR", "")));
}
