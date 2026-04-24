"""Scaffolding helpers for MobileTarget.setup().

Generates all source files written into the user's mobile/ directory:
app.json, package.json, tsconfig.json, WebView screen, bundle script,
layout, placeholder icons, and .gitignore.  Also provides
_install_yarn_dependencies (called by bundle_helpers._prepare_build_dir).
"""
import from pathlib { Path }
import from jaclang.cli.console { console }
import subprocess;
import shutil;
import json;

"""Generate app.json from the [mobile] section of jac.toml."""
def _generate_app_json_from_toml(mobile_dir: Path, project_dir: Path) {
    import from jac_client.plugin.src.mobile_config { MobileConfig }
    mobile_config = MobileConfig(project_dir=project_dir);
    app_json_config = mobile_config.get_app_json_config();
    config_path = mobile_dir / "app.json";
    with open(config_path, "w") as f {
        json.dump(app_json_config, f, indent=2);
    }
    console.print(f"  ✔ Generated app.json from TOML config", style="success");
}

"""Generate package.json for the React Native / Expo project."""
def _generate_package_json(mobile_dir: Path, name: str) {
    package_name = str(name).lower().replace(" ", "-");
    package_json = {
        "name": package_name,
        "version": "1.0.0",
        "main": "expo-router/entry",
        "scripts": {
            "start": "expo start",
            "android": "expo start --android",
            "ios": "expo start --ios",
            "web": "expo start --web"
        },
        "dependencies": {
            "expo": "~54.0.0",
            "expo-router": "~6.0.23",
            "expo-linking": "~8.0.0",
            "expo-status-bar": "~3.0.9",
            "expo-dev-client": "~6.0.4",
            "react": "19.2.4",
            "react-dom": "19.2.4",
            "react-freeze": "~1.0.4",
            "react-native": "0.81.5",
            "react-native-safe-area-context": "~5.7.0",
            "react-native-screens": "~4.24.0",
            "react-native-webview": "13.15.0"
        },
        "devDependencies": {
            "@babel/core": "^7.25.0",
            "@types/react": "~19.1.10",
            "typescript": "^5.3.3"
        },
        "private": True
    };
    with open(mobile_dir / "package.json", "w") as f {
        json.dump(package_json, f, indent=2);
    }
    console.print(f"  ✔ Generated package.json", style="success");
}

"""Generate tsconfig.json."""
def _generate_tsconfig(mobile_dir: Path) {
    tsconfig = {"extends": "expo/tsconfig.base", "compilerOptions": {"strict": True}};
    with open(mobile_dir / "tsconfig.json", "w") as f {
        json.dump(tsconfig, f, indent=2);
    }
    console.print(f"  ✔ Generated tsconfig.json", style="success");
}

