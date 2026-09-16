"""The macOS application bundle around a built desktop host.

`AppLayout.for_host` already places the executable under Contents/MacOS and the
app's files under Contents/Resources. This module writes what makes that tree
an app to Finder and the Dock: Contents/Info.plist, PkgInfo, and the icon."""
import plistlib;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }
import from jaclang.client.desktop_config { DesktopIdentity }
import from jaclang.client.targets.desktop.app_layout { AppLayout }
import from jaclang.toolchains.desktop { MACOS_DESKTOP_MIN_VERSION }

glob ICON_NAME: str = "AppIcon",
     ICONSET_POINTS: list[int] = [16, 32, 128, 256, 512];

"""The Info.plist dictionary for an app: its identity from [desktop], the
executable it wraps, and the floor of macOS it runs on."""
def bundle_info(
    identity: DesktopIdentity, executable: str, title: str, icon: bool
) -> dict[str, object] {
    info: dict[str, object] = {
        "CFBundleDevelopmentRegion": "en",
        "CFBundleDisplayName": title or identity.name,
        "CFBundleExecutable": executable,
        "CFBundleIdentifier": identity.identifier,
        "CFBundleInfoDictionaryVersion": "6.0",
        "CFBundleName": identity.name,
        "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": identity.version,
        "CFBundleVersion": identity.version,
        "LSMinimumSystemVersion": MACOS_DESKTOP_MIN_VERSION,
        "NSHighResolutionCapable": True,
        "NSSupportsAutomaticGraphicsSwitching": True
    };
    if icon {
        info["CFBundleIconFile"] = ICON_NAME;
    }
    return info;
}

"""Write the bundle's Info.plist, PkgInfo and icon, and return the plist path."""
def write_bundle_metadata(
    layout: AppLayout, identity: DesktopIdentity, title: str, icon: Path | None
) -> Path {
    bundle = layout.bundle;
    if bundle is None {
        raise ValueError("write_bundle_metadata needs a bundle layout");
    }
    contents = bundle / "Contents";
    layout.resources.mkdir(parents=True, exist_ok=True);
    if icon is not None {
        write_icon(icon, layout.resources / (ICON_NAME + ".icns"));
    }
    info = contents / "Info.plist";
    with open(info, "wb") as out {
        plistlib.dump(
            bundle_info(identity, layout.executable.name, title, icon is not None), out
        );
    }
    (contents / "PkgInfo").write_text("APPL????");
    return info;
}

"""Install an icon as `destination`: an .icns is copied, a .png is rendered into
an iconset with sips and packed with iconutil, both of which ship with macOS."""
def write_icon(source: Path, destination: Path) {
    if source.suffix == ".icns" {
        shutil.copy2(source, destination);
        return;
    }
    with tempfile.TemporaryDirectory() as tmp {
        iconset = Path(tmp) / (ICON_NAME + ".iconset");
        iconset.mkdir();
        for points in ICONSET_POINTS {
            for (scale, suffix) in [(1, ""), (2, "@2x")] {
                pixels = str(points * scale);
                subprocess.run(
                    [
                        "sips",
                        "-z",
                        pixels,
                        pixels,
                        str(source),
                        "--out",
                        str(iconset / f"icon_{points}x{points}{suffix}.png")
                    ],
                    check=True,
                    capture_output=True
                );
            }
        }
        subprocess.run(
            ["iconutil", "-c", "icns", str(iconset), "-o", str(destination)],
            check=True,
            capture_output=True
        );
    }
}
