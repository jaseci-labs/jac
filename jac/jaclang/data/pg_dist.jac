import logging;
import os;
import platform;
import shutil;
import subprocess;
import urllib.request;
import zipfile;
import from pathlib { Path }

glob logger = logging.getLogger(__name__),
     PG_MAJOR: int = 19,
     MIN_SYSTEM_MAJOR: int = 14,
     ZONKY_BASE: str = (
         'https://repo1.maven.org/maven2/io/zonky/test/postgres/'
         'embedded-postgres-binaries-'
     ),
     SYSTEM_ROOTS: tuple[str, ...] = (
         '/usr/lib/postgresql',
         '/usr/pgsql',
         '/opt/homebrew/opt'
     );

def _database_config -> (DatabaseConfig | None);

def _configured_dist -> str;

def _env_dist -> str;

def pinned_major -> int;

def dist_cache_dir -> str;

def platform_slug -> (str | None);

def postgres_exe -> str;

def _bin_of(dist: str) -> (str | None);

def pg_major_of(bin_dir: str) -> (int | None);

def _version_key(version: str) -> tuple[int, ...];

def _cached(major: int) -> (str | None);

def _system(major: int) -> (str | None);

def _published(slug: str) -> list[str];

def _unpack(slug: str, version: str, dist_dir: str);

def download_dist -> str;

def _dist_root(bin_dir: (str | None)) -> (str | None);

def bundled_dist_dir -> str;

def cached_dist_dir -> str;

obj PostgresArtifact(Artifact) {
    has name: str = "postgres",
        kind: ArtifactKind = ArtifactKind.CAPABILITY,
        release: ReleasePolicy = ReleasePolicy.ON_DEMAND,
        summary: str = "the embedded Postgres distribution",
        hosts: list[str] = ["linux", "darwin", "win32"],
        provision: bool = True;

    override def probe_checkout -> Probe;
    override def build_blocker -> str;
    override def checkout_path -> str;
    override def build(log: Callable[[str], None], force: bool, exact: bool);
}

def postgres_bin_dir -> str;