"""Generate app/index.tsx - the React Native WebView screen component."""
def _generate_webview_screen(mobile_dir: Path) {
    screen_code = '''import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, Platform, ActivityIndicator } from 'react-native';
import { WebView } from 'react-native-webview';

// Dev mode: load from Vite dev server for HMR
// Production: load from bundled HTML
const USE_DEV_SERVER = __DEV__; // Automatically enabled in dev mode

let JAC_BUNDLE_HTML: string | null = null;
if (!USE_DEV_SERVER) {
  try {
    const bundle = require('../assets/jac-app/bundle');
    JAC_BUNDLE_HTML = bundle.JAC_BUNDLE_HTML;
  } catch (e) {
    console.warn('Bundle not found, will use dev server');
  }
}

// Load dev server configuration
let DEV_CONFIG = { localIP: '127.0.0.1', productionApiUrl: '' };
try {
  const config = require('../dev-config.json');
  DEV_CONFIG = config;
} catch (e) {
  console.warn('Dev config not found, using defaults');
}

const getDevServerUrl = () => {
  const localIP = DEV_CONFIG.localIP || '127.0.0.1';
  return `http://${localIP}:5173`;
};

const getBackendApiUrl = () => {
  if (__DEV__) {
    const localIP = DEV_CONFIG.localIP || '127.0.0.1';
    // Android emulator alias for host loopback; only used when IP detection
    // falls back to 127.x (e.g. single-interface machine).
    if (Platform.OS === 'android' && (localIP === '127.0.0.1' || localIP === 'localhost')) {
      return 'http://10.0.2.2:9000';
    }
    return `http://${localIP}:9000`;
  }
  // Production: use API URL from config or log a clear error
  if (!DEV_CONFIG.productionApiUrl) {
    console.error('Production API URL not configured! Set [mobile.features].api_url in jac.toml');
    return '';
  }
  return DEV_CONFIG.productionApiUrl;
};

export default function JacWebViewScreen() {
  const [isLoading, setIsLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [htmlContent, setHtmlContent] = useState<string>('');
  const [devServerUrl, setDevServerUrl] = useState<string>('');
  const backendApiUrl = getBackendApiUrl();

  useEffect(() => {
    if (USE_DEV_SERVER || !JAC_BUNDLE_HTML) {
      setDevServerUrl(getDevServerUrl());
      setIsLoading(false);
    } else {
      prepareBundle();
    }
  }, []);

  const prepareBundle = () => {
    try {
      if (!JAC_BUNDLE_HTML) {
        throw new Error('Bundle not available');
      }
      // Inject the backend API URL using the explicit placeholder marker
      const html = JAC_BUNDLE_HTML.replace(
        `'%%__JAC_BACKEND_URL__%%'`,
        `'${backendApiUrl}'`
      );
      setHtmlContent(html);
    } catch (error) {
      setLoadError('Failed to load app bundle');
      setIsLoading(false);
    }
  };

  const handleError = (syntheticEvent: any) => {
    const { nativeEvent } = syntheticEvent;
    setLoadError(nativeEvent.description || 'Failed to load app');
    setIsLoading(false);
  };

  const handleLoadEnd = () => {
    setIsLoading(false);
    setLoadError(null);
  };

  const handleMessage = (event: any) => {
    try {
      const message = JSON.parse(event.nativeEvent.data);
      if (message.type === 'error') {
        console.error('[WebView Error]', ...message.data);
      }
    } catch {
      // Ignore non-JSON messages
    }
  };

  const renderWebView = () => {
    if (devServerUrl) {
      return (
        <WebView
          source={{ uri: devServerUrl }}
          style={styles.webview}
          javaScriptEnabled={true}
          domStorageEnabled={true}
          mixedContentMode="always"
          onLoadEnd={handleLoadEnd}
          onError={handleError}
          onMessage={handleMessage}
          startInLoadingState={true}
          cacheEnabled={false}
          originWhitelist={['*']}
          injectedJavaScript={`
            (function() {
              const originalError = console.error;
              console.error = function(...args) {
                window.ReactNativeWebView?.postMessage(JSON.stringify({type: 'error', data: args}));
                originalError.apply(console, args);
              };
              window.addEventListener('error', function(e) { console.error('Error:', e.message); });
              window.addEventListener('unhandledrejection', function(e) { console.error('Unhandled rejection:', e.reason); });
            })();
            true;
          `}
        />
      );
    } else if (htmlContent) {
      return (
        <WebView
          source={{ html: htmlContent, baseUrl: 'http://localhost/' }}
          style={styles.webview}
          javaScriptEnabled={true}
          domStorageEnabled={true}
          mixedContentMode="always"
          onLoadEnd={handleLoadEnd}
          onError={handleError}
          onMessage={handleMessage}
          allowFileAccess={true}
          allowFileAccessFromFileURLs={true}
          allowUniversalAccessFromFileURLs={true}
          startInLoadingState={true}
          cacheEnabled={false}
          originWhitelist={['*']}
          injectedJavaScript={`
            (function() {
              const originalError = console.error;
              console.error = function(...args) {
                window.ReactNativeWebView?.postMessage(JSON.stringify({type: 'error', data: args}));
                originalError.apply(console, args);
              };
              window.addEventListener('error', function(e) { console.error('Error:', e.message); });
              window.addEventListener('unhandledrejection', function(e) { console.error('Unhandled rejection:', e.reason); });
            })();
            true;
          `}
        />
      );
    }
    return null;
  };

  return (
    <View style={styles.container}>
      {isLoading && (
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color="#0066cc" />
          <Text style={styles.loadingText}>Loading Jac App...</Text>
          <Text style={styles.urlText}>
            {devServerUrl ? `From dev server: ${devServerUrl}` : 'From local bundle'}
          </Text>
        </View>
      )}
      {loadError && (
        <View style={styles.errorContainer}>
          <Text style={styles.errorTitle}>⚠️ Error</Text>
          <Text style={styles.errorMessage}>{loadError}</Text>
          <Text style={styles.errorHelp}>
            Failed to load the Jac app.{'\\n'}
            {devServerUrl
              ? `Make sure dev server is running at ${devServerUrl}`
              : 'Make sure the app was built correctly.'}
          </Text>
        </View>
      )}
      {renderWebView()}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#ffffff' },
  webview: { flex: 1 },
  loadingContainer: {
    position: 'absolute', top: 0, left: 0, right: 0, bottom: 0,
    justifyContent: 'center', alignItems: 'center',
    backgroundColor: '#ffffff', zIndex: 10,
  },
  loadingText: { marginTop: 16, fontSize: 18, fontWeight: '600', color: '#333' },
  urlText: { marginTop: 8, fontSize: 12, color: '#666' },
  errorContainer: {
    position: 'absolute', top: 0, left: 0, right: 0, bottom: 0,
    justifyContent: 'center', alignItems: 'center',
    backgroundColor: '#fff3cd', padding: 20, zIndex: 10,
  },
  errorTitle: { fontSize: 20, fontWeight: 'bold', color: '#856404', marginBottom: 12 },
  errorMessage: { fontSize: 16, color: '#856404', marginBottom: 16, textAlign: 'center' },
  errorHelp: {
    fontSize: 12, color: '#666', textAlign: 'center',
    fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace',
    backgroundColor: '#f8f9fa', padding: 12, borderRadius: 8,
  },
});
''';

    screen_path = mobile_dir / "app" / "index.tsx";
    with open(screen_path, "w") as f {
        f.write(screen_code);
    }
    console.print(f"  ✔ Generated app/index.tsx", style="success");
}

