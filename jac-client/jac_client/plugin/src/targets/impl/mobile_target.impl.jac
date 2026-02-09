"""Implementation of MobileTarget methods.

Wraps the existing web bundle in an Expo app with react-native-webview.
Same pattern as DesktopTarget: WebTarget.build() → native shell.
"""
import json;
import os;
import shutil;
import subprocess;
import socket;
import from pathlib { Path }
import from typing { Optional }
import from jaclang.cli.console { console }
import from jaclang.project.config { get_config }

# Path to plugin defaults directory (app_config.json, eas_config.json)
glob DEFAULTS_DIR = Path(__file__).parent.parent.parent.parent / "defaults";

# ===============================================================================
# Setup: Scaffold Expo project with WebView shell
# ===============================================================================

"""Setup mobile target - scaffold Expo project with WebView shell."""
impl MobileTarget.setup(self: MobileTarget, project_dir: Path) -> None {
    import from jac_client.plugin.utils { ensure_bun_available }

    mobile_dir = project_dir / ".jac" / "mobile";

    # Check if already set up
    if (mobile_dir / "package.json").exists() {
        console.warning("Mobile target already set up. To re-scaffold, delete .jac/mobile/ first.");
        return;
    }

    # Check prerequisites
    if not ensure_bun_available() {
        raise RuntimeError("Bun is required for mobile target. Install: https://bun.sh") ;
    }

    console.print("\n📱 Setting up mobile target (Expo + WebView)", style="bold");
    console.print(f"  Project directory: {project_dir}", style="muted");

    # 1. Create directory structure
    mobile_dir.mkdir(parents=True, exist_ok=True);
    (mobile_dir / "assets").mkdir(exist_ok=True);
    (mobile_dir / "assets" / "web").mkdir(exist_ok=True);

    # 2. Get project metadata from jac.toml
    config = get_config();
    project_name = "jac-app";
    project_version = "1.0.0";
    if config {
        project_name = config.project.name or "jac-app";
        project_version = config.project.version or "1.0.0";
    }

    # Derive slug (lowercase, hyphens only)
    slug = project_name.lower().replace(" ", "-").replace("_", "-");

    # 3. Generate package.json (don't fail setup if this fails)
    try {
        _generate_package_json(mobile_dir, slug);
        console.print("  ✔ Generated package.json", style="success");
    } except Exception as e {
        console.warning(f"  Failed to generate package.json: {e}");
    }

    # 4. Generate App.tsx (WebView shell)
    try {
        _generate_app_tsx(mobile_dir);
        console.print("  ✔ Generated App.tsx (WebView shell)", style="success");
    } except Exception as e {
        console.warning(f"  Failed to generate App.tsx: {e}");
    }

    # 5. Generate app.json from template
    try {
        _generate_app_json(mobile_dir, project_name, slug, project_version);
        console.print("  ✔ Generated app.json", style="success");
    } except Exception as e {
        console.warning(f"  Failed to generate app.json: {e}");
    }

    # 6. Generate eas.json
    try {
        _generate_eas_json(mobile_dir);
        console.print("  ✔ Generated eas.json", style="success");
    } except Exception as e {
        console.warning(f"  Failed to generate eas.json: {e}");
    }

    # 7. Generate babel.config.js
    try {
        _generate_babel_config(mobile_dir);
        console.print("  ✔ Generated babel.config.js", style="success");
    } except Exception as e {
        console.warning(f"  Failed to generate babel.config.js: {e}");
    }

    # 8. Generate tsconfig.json
    try {
        _generate_tsconfig(mobile_dir);
        console.print("  ✔ Generated tsconfig.json", style="success");
    } except Exception as e {
        console.warning(f"  Failed to generate tsconfig.json: {e}");
    }

    # 9. Generate placeholder assets
    try {
        _generate_placeholder_assets(mobile_dir);
        console.print("  ✔ Generated placeholder assets", style="success");
    } except Exception as e {
        console.warning(f"  Failed to generate placeholder assets: {e}");
    }

