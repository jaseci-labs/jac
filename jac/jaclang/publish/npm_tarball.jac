"""Reproducible npm `.tgz` packing — a leaf helper shared by the npm builders."""

# Fixed mtime for all tar entries — produces reproducible tarballs.
# 2016-01-01T00:00:00Z, mirroring the wheel builder's reproducibility convention.
glob _NPM_MTIME: int = 1451606400;

"""Pack (arcname, data) members into a reproducible gzipped tar (npm `.tgz`).

   Members must already carry the `package/` prefix npm expects. Entries are
   sorted and stamped with a fixed mtime/owner so identical input yields
   byte-identical output."""
def pack_tarball(members: list[tuple[str, bytes]]) -> bytes;