"""Generate assets/jac-app/create-bundle.js - the Node.js bundler script."""
def _generate_bundle_script(mobile_dir: Path) {
    script_code = '''const fs = require('fs');
const path = require('path');

const cssPath = path.join(__dirname, 'styles.css');
const jsPath = path.join(__dirname, 'client.js');
const htmlPath = path.join(__dirname, 'index.html');

if (!fs.existsSync(cssPath) || !fs.existsSync(jsPath) || !fs.existsSync(htmlPath)) {
    console.error('Missing required files. Please build the web app first.');
    process.exit(1);
}

const css = fs.readFileSync(cssPath, 'utf8');
const js = fs.readFileSync(jsPath, 'utf8');
const sourceHtml = fs.readFileSync(htmlPath, 'utf8');

// Extract __jac_init__ config from original HTML (s flag = dotAll for multiline)
const jacInitMatch = sourceHtml.match(/<script id="__jac_init__" type="application\\/json">(.*?)<\\/script>/s);
const jacInitConfig = jacInitMatch
    ? jacInitMatch[1].replace(/&quot;/g, '"')
    : '{"module":"main","function":"app","args":{},"argOrder":[],"globals":{}}';

const html = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width,initial-scale=1.0,maximum-scale=1.0,user-scalable=no" />
    <title>Jac Mobile App</title>
    <style>${css}</style>
</head>
<body>
    <div id="root"></div>
    <script id="__jac_init__" type="application/json">
    ${jacInitConfig}
    </script>
    <!-- Backend API URL placeholder - replaced at runtime by the mobile app -->
    <script>
        window.JAC_BACKEND_URL = '%%__JAC_BACKEND_URL__%%';
    </script>
    <!-- Jac client bundle loaded via blob URL to satisfy CSP -->
    <script>
    (function() {
        const jsCode = atob('${Buffer.from(js).toString('base64')}');
        const blob = new Blob([jsCode], { type: 'text/javascript' });
        const url = URL.createObjectURL(blob);
        const script = document.createElement('script');
        script.type = 'module';
        script.src = url;
        script.onload = function() { URL.revokeObjectURL(url); };
        script.onerror = function() { console.error('Failed to load Jac bundle'); };
        document.body.appendChild(script);
    })();
    </script>
</body>
</html>`;

fs.writeFileSync(path.join(__dirname, 'bundle.html'), html);
console.log('Created bundle.html');

// Escape backticks and $ signs so the string is safe inside a TS template literal
const tsContent = `// Auto-generated standalone Jac app bundle
export const JAC_BUNDLE_HTML = \\`${html.replace(/\\\\/g, '\\\\\\\\').replace(/`/g, '\\\\`').replace(/\\$/g, '\\\\$')}\\`;
`;

fs.writeFileSync(path.join(__dirname, 'bundle.ts'), tsContent);
console.log('Created bundle.ts');
console.log(`Bundle size: ${(html.length / 1024).toFixed(2)} KB`);
''';

    script_path = mobile_dir / "assets" / "jac-app" / "create-bundle.js";
    with open(script_path, "w") as f {
        f.write(script_code);
    }
    console.print(f"  ✔ Generated assets/jac-app/create-bundle.js", style="success");
}