    # 10. Install dependencies
    console.print("\n📦 Installing Expo dependencies...", style="bold");
    try {
        result = subprocess.run(
            ["bun", "install"],
            cwd=str(mobile_dir),
            check=False,
            timeout=300
        );
        if result.returncode != 0 {
            console.warning("Package installation had issues. Run manually: cd .jac/mobile && bun install");
        } else {
            console.print("  ✔ Dependencies installed", style="success");
        }
    } except subprocess.TimeoutExpired {
        console.warning("Package installation timed out. Run manually: cd .jac/mobile && bun install");
    } except FileNotFoundError {
        console.warning("Bun not found. Run manually: cd .jac/mobile && bun install");
    }

    # 11. Update jac.toml with mobile config
    try {
        _update_jac_toml_mobile_config(project_dir, slug);
    } except Exception as e {
        console.warning(f"  Failed to update jac.toml: {e}");
    }

    console.success("Mobile target setup complete!");
    console.print("\nNext steps:", style="bold");
    console.print("  1. Dev:   jac start --client mobile");
    console.print("  2. Build: jac build --client mobile --target ios --profile production");
}

# ===============================================================================
# Build: Web bundle → Expo app
# ===============================================================================

"""Build mobile app - build web bundle first, then wrap with Expo."""
impl MobileTarget.build(
    self: MobileTarget,
    entry_file: Path,
    project_dir: Path,
    platform: Optional[str] = None
) -> Path {
    import from jac_client.plugin.src.targets.registry { get_target_registry }

    mobile_dir = project_dir / ".jac" / "mobile";

    # Verify setup
    if not (mobile_dir / "package.json").exists() {
        raise RuntimeError("Mobile target not set up. Run 'jac setup mobile' first.") ;
    }

    # 1. Build web bundle first (reuse WebTarget.build)
    console.print("\n  Building web bundle...", style="bold");
    registry = get_target_registry();
    web_target = registry.get("web");
    if not web_target {
        raise RuntimeError("Web target not found in registry") ;
    }
    bundle_path = web_target.build(entry_file, project_dir, None);
    console.print("  ✔ Web bundle built", style="success");

    # 2. Copy web bundle to Expo assets
    web_assets_dir = mobile_dir / "assets" / "web";
    if web_assets_dir.exists() {
        shutil.rmtree(web_assets_dir);
    }
    web_assets_dir.mkdir(parents=True, exist_ok=True);

    dist_dir = project_dir / ".jac" / "client" / "dist";
    if dist_dir.exists() {
        for item in dist_dir.iterdir() {
            dest = web_assets_dir / item.name;
            if item.is_dir() {
                shutil.copytree(str(item), str(dest));
            } else {
                shutil.copy2(str(item), str(dest));
            }
        }
    }
    console.print("  ✔ Web bundle copied to mobile assets", style="success");

    # 3. Update app.json with latest metadata
    _refresh_app_json(mobile_dir, project_dir);

    # 4. Run EAS build or expo export
    profile = os.environ.get("JAC_MOBILE_PROFILE", "preview");

    if platform {
        # Run eas build
        cmd = ["bunx", "eas", "build", "--platform", platform, "--profile", profile];
        if os.environ.get("JAC_MOBILE_LOCAL_BUILD") {
            cmd.append("--local");
        }
        console.print(f"\n  Running: {' '.join(cmd)}", style="muted");
        console.print("  EAS cloud builds may take 15-30 minutes...\n", style="muted");
        try {
            # No timeout — EAS cloud builds can take 15-30+ minutes
            subprocess.run(cmd, cwd=str(mobile_dir), check=True);
        } except subprocess.CalledProcessError as e {
            raise RuntimeError(f"EAS build failed: {e}") from e ;
        } except FileNotFoundError {
            raise RuntimeError(
                "Bun/EAS CLI not found. Ensure Bun is installed: https://bun.sh"
            ) ;
        }
    } else {
        # Export bundle (no platform specified = export only)
        cmd = ["bunx", "expo", "export"];
        console.print(f"\n  Running: {' '.join(cmd)}", style="muted");
        try {
            subprocess.run(cmd, cwd=str(mobile_dir), check=True, timeout=300);
        } except subprocess.TimeoutExpired {
            raise RuntimeError("Expo export timed out after 5 minutes") ;
        } except subprocess.CalledProcessError as e {
            raise RuntimeError(f"Expo export failed: {e}") from e ;
        } except FileNotFoundError {
            raise RuntimeError(
                "Bun/Expo CLI not found. Ensure Bun is installed: https://bun.sh"
            ) ;
        }
    }

    return mobile_dir;
}

