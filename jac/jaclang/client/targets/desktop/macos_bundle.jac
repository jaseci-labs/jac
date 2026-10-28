import plistlib;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }

glob ICON_NAME: str = "AppIcon",
     ICONSET_POINTS: list[int] = [16, 32, 128, 256, 512];

def bundle_info(
    identity: DesktopIdentity, executable: str, title: str, icon: bool
) -> dict[str, object];

def write_bundle_metadata(
    layout: AppLayout, identity: DesktopIdentity, title: str, icon: Path | None
) -> Path;

def write_icon(source: Path, destination: Path);