"""Generate app/_layout.tsx for expo-router."""
def _generate_layout_file(mobile_dir: Path) {
    layout_code = '''import { Slot } from 'expo-router';

export default function RootLayout() {
  return <Slot />;
}
''';
    with open(mobile_dir / "app" / "_layout.tsx", "w") as f {
        f.write(layout_code);
    }
    console.print(f"  ✔ Generated app/_layout.tsx", style="success");
}

"""Append a [mobile] section to the project's jac.toml (skips if already present)."""
def _add_mobile_config(
    project_dir: Path, name: str, bundle_id: str, version: str
) -> None {
    toml_path = project_dir / "jac.toml";
    if not toml_path.exists() {
        console.warning(f"  jac.toml not found at {toml_path}");
        return;
    }
    toml_content = toml_path.read_text();
    if "[mobile]" in toml_content {
        console.print(f"  [mobile] section already exists in jac.toml", style="muted");
        return;
    }

    name_str = str(name);
    slug = name_str.lower().replace(" ", "-");
    scheme = name_str.lower().replace(" ", "").replace("-", "").replace("_", "");

    mobile_section = f'''

[mobile]
name = "{name}"
bundle_id = "{bundle_id}"
version = "{version}"
display_name = "{name}"
slug = "{slug}"
scheme = "{scheme}"

[mobile.platforms]
ios = true
android = true

[mobile.features]
use_sidecar = false
api_url = ""

[mobile.expo]
orientation = "portrait"
userInterfaceStyle = "light"
icon = "./assets/icon.png"

[mobile.expo.splash]
image = "./assets/splash.png"
resizeMode = "contain"
backgroundColor = "#ffffff"

[mobile.expo.ios]
supportsTablet = true

[mobile.expo.android.adaptiveIcon]
foregroundImage = "./assets/adaptive-icon.png"
backgroundColor = "#ffffff"

[mobile.expo.web]
favicon = "./assets/favicon.png"

[mobile.eas.profiles.development]
distribution = "internal"
developmentClient = true

[mobile.eas.profiles.preview]
distribution = "internal"

[mobile.eas.profiles.production]
distribution = "store"
''';

    with open(toml_path, "a") as f {
        f.write(mobile_section);
    }
    console.print(f"  ✔ Added [mobile] section to jac.toml", style="success");
}