# ===============================================================================
# Dev: Start backend + Expo dev server
# ===============================================================================

"""Start mobile dev server - start jac backend and launch Expo dev server."""
impl MobileTarget.dev(
    self: MobileTarget, entry_file: Path, project_dir: Path,
    api_port: int = 8000
) -> None {
    mobile_dir = project_dir / ".jac" / "mobile";

    # Verify setup
    if not (mobile_dir / "package.json").exists() {
        raise RuntimeError("Mobile target not set up. Run 'jac setup mobile' first.") ;
    }

    # Detect LAN IP for physical device access
    lan_ip = _get_lan_ip();
    dev_url = f"http://{lan_ip}:{api_port}";

    console.print(f"\n  Mobile dev server starting...", style="bold");
    console.print(f"  Backend URL: {dev_url}", style="muted");
    console.print(f"  WebView will load: {dev_url}\n", style="muted");

    # Set environment variable for App.tsx to read
    env = os.environ.copy();
    env["EXPO_PUBLIC_DEV_SERVER_URL"] = dev_url;

    # Build expo start command
    expo_cmd = ["bunx", "expo", "start"];

    # Check for platform-specific flags from environment
    if os.environ.get("JAC_MOBILE_IOS") {
        expo_cmd.append("--ios");
    } elif os.environ.get("JAC_MOBILE_ANDROID") {
        expo_cmd.append("--android");
    }
    if os.environ.get("JAC_MOBILE_TUNNEL") {
        expo_cmd.append("--tunnel");
    }

    # Start Expo dev server
    console.print(f"  Running: {' '.join(expo_cmd)}", style="muted");
    console.print("  Scan the QR code with Expo Go to view your app.\n", style="cyan");

    try {
        expo_proc = subprocess.Popen(
            expo_cmd,
            cwd=str(mobile_dir),
            env=env
        );
        expo_proc.wait();
    } except KeyboardInterrupt {
        console.print("\n  Shutting down Expo dev server...", style="muted");
        expo_proc.terminate();
        try {
            expo_proc.wait(timeout=5);
        } except subprocess.TimeoutExpired {
            expo_proc.kill();
        }
    } except FileNotFoundError {
        raise RuntimeError(
            "Bun/Expo CLI not found. Ensure Bun is installed: https://bun.sh"
        ) ;
    }
}

# ===============================================================================
# Start: Build + launch (production-like)
# ===============================================================================

"""Start mobile app - build web bundle and launch Expo with built bundle."""
impl MobileTarget.start(
    self: MobileTarget, entry_file: Path, project_dir: Path,
    api_port: int = 8000
) -> None {
    # For mobile, start and dev are equivalent — both launch Expo dev server
    # Production builds use `jac build --client mobile --target ios|android`
    self.dev(entry_file, project_dir, api_port=api_port);
}


# ===============================================================================
# Helper: Generate package.json
# ===============================================================================

"""Generate package.json for the Expo project."""
def _generate_package_json(mobile_dir: Path, slug: str) -> None {
    package_json = {
        "name": slug,
        "version": "1.0.0",
        "main": "expo/AppEntry.js",
        "scripts": {
            "start": "expo start",
            "android": "expo start --android",
            "ios": "expo start --ios",
            "web": "expo start --web"
        },
        "dependencies": {
            "expo": "~52.0.0",
            "expo-constants": "~17.0.0",
            "expo-status-bar": "~2.0.0",
            "react": "18.3.1",
            "react-native": "0.76.6",
            "react-native-webview": "13.12.5"
        },
        "devDependencies": {
            "@babel/core": "^7.25.0",
            "@types/react": "~18.3.0",
            "typescript": "^5.3.0"
        },
        "private": True
    };

    with open(mobile_dir / "package.json", "w") as f {
        json.dump(package_json, f, indent=2);
        f.write("\n");
    }
}

# ===============================================================================
# Helper: Generate App.tsx (WebView shell)
# ===============================================================================

"""Generate App.tsx WebView shell that loads the web app."""
def _generate_app_tsx(mobile_dir: Path) -> None {
    app_content = '''import React from 'react';
import { SafeAreaView, StyleSheet, ActivityIndicator, View } from 'react-native';
import { StatusBar } from 'expo-status-bar';
import { WebView } from 'react-native-webview';

const DEV_SERVER_URL = process.env.EXPO_PUBLIC_DEV_SERVER_URL || 'http://localhost:8000';

export default function App() {
  const source = { uri: DEV_SERVER_URL };

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar style="auto" />
      <WebView
        source={source}
        style={styles.webview}
        originWhitelist={['*']}
        javaScriptEnabled={true}
        domStorageEnabled={true}
        allowFileAccess={true}
        allowFileAccessFromFileURLs={true}
        startInLoadingState={true}
        renderLoading={() => (
          <View style={styles.loading}>
            <ActivityIndicator size="large" color="#2563eb" />
          </View>
        )}
        onError={(syntheticEvent) => {
          const { nativeEvent } = syntheticEvent;
          console.warn('WebView error:', nativeEvent);
        }}
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
  },
  webview: {
    flex: 1,
  },
  loading: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#fff',
  },
});
''';

    with open(mobile_dir / "App.tsx", "w") as f {
        f.write(app_content);
    }
}

# ===============================================================================
# Helper: Generate app.json from template
# ===============================================================================

"""Generate app.json from default template with project metadata."""
def _generate_app_json(
    mobile_dir: Path,
    project_name: str,
    slug: str,
    version: str
) -> None {
    # Load default template
    template_path = DEFAULTS_DIR / "app_config.json";

    if template_path.exists() {
        with open(template_path, "r") as f {
            app_config = json.load(f);
        }
    } else {
        app_config = {"expo": {}};
    }

    # Override with project values
    expo = app_config.get("expo", {});
    expo["name"] = project_name;
    expo["slug"] = slug;
    expo["version"] = version;
    app_config["expo"] = expo;

    with open(mobile_dir / "app.json", "w") as f {
        json.dump(app_config, f, indent=2);
        f.write("\n");
    }
}

# ===============================================================================
# Helper: Generate eas.json
# ===============================================================================

"""Generate eas.json with default build profiles."""
def _generate_eas_json(mobile_dir: Path) -> None {
    template_path = DEFAULTS_DIR / "eas_config.json";

    if template_path.exists() {
        shutil.copy2(str(template_path), str(mobile_dir / "eas.json"));
    } else {
        eas_config = {
            "build": {
                "development": {"developmentClient": True, "distribution": "internal"},
                "preview": {"distribution": "internal"},
                "production": {}
            }
        };
        with open(mobile_dir / "eas.json", "w") as f {
            json.dump(eas_config, f, indent=2);
            f.write("\n");
        }
    }
}

# ===============================================================================
# Helper: Generate babel.config.js
# ===============================================================================

"""Generate babel.config.js for Expo preset."""
def _generate_babel_config(mobile_dir: Path) -> None {
    content = '''module.exports = function (api) {
  api.cache(true);
  return {
    presets: ['babel-preset-expo'],
  };
};
''';
    with open(mobile_dir / "babel.config.js", "w") as f {
        f.write(content);
    }
}

# ===============================================================================
# Helper: Generate tsconfig.json
# ===============================================================================

"""Generate tsconfig.json extending Expo base config."""
def _generate_tsconfig(mobile_dir: Path) -> None {
    tsconfig = {
        "extends": "expo/tsconfig.base",
        "compilerOptions": {
            "strict": True
        }
    };
    with open(mobile_dir / "tsconfig.json", "w") as f {
        json.dump(tsconfig, f, indent=2);
        f.write("\n");
    }
}