"""Check that Node.js, yarn, and Expo CLI are available."""
def _check_mobile_dependencies {
    for (cmd, label, hint) in [
        (["node", "--version"], "Node.js", "Install from https://nodejs.org/"),
        (["yarn", "--version"], "yarn", "Install with: npm install -g yarn"),
        (["npx", "expo", "--version"], "Expo CLI", "Will be installed with yarn install"),
    ] {
        try {
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=10);
            if result.returncode == 0 {
                console.print(f"  ✔ {label}: {result.stdout.strip()}", style="success");
            } else {
                console.warning(f"  {label} not found. {hint}");
            }
        } except Exception {
            console.warning(f"  {label} not found. {hint}");
        }
    }
}

"""Run yarn install inside mobile_dir."""
def _install_yarn_dependencies(mobile_dir: Path) {
    try {
        process = subprocess.run(
            ["yarn", "install"], cwd=str(mobile_dir), timeout=300, text=True
        );
        if process.returncode == 0 {
            console.print(
                "  ✔ Dependencies installed successfully with yarn", style="success"
            );
        } else {
            raise RuntimeError(
                f"yarn install failed with exit code {process.returncode}"
            );
        }
    } except subprocess.TimeoutExpired {
        raise RuntimeError("yarn install timed out after 5 minutes");
    } except FileNotFoundError {
        raise RuntimeError("yarn not found. Install with: npm install -g yarn");
    } except Exception as e {
        raise RuntimeError(f"yarn install failed: {e}");
    }
}

"""Generate placeholder PNG icons for Expo (icon, splash, adaptive-icon, favicon)."""
def _generate_placeholder_icons(mobile_dir: Path) {
    assets_dir = mobile_dir / "assets";
    python_code = '''
import sys
try:
    from PIL import Image, ImageDraw
    img = Image.new("RGBA", (1024, 1024), (74, 144, 226, 255))
    draw = ImageDraw.Draw(img)
    draw.text((400, 400), "J", fill=(255, 255, 255, 255))
    img.save(sys.argv[1])
except ImportError:
    import struct, zlib
    width, height = 1024, 1024
    def pack_chunk(tag, data):
        chunk_head = tag + data
        return struct.pack("!I", len(data)) + chunk_head + struct.pack("!I", 0xFFFFFFFF & zlib.crc32(chunk_head))
    with open(sys.argv[1], "wb") as f:
        f.write(b"\\x89PNG\\r\\n\\x1a\\n")
        f.write(pack_chunk(b"IHDR", struct.pack("!2I5B", width, height, 8, 2, 0, 0, 0)))
        raw_data = b"\\x00" + (b"\\x4A\\x90\\xE2" * width)
        f.write(pack_chunk(b"IDAT", zlib.compress(raw_data * height)))
        f.write(pack_chunk(b"IEND", b""))
''';
    try {
        icon_path = assets_dir / "icon.png";
        subprocess.run(
            ["python3", "-c", python_code, str(icon_path)],
            capture_output=True, text=True, timeout=10
        );
        for icon_name in ["splash.png", "adaptive-icon.png", "favicon.png"] {
            shutil.copy2(icon_path, assets_dir / icon_name);
        }
        console.print(f"  ✔ Generated placeholder icons", style="success");
    } except Exception as e {
        console.warning(f"  Could not generate icons: {e}");
        console.print("  You can add custom icons later to assets/", style="muted");
    }
}

"""Generate mobile/.gitignore."""
def _generate_gitignore(mobile_dir: Path) {
    gitignore_content = """# Source files only — build artifacts live in .jac/mobile/

# node_modules symlink (points to .jac/mobile/node_modules for EAS)
node_modules/

# Environment files
.env.local
.env

# OS files
.DS_Store
*.pem

# Web bundle artifacts (generated in .jac/mobile/, copied here only for EAS)
assets/jac-app/bundle.html
assets/jac-app/bundle.ts
assets/jac-app/client.js
assets/jac-app/index.html
assets/jac-app/styles.css
""";
    with open(mobile_dir / ".gitignore", "w") as f {
        f.write(gitignore_content);
    }
    console.print(f"  ✔ Generated .gitignore", style="success");
}