# ===============================================================================
# Helper: Generate placeholder asset files
# ===============================================================================

"""Generate placeholder icon/splash PNGs for Expo assets."""
def _generate_placeholder_assets(mobile_dir: Path) -> None {
    import base64;
    assets_dir = mobile_dir / "assets";
    assets_dir.mkdir(exist_ok=True);

    # Minimal 1x1 pixel PNG (transparent) as placeholder for all icons
    # Real apps should replace these with actual assets
    pixel_png = base64.b64decode(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
    );

    for name in ["icon.png", "splash-icon.png", "adaptive-icon.png", "favicon.png"] {
        asset_path = assets_dir / name;
        if not asset_path.exists() {
            with open(asset_path, "wb") as f {
                f.write(pixel_png);
            }
        }
    }
}

# ===============================================================================
# Helper: Update jac.toml with mobile config
# ===============================================================================

"""Add [plugins.client.mobile] section to jac.toml if not present."""
def _update_jac_toml_mobile_config(project_dir: Path, slug: str) -> None {
    config = get_config();
    if not config {
        return;
    }

    # Check if mobile config already exists
    client_cfg = config.get_plugin_config("client");
    if client_cfg and client_cfg.get("mobile") {
        return;
    }

    # Add mobile config section to jac.toml
    toml_path = project_dir / "jac.toml";
    if toml_path.exists() {
        content = toml_path.read_text();
        if "[plugins.client.mobile]" not in content {
            mobile_section = f'''
[plugins.client.mobile]
scheme = "{slug}"
api_base_url = "http://localhost:8000"
bundle_identifier = "com.example.{slug.replace('-', '')}"
package_name = "com.example.{slug.replace('-', '')}"
''';
            content += mobile_section;
            toml_path.write_text(content);
            console.print("  ✔ Updated jac.toml with [plugins.client.mobile]", style="success");
        }
    }
}

# ===============================================================================
# Helper: Refresh app.json with latest jac.toml metadata
# ===============================================================================

"""Sync app.json with latest project metadata from jac.toml."""
def _refresh_app_json(mobile_dir: Path, project_dir: Path) -> None {
    config = get_config();
    if not config {
        return;
    }

    app_json_path = mobile_dir / "app.json";
    if not app_json_path.exists() {
        return;
    }

    with open(app_json_path, "r") as f {
        app_config = json.load(f);
    }

    expo = app_config.get("expo", {});
    expo["name"] = config.project.name or expo.get("name", "jac-app");
    expo["version"] = config.project.version or expo.get("version", "1.0.0");

    # Read mobile-specific config
    client_cfg = config.get_plugin_config("client");
    if client_cfg {
        mobile_cfg = client_cfg.get("mobile", {});
        if mobile_cfg.get("scheme") {
            expo["scheme"] = mobile_cfg["scheme"];
        }
        if mobile_cfg.get("bundle_identifier") {
            ios = expo.get("ios", {});
            ios["bundleIdentifier"] = mobile_cfg["bundle_identifier"];
            expo["ios"] = ios;
        }
        if mobile_cfg.get("package_name") {
            android = expo.get("android", {});
            android["package"] = mobile_cfg["package_name"];
            expo["android"] = android;
        }
    }

    app_config["expo"] = expo;
    with open(app_json_path, "w") as f {
        json.dump(app_config, f, indent=2);
        f.write("\n");
    }
}

# ===============================================================================
# Helper: Get LAN IP for physical device access
# ===============================================================================

"""Detect LAN IP address for physical device access over Wi-Fi.

Uses a UDP socket connection to Google DNS (8.8.8.8:80) to determine
the local network interface IP. No actual traffic is sent.
Falls back to 'localhost' if detection fails.
"""
def _get_lan_ip -> str {
    try {
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM);
        try {
            # Connect to public DNS to determine outbound network interface
            s.connect(("8.8.8.8", 80));
            ip = s.getsockname()[0];
        } finally {
            s.close();
        }
        return ip;
    } except Exception {
        return "localhost";
    }
}
