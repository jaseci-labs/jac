"""Implementation of MobileTarget methods."""
import from pathlib { Path }
import from typing { Optional, Any }
import from jaclang.cli.console { console }
import from jaclang.project.config { get_config }
import from jac_client.plugin.src.config_loader { JacClientConfig }
import from jac_client.plugin.src.vite_bundler { API_BASE_URL_ENV_VAR }
import subprocess;
import json;
import shutil;
import os;
import platform;

def _make_localhost_url(port: int) -> str {
    return f"http://127.0.0.1:{port}";
}

def _get_toml_api_base_url(project_dir: Path) -> str {
    config_loader = JacClientConfig(project_dir);
    return config_loader.get_api_config().get('base_url', '');
}

"""Get local network IP address for mobile dev server."""
def _get_local_ip() -> str {
    import socket;

    try {
        # Create a socket to determine the local IP
        # We connect to an external address (doesn't actually connect)
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM);
        s.settimeout(0);
        try {
            # Connect to a public DNS server to find local IP
            s.connect(('8.8.8.8', 80));
            local_ip = s.getsockname()[0];
        } finally {
            s.close();
        }
        return local_ip;
    } except Exception {
        # Fallback to localhost if detection fails
        return '127.0.0.1';
    }
}

"""Setup mobile target - scaffold React Native/Expo project structure."""
impl MobileTarget.setup(project_dir: Path) -> None {
    # Define mobile_dir - at top level for source files ONLY
    # Build artifacts will be in .jac/mobile/
    mobile_dir = project_dir / "mobile";

    console.print("\n📱 Setting up mobile target (React Native/Expo)", style="bold");
    console.print(f"  Project directory: {project_dir}", style="muted");
    console.print(f"  Source directory: {mobile_dir.relative_to(project_dir)}", style="muted");
    console.print(f"  Build artifacts: .jac/mobile/ (not tracked in git)", style="muted");

    # Check if already set up
    if mobile_dir.exists() {
        console.warning("Mobile target already set up. Skipping...");
        return;
    }

    # Ensure project directory exists
    if not project_dir.exists() {
        try {
            project_dir.mkdir(parents=True, exist_ok=True);
        } except Exception as e {
            raise RuntimeError(f"Failed to create project directory: {e}") ;
        }
    }

    # Create mobile directory structure
    console.print("  Creating mobile/ directory structure...", style="muted");
    try {
        mobile_dir.mkdir(parents=True, exist_ok=True);
        (mobile_dir / "app").mkdir(exist_ok=True);
        (mobile_dir / "assets").mkdir(exist_ok=True);
        (mobile_dir / "assets" / "jac-app").mkdir(exist_ok=True);
        console.print(f"  ✔ Created {mobile_dir}", style="success");
    } except Exception as e {
        raise RuntimeError(f"Failed to create mobile directory: {e}") ;
    }

    # Wrap rest of setup in try-finally
    try {
        # Import mobile config
        import from jac_client.plugin.src.mobile_config { MobileConfig }

        # Load mobile config (will use defaults if [mobile] section doesn't exist)
        try {
            mobile_config = MobileConfig(project_dir=project_dir);
            config_data = mobile_config.load();

            project_name = config_data.get('name', 'my-jac-app');
            project_version = config_data.get('version', '1.0.0');
            bundle_id = config_data.get('bundle_id', 'com.example.myjacapp');
            display_name = config_data.get('display_name', project_name);
        } except Exception as e {
            console.warning(f"  Failed to load mobile config: {e}, using defaults");
            project_name = 'my-jac-app';
            project_version = '1.0.0';
            bundle_id = 'com.example.myjacapp';
            display_name = project_name;
        }

        console.print(
            f"  Project name: {project_name}, version: {project_version}",
            style="muted"
        );
        console.print(f"  Bundle ID: {bundle_id}", style="muted");

        # Generate app.json from TOML config
        try {
            _generate_app_json_from_toml(mobile_dir, project_dir);
        } except Exception as e {
            console.warning(f"  Failed to generate app.json: {e}");
        }

        # Generate package.json
        try {
            _generate_package_json(mobile_dir, project_name);
        } except Exception as e {
            console.warning(f"  Failed to generate package.json: {e}");
        }

        # Generate TypeScript config
        try {
            _generate_tsconfig(mobile_dir);
        } except Exception as e {
            console.warning(f"  Failed to generate tsconfig.json: {e}");
        }

        # Generate React Native screen
        try {
            _generate_webview_screen(mobile_dir);
        } except Exception as e {
            console.warning(f"  Failed to generate WebView screen: {e}");
        }

        # Generate bundle creation script
        try {
            _generate_bundle_script(mobile_dir);
        } except Exception as e {
            console.warning(f"  Failed to generate bundle script: {e}");
        }

        # Generate _layout.tsx
        try {
            _generate_layout_file(mobile_dir);
        } except Exception as e {
            console.warning(f"  Failed to generate _layout.tsx: {e}");
        }

        # Add [mobile] section to jac.toml
        try {
            _add_mobile_config(project_dir, project_name, bundle_id, project_version);
        } except Exception as e {
            console.warning(f"  Failed to add [mobile] section to jac.toml: {e}");
        }

        # Generate placeholder icons
        try {
            _generate_placeholder_icons(mobile_dir);
        } except Exception as e {
            console.warning(f"  Failed to generate placeholder icons: {e}");
        }

        # Generate .gitignore
        try {
            _generate_gitignore(mobile_dir);
        } except Exception as e {
            console.warning(f"  Failed to generate .gitignore: {e}");
        }

        # Check dependencies
        console.print("\n📦 Checking required dependencies...", style="bold");
        try {
            _check_mobile_dependencies();
        } except Exception as e {
            console.warning(f"  Dependency check encountered an issue: {e}");
        }

        # Don't install dependencies during setup - they'll be in .jac/mobile/
        console.success("Mobile target setup complete!");
        console.print("\n💡 Source files created in mobile/ directory", style="bold");
        console.print("   Dependencies & bundles will be in .jac/mobile/ during build/dev", style="muted");
        console.print("\nNext steps:", style="bold");
        console.print("  1. Build: jac build main.jac --client mobile", style="muted");
        console.print("             (you'll be prompted for platform and build profile)", style="muted");
        console.print("     Or use flags:", style="muted");
        console.print("       jac build main.jac --client mobile -p android -b development", style="muted");
        console.print("       jac build main.jac --client mobile -p ios -b production", style="muted");
        console.print("       jac build main.jac --client mobile -p all -b preview", style="muted");
        console.print("\n  2. Dev:   jac start main.jac --client mobile --dev", style="muted");
    } finally {
        # Ensure mobile directory exists no matter what
        if not mobile_dir.exists() {
            try {
                mobile_dir.mkdir(parents=True, exist_ok=True);
                console.print(f"  ✔ Ensured {mobile_dir} exists", style="success");
            } except Exception as e {
                console.error(f"  CRITICAL: Could not create mobile directory: {e}");
            }
        }
    }
}

"""Generate app.json from TOML configuration."""
def _generate_app_json_from_toml(mobile_dir: Path, project_dir: Path) -> None {
    import from jac_client.plugin.src.mobile_config { MobileConfig }

    # Load mobile config from jac.toml
    mobile_config = MobileConfig(project_dir=project_dir);
    app_json_config = mobile_config.get_app_json_config();

    config_path = mobile_dir / "app.json";
    with open(config_path, "w") as f {
        json.dump(app_json_config, f, indent=2);
    }
    console.print(f"  ✔ Generated app.json from TOML config", style="success");
}

"""Generate app.json for Expo (legacy - kept for backwards compatibility)."""
def _generate_app_json(
    mobile_dir: Path, name: str, bundle_id: str, version: str, display_name: str
) -> None {
    # Generate scheme from name (lowercase, no special chars)
    scheme = name.lower().replace(" ", "").replace("-", "").replace("_", "");

    config = {
        "expo": {
            "name": display_name,
            "slug": name.lower().replace(" ", "-"),
            "scheme": scheme,
            "version": version,
            "orientation": "portrait",
            "icon": "./assets/icon.png",
            "userInterfaceStyle": "light",
            "splash": {
                "image": "./assets/splash.png",
                "resizeMode": "contain",
                "backgroundColor": "#ffffff"
            },
            "ios": {
                "supportsTablet": True,
                "bundleIdentifier": bundle_id
            },
            "android": {
                "adaptiveIcon": {
                    "foregroundImage": "./assets/adaptive-icon.png",
                    "backgroundColor": "#ffffff"
                },
                "package": bundle_id
            },
            "web": {
                "favicon": "./assets/favicon.png"
            },
            "plugins": ["expo-router"]
        }
    };

    config_path = mobile_dir / "app.json";
    with open(config_path, "w") as f {
        json.dump(config, f, indent=2);
    }
    console.print(f"  ✔ Generated app.json", style="success");
}

"""Generate package.json for React Native."""
def _generate_package_json(mobile_dir: Path, name: str) -> None {
    package_name = name.lower().replace(" ", "-");

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

    package_path = mobile_dir / "package.json";
    with open(package_path, "w") as f {
        json.dump(package_json, f, indent=2);
    }
    console.print(f"  ✔ Generated package.json", style="success");
}

"""Generate tsconfig.json."""
def _generate_tsconfig(mobile_dir: Path) -> None {
    tsconfig = {
        "extends": "expo/tsconfig.base",
        "compilerOptions": {
            "strict": True
        }
    };

    tsconfig_path = mobile_dir / "tsconfig.json";
    with open(tsconfig_path, "w") as f {
        json.dump(tsconfig, f, indent=2);
    }
    console.print(f"  ✔ Generated tsconfig.json", style="success");
}

"""Generate WebView screen component."""
def _generate_webview_screen(mobile_dir: Path) -> None {
    screen_code = '''import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, Platform, ActivityIndicator } from 'react-native';
import { WebView } from 'react-native-webview';

// Dev mode: load from Vite dev server for HMR
// Production: load from bundled HTML
const USE_DEV_SERVER = __DEV__ && false; // Set to true for dev server mode

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
let DEV_CONFIG = { localIP: '127.0.0.1' };
try {
  const config = require('../dev-config.json');
  DEV_CONFIG = config;
} catch (e) {
  console.warn('Dev config not found, using defaults');
}

// Configuration for URLs
const getDevServerUrl = () => {
  const localIP = DEV_CONFIG.localIP || '127.0.0.1';
  return `http://${localIP}:5173`;
};

const getBackendApiUrl = () => {
  if (__DEV__) {
    if (Platform.OS === 'android') {
      return 'http://10.0.2.2:9000';
    }
    // Use local network IP for iOS
    const localIP = DEV_CONFIG.localIP || '127.0.0.1';
    return `http://${localIP}:9000`;
  }
  return 'https://your-production-url.com';
};

export default function JacWebViewScreen() {
  const [isLoading, setIsLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [htmlContent, setHtmlContent] = useState<string>('');
  const [devServerUrl, setDevServerUrl] = useState<string>('');
  const backendApiUrl = getBackendApiUrl();

  useEffect(() => {
    if (USE_DEV_SERVER || !JAC_BUNDLE_HTML) {
      // Dev mode: use Vite dev server
      setDevServerUrl(getDevServerUrl());
      setIsLoading(false);
    } else {
      // Production mode: use bundled HTML
      prepareBundle();
    }
  }, []);

  const prepareBundle = () => {
    try {
      if (!JAC_BUNDLE_HTML) {
        throw new Error('Bundle not available');
      }
      // Inject the backend API URL into the bundle
      const html = JAC_BUNDLE_HTML.replace(
        `window.JAC_BACKEND_URL = window.JAC_BACKEND_URL || 'http://localhost:9000';`,
        `window.JAC_BACKEND_URL = '${backendApiUrl}';`
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
      // Dev mode: load from Vite dev server
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
              window.addEventListener('error', function(e) {
                console.error('Error:', e.message);
              });
              window.addEventListener('unhandledrejection', function(e) {
                console.error('Unhandled rejection:', e.reason);
              });
            })();
            true;
          `}
        />
      );
    } else if (htmlContent) {
      // Production mode: load from bundled HTML
      return (
        <WebView
          source={{
            html: htmlContent,
            baseUrl: 'http://localhost/'
          }}
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
              window.addEventListener('error', function(e) {
                console.error('Error:', e.message);
              });
              window.addEventListener('unhandledrejection', function(e) {
                console.error('Unhandled rejection:', e.reason);
              });
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
  container: {
    flex: 1,
    backgroundColor: '#ffffff',
  },
  webview: {
    flex: 1,
  },
  loadingContainer: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#ffffff',
    zIndex: 10,
  },
  loadingText: {
    marginTop: 16,
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
  },
  urlText: {
    marginTop: 8,
    fontSize: 12,
    color: '#666',
  },
  errorContainer: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#fff3cd',
    padding: 20,
    zIndex: 10,
  },
  errorTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#856404',
    marginBottom: 12,
  },
  errorMessage: {
    fontSize: 16,
    color: '#856404',
    marginBottom: 16,
    textAlign: 'center',
  },
  errorHelp: {
    fontSize: 12,
    color: '#666',
    textAlign: 'center',
    fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace',
    backgroundColor: '#f8f9fa',
    padding: 12,
    borderRadius: 8,
  },
});
''';

    screen_path = mobile_dir / "app" / "index.tsx";
    with open(screen_path, "w") as f {
        f.write(screen_code);
    }
    console.print(f"  ✔ Generated app/index.tsx", style="success");
}

"""Generate bundle creation script."""
def _generate_bundle_script(mobile_dir: Path) -> None {
    script_code = '''const fs = require('fs');
const path = require('path');

// Read the built files
const cssPath = path.join(__dirname, 'styles.css');
const jsPath = path.join(__dirname, 'client.js');
const htmlPath = path.join(__dirname, 'index.html');

if (!fs.existsSync(cssPath) || !fs.existsSync(jsPath) || !fs.existsSync(htmlPath)) {
    console.error('❌ Missing required files. Please build the web app first.');
    process.exit(1);
}

const css = fs.readFileSync(cssPath, 'utf8');
const js = fs.readFileSync(jsPath, 'utf8');
const sourceHtml = fs.readFileSync(htmlPath, 'utf8');

// Extract __jac_init__ config from original HTML
const jacInitMatch = sourceHtml.match(/<script id="__jac_init__" type="application\\/json">(.*?)<\\/script>/);
const jacInitConfig = jacInitMatch ? jacInitMatch[1].replace(/&quot;/g, '"') : '{"module": "main", "function": "app", "args": {}, "argOrder": [], "globals": {}}';

// Create a complete standalone HTML
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

    <!-- Jac initialization config -->
    <script id="__jac_init__" type="application/json">
    ${jacInitConfig}
    </script>

    <!-- Backend API URL - will be injected by mobile app -->
    <script>
        window.JAC_BACKEND_URL = window.JAC_BACKEND_URL || 'http://localhost:9000';
    </script>

    <!-- Jac client bundle as blob URL -->
    <script>
    (function() {
        const jsCode = atob('${Buffer.from(js).toString('base64')}');
        const blob = new Blob([jsCode], { type: 'text/javascript' });
        const url = URL.createObjectURL(blob);
        const script = document.createElement('script');
        script.type = 'module';
        script.src = url;
        script.onload = function() {
            URL.revokeObjectURL(url);
        };
        script.onerror = function(e) {
            console.error('Failed to load Jac bundle');
        };
        document.body.appendChild(script);
    })();
    </script>
</body>
</html>`;

// Write standalone HTML file
fs.writeFileSync(path.join(__dirname, 'bundle.html'), html);
console.log('✓ Created bundle.html');

// Also create TypeScript export
const tsContent = `// Auto-generated standalone Jac app bundle
export const JAC_BUNDLE_HTML = \\`${html.replace(/`/g, '\\\\`').replace(/\\$/g, '\\\\$')}\\`;
`;

fs.writeFileSync(path.join(__dirname, 'bundle.ts'), tsContent);
console.log('✓ Created bundle.ts');
console.log(`Bundle size: ${(html.length / 1024).toFixed(2)} KB`);
''';

    script_path = mobile_dir / "assets" / "jac-app" / "create-bundle.js";
    with open(script_path, "w") as f {
        f.write(script_code);
    }
    console.print(f"  ✔ Generated assets/jac-app/create-bundle.js", style="success");
}

"""Generate _layout.tsx for expo-router."""
def _generate_layout_file(mobile_dir: Path) -> None {
    layout_code = '''import { Slot } from 'expo-router';

export default function RootLayout() {
  return <Slot />;
}
''';

    layout_path = mobile_dir / "app" / "_layout.tsx";
    with open(layout_path, "w") as f {
        f.write(layout_code);
    }
    console.print(f"  ✔ Generated app/_layout.tsx", style="success");
}

"""Add [mobile] section to jac.toml."""
def _add_mobile_config(
    project_dir: Path, name: str, bundle_id: str, version: str
) -> None {
    toml_path = project_dir / "jac.toml";

    if not toml_path.exists() {
        console.warning(f"  jac.toml not found at {toml_path}");
        return;
    }

    # Read existing TOML
    toml_content = toml_path.read_text();

    # Check if [mobile] section already exists
    if "[mobile]" in toml_content {
        console.print(f"  [mobile] section already exists in jac.toml", style="muted");
        return;
    }

    # Add [mobile] section with full Expo configuration
    # Generate slug and scheme from name
    slug = name.lower().replace(" ", "-");
    scheme = name.lower().replace(" ", "").replace("-", "").replace("_", "");

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

# Expo app configuration (generates app.json)
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

# EAS Build profiles (generates eas.json)
[mobile.eas.profiles.development]
distribution = "internal"
developmentClient = true

[mobile.eas.profiles.preview]
distribution = "internal"

[mobile.eas.profiles.production]
distribution = "store"
''';

    # Append to TOML
    with open(toml_path, "a") as f {
        f.write(mobile_section);
    }

    console.print(f"  ✔ Added [mobile] section to jac.toml", style="success");
}

"""Check for required mobile dependencies."""
def _check_mobile_dependencies() -> None {
    # Check for Node.js
    try {
        result = subprocess.run(
            ["node", "--version"], capture_output=True, text=True, timeout=5
        );
        if result.returncode == 0 {
            console.print(f"  ✔ Node.js: {result.stdout.strip()}", style="success");
        } else {
            console.warning("  Node.js not found. Install from https://nodejs.org/");
        }
    } except Exception {
        console.warning("  Node.js not found. Install from https://nodejs.org/");
    }

    # Check for yarn
    try {
        result = subprocess.run(
            ["yarn", "--version"], capture_output=True, text=True, timeout=5
        );
        if result.returncode == 0 {
            console.print(f"  ✔ yarn: v{result.stdout.strip()}", style="success");
        } else {
            console.warning("  yarn not found. Install with: npm install -g yarn");
        }
    } except Exception {
        console.warning("  yarn not found. Install with: npm install -g yarn");
    }

    # Check for Expo CLI (optional, will be installed locally)
    try {
        result = subprocess.run(
            ["npx", "expo", "--version"], capture_output=True, text=True, timeout=10
        );
        if result.returncode == 0 {
            console.print(f"  ✔ Expo CLI available", style="success");
        } else {
            console.print(
                "  ℹ Expo CLI will be installed with yarn install", style="muted"
            );
        }
    } except Exception {
        console.print("  ℹ Expo CLI will be installed with yarn install", style="muted");
    }
}

"""Install dependencies for mobile project using yarn."""
def _install_yarn_dependencies(mobile_dir: Path) -> None {
    try {
        # Run yarn install with real-time output
        process = subprocess.run(
            ["yarn", "install"],
            cwd=str(mobile_dir),
            timeout=300,
            text=True
        );

        if process.returncode == 0 {
            console.print("  ✔ Dependencies installed successfully with yarn", style="success");
        } else {
            raise RuntimeError(f"yarn install failed with exit code {process.returncode}") ;
        }
    } except subprocess.TimeoutExpired {
        raise RuntimeError("yarn install timed out after 5 minutes") ;
    } except FileNotFoundError {
        raise RuntimeError("yarn not found. Install with: npm install -g yarn") ;
    } except Exception as e {
        raise RuntimeError(f"yarn install failed: {e}") ;
    }
}

"""Generate placeholder icon files for Expo."""
def _generate_placeholder_icons(mobile_dir: Path) -> None {
    assets_dir = mobile_dir / "assets";

    # Create a minimal 1024x1024 PNG icon using Python
    try {
        import subprocess;
        # Try to create icon using Python PIL
        python_code = '''
import sys
try:
    from PIL import Image, ImageDraw
    img = Image.new("RGBA", (1024, 1024), (74, 144, 226, 255))
    draw = ImageDraw.Draw(img)
    # Draw simple "J" for Jac
    draw.text((400, 400), "J", fill=(255, 255, 255, 255))
    img.save(sys.argv[1])
    print("Created with PIL")
except ImportError:
    # Fallback: create minimal valid PNG
    import struct
    width, height = 1024, 1024
    def png_pack(png_tag, data):
        chunk_head = png_tag + data
        return struct.pack("!I", len(data)) + chunk_head + struct.pack("!I", 0xFFFFFFFF & __import__("zlib").crc32(chunk_head))

    with open(sys.argv[1], "wb") as f:
        f.write(b"\\x89PNG\\r\\n\\x1a\\n")
        f.write(png_pack(b"IHDR", struct.pack("!2I5B", width, height, 8, 2, 0, 0, 0)))
        # Single blue pixel data
        raw_data = b"\\x00" + (b"\\x4A\\x90\\xE2" * width)
        import zlib
        f.write(png_pack(b"IDAT", zlib.compress(raw_data * height)))
        f.write(png_pack(b"IEND", b""))
    print("Created minimal PNG")
''';

        # Create icon.png
        icon_path = assets_dir / "icon.png";
        result = subprocess.run(
            ["python3", "-c", python_code, str(icon_path)],
            capture_output=True,
            text=True,
            timeout=10
        );

        # Create other required icons
        for icon_name in ["splash.png", "adaptive-icon.png", "favicon.png"] {
            target_path = assets_dir / icon_name;
            shutil.copy2(icon_path, target_path);
        }

        console.print(f"  ✔ Generated placeholder icons", style="success");
    } except Exception as e {
        console.warning(f"  Could not generate icons: {e}");
        console.print("  You can add custom icons later to assets/", style="muted");
    }
}

"""Generate .gitignore file for mobile directory."""
def _generate_gitignore(mobile_dir: Path) -> None {
    gitignore_content = """# This directory contains SOURCE files only
# All build artifacts (node_modules, bundles) are in .jac/mobile/

# node_modules symlink (points to .jac/mobile/node_modules for EAS verification)
node_modules/

# Environment files
.env.local
.env

# OS files
.DS_Store
*.pem

# Jac web bundle artifacts (temporarily copied here for EAS builds)
# These are generated in .jac/mobile/ and copied here only for EAS git upload
assets/jac-app/bundle.html
assets/jac-app/bundle.ts
assets/jac-app/client.js
assets/jac-app/index.html
assets/jac-app/styles.css
""";

    gitignore_path = mobile_dir / ".gitignore";
    with open(gitignore_path, "w") as f {
        f.write(gitignore_content);
    }
    console.print(f"  ✔ Generated .gitignore", style="success");
}

"""Prepare build directory by copying source and installing deps in .jac/mobile/."""
def _prepare_build_dir(mobile_src_dir: Path, mobile_build_dir: Path) -> None {
    console.print("  Preparing build directory...", style="muted");

    # Create build directory
    mobile_build_dir.mkdir(parents=True, exist_ok=True);

    # Copy source files from mobile/ to .jac/mobile/
    source_files = ["app.json", "package.json", "tsconfig.json"];
    for file_name in source_files {
        src_file = mobile_src_dir / file_name;
        if src_file.exists() {
            shutil.copy2(src_file, mobile_build_dir / file_name);
        }
    }

    # Copy directories
    source_dirs = ["app", "assets"];
    for dir_name in source_dirs {
        src_dir = mobile_src_dir / dir_name;
        dst_dir = mobile_build_dir / dir_name;
        if src_dir.exists() {
            if dst_dir.exists() {
                shutil.rmtree(dst_dir);
            }
            shutil.copytree(src_dir, dst_dir);
        }
    }

    console.print("  ✔ Source files copied to .jac/mobile/", style="success");

    # Install dependencies if needed
    if not (mobile_build_dir / "node_modules").exists() {
        console.print("  Installing dependencies in .jac/mobile/...", style="muted");
        try {
            _install_yarn_dependencies(mobile_build_dir);
        } except Exception as e {
            console.warning(f"  Failed to install dependencies: {e}");
            raise;
        }
    } else {
        console.print("  ✔ Dependencies already installed", style="success");
    }
}

"""Copy bundles from .jac/mobile/ to mobile/ for EAS."""
def _copy_bundles_for_eas(mobile_build_dir: Path, mobile_src_dir: Path) -> None {
    build_assets = mobile_build_dir / "assets" / "jac-app";
    src_assets = mobile_src_dir / "assets" / "jac-app";

    # Ensure destination exists
    src_assets.mkdir(parents=True, exist_ok=True);

    # Copy generated bundle files
    bundle_files = ["bundle.html", "bundle.ts", "client.js", "index.html", "styles.css"];
    for file_name in bundle_files {
        src_file = build_assets / file_name;
        if src_file.exists() {
            shutil.copy2(src_file, src_assets / file_name);
        }
    }

    console.print("  ✔ Bundles copied to mobile/ for EAS", style="success");
}

"""Build mobile app - build web bundle first, then wrap with React Native."""
impl MobileTarget.build(
    entry_file: Path,
    project_dir: Path,
    platform: Optional[str] = None,
    build_type: str = "production",
    use_eas: bool = True
) -> Path {
    import from jac_client.plugin.src.vite_bundler { ViteBundler }
    console.print("\n📱 Building mobile app (React Native)", style="bold");

    # Check if setup has been run
    mobile_src_dir = project_dir / "mobile";
    if not mobile_src_dir.exists() {
        raise RuntimeError(
            "Mobile target not set up. Run 'jac setup mobile' first."
        ) ;
    }

    # Build directory in .jac/mobile/
    mobile_build_dir = project_dir / ".jac" / "mobile";

    # Step 1: Prepare build directory (copy source + install deps in .jac/mobile/)
    console.print("  Step 1: Preparing build directory...", style="muted");
    _prepare_build_dir(mobile_src_dir, mobile_build_dir);

    # Step 2: Build web bundle
    console.print("  Step 2: Building web bundle...", style="muted");
    web_bundle_path = super.build(entry_file, project_dir, platform);
    console.print(f"  ✔ Web bundle built: {web_bundle_path}", style="success");

    # Step 3: Copy web bundle to .jac/mobile/assets/jac-app/
    console.print("  Step 3: Copying web bundle to build directory...", style="muted");
    _copy_web_bundle_to_mobile(web_bundle_path, mobile_build_dir);

    # Step 4: Generate mobile bundle in .jac/mobile/
    console.print("  Step 4: Creating mobile bundle...", style="muted");
    _create_mobile_bundle(mobile_build_dir);

    # Step 5: Build with EAS
    if use_eas {
        console.print(f"  Step 5: Preparing for EAS build...", style="muted");

        # Copy bundles from .jac/mobile/ to mobile/ for EAS
        console.print("  Copying bundles to source directory for EAS...", style="muted");
        _copy_bundles_for_eas(mobile_build_dir, mobile_src_dir);

        # Generate/update eas.json in source directory
        try {
            _generate_eas_json(mobile_src_dir, project_dir);
        } except Exception as e {
            console.warning(f"  Failed to generate eas.json: {e}");
        }

        # For development builds, symlink node_modules so EAS can verify expo-dev-client
        # EAS will install its own fresh node_modules on cloud, but needs local verification
        node_modules_link = mobile_src_dir / "node_modules";
        node_modules_src = mobile_build_dir / "node_modules";

        if build_type == "development" and not node_modules_link.exists() {
            console.print("  Creating symlink to node_modules for EAS verification...", style="muted");
            try {
                import os;
                os.symlink(node_modules_src, node_modules_link, target_is_directory=True);
                console.print("  ✔ Symlink created", style="success");
            } except Exception as e {
                console.warning(f"  Could not create symlink: {e}");
            }
        }

        try {
            console.print(f"  Building with EAS...", style="muted");
            build_info = _build_with_eas(
                mobile_src_dir,
                project_dir,
                build_type,
                platform or "android"
            );

            console.success("Mobile app submitted to EAS!");
        } finally {
            # Clean up symlink after EAS build
            if node_modules_link.exists() and node_modules_link.is_symlink() {
                console.print("  Cleaning up symlink...", style="muted");
                node_modules_link.unlink();
            }
        }
        console.print(f"\n📊 Build Information:", style="bold");
        console.print(f"  Build ID: {build_info['build_id']}", style="muted");
        console.print(f"  Build URL: {build_info['build_url']}", style="muted");
        console.print(f"  Expected artifact: {build_info['artifact_type']}", style="muted");
        console.print(f"\n💡 Monitor your build at: {build_info['build_url']}", style="bold");
    } else {
        console.print("  Step 5: Skipping EAS build...", style="muted");
        console.success("Mobile app bundle created successfully!");
        console.print(f"  Build directory: {mobile_build_dir}", style="muted");
        console.print(f"\n💡 For native builds, re-run with EAS enabled", style="muted");
    }

    return mobile_build_dir;
}

"""Copy web bundle files to mobile assets directory."""
def _copy_web_bundle_to_mobile(web_bundle_path: Path, mobile_dir: Path) -> None {
    assets_dir = mobile_dir / "assets" / "jac-app";

    # Find the built files in web bundle
    dist_dir = web_bundle_path;
    if not dist_dir.is_dir() {
        dist_dir = web_bundle_path.parent;
    }

    # Copy index.html
    html_file = dist_dir / "index.html";
    if html_file.exists() {
        shutil.copy2(html_file, assets_dir / "index.html");
        console.print(f"    ✔ Copied index.html", style="success");
    } else {
        raise RuntimeError(f"index.html not found in {dist_dir}") ;
    }

    # Find and copy CSS file
    css_files = list(dist_dir.glob("*.css"));
    if css_files {
        # Use the first CSS file found
        shutil.copy2(css_files[0], assets_dir / "styles.css");
        console.print(f"    ✔ Copied {css_files[0].name} as styles.css", style="success");
    } else {
        console.warning("    No CSS file found, creating empty styles.css");
        (assets_dir / "styles.css").write_text("");
    }

    # Find and copy JS file
    js_files = list(dist_dir.glob("*.js"));
    if js_files {
        # Find the main client JS file (usually the largest)
        main_js = js_files[0];
        max_size = 0;
        for js_file in js_files {
            file_size = js_file.stat().st_size;
            if file_size > max_size {
                max_size = file_size;
                main_js = js_file;
            }
        }
        shutil.copy2(main_js, assets_dir / "client.js");
        console.print(f"    ✔ Copied {main_js.name} as client.js", style="success");
    } else {
        raise RuntimeError(f"No JavaScript files found in {dist_dir}") ;
    }
}

"""Create mobile bundle using Node.js script."""
def _create_mobile_bundle(mobile_dir: Path) -> None {
    script_path = mobile_dir / "assets" / "jac-app" / "create-bundle.js";

    if not script_path.exists() {
        raise RuntimeError(f"Bundle script not found: {script_path}") ;
    }

    # Run the bundle creation script
    try {
        result = subprocess.run(
            ["node", str(script_path)],
            cwd=str(script_path.parent),
            capture_output=True,
            text=True,
            timeout=30
        );

        if result.returncode != 0 {
            console.error(f"  Bundle creation failed: {result.stderr}");
            raise RuntimeError(f"Bundle creation failed: {result.stderr}") ;
        }

        console.print(f"  {result.stdout.strip()}", style="success");
    } except subprocess.TimeoutExpired {
        raise RuntimeError("Bundle creation timed out") ;
    } except Exception as e {
        raise RuntimeError(f"Failed to create bundle: {e}") ;
    }
}

"""Build mobile app for production."""
def _build_mobile_app(mobile_dir: Path, platform: str) -> None {
    console.print(f"  Building for {platform} (this may take several minutes)...", style="muted");

    # Check if node_modules exists
    if not (mobile_dir / "node_modules").exists() {
        console.warning("  node_modules not found, running yarn install first...");
        try {
            subprocess.run(
                ["yarn", "install"],
                cwd=str(mobile_dir),
                check=True,
                timeout=300,
                text=True
            );
        } except Exception as e {
            raise RuntimeError(f"yarn install failed: {e}") ;
        }
    }

    # Build using Expo
    try {
        if platform == "ios" {
            console.print("  Building iOS app (requires Mac with Xcode)...", style="muted");
            subprocess.run(
                ["npx", "expo", "build:ios"],
                cwd=str(mobile_dir),
                check=True
            );
        } elif platform == "android" {
            console.print("  Building Android app...", style="muted");
            subprocess.run(
                ["npx", "expo", "build:android"],
                cwd=str(mobile_dir),
                check=True
            );
        } else {
            console.warning(f"  Unknown platform: {platform}, skipping native build");
        }
    } except Exception as e {
        console.warning(f"  Native build failed: {e}");
        console.print("  Note: Use 'expo build:ios' or 'expo build:android' manually", style="muted");
    }
}

"""Write dev configuration file with local IP for mobile app."""
def _write_dev_config(mobile_dir: Path, local_ip: str) -> None {
    dev_config = {
        'localIP': local_ip
    };

    dev_config_path = mobile_dir / "dev-config.json";
    with open(dev_config_path, "w") as f {
        json.dump(dev_config, f, indent=2);
    }
    console.print(f"  ✔ Dev config written (IP: {local_ip})", style="success");
}

"""Start mobile dev server - start web dev server and launch Expo dev."""
impl MobileTarget.dev(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    import signal;
    import sys;
    console.print("\n📱 Starting mobile dev server (Expo)", style="bold");

    # Check if setup has been run
    mobile_src_dir = project_dir / "mobile";
    if not mobile_src_dir.exists() {
        raise RuntimeError(
            "Mobile target not set up. Run 'jac setup mobile' first."
        ) ;
    }

    # Build directory in .jac/mobile/
    mobile_build_dir = project_dir / ".jac" / "mobile";

    # Prepare build directory
    _prepare_build_dir(mobile_src_dir, mobile_build_dir);

    # Detect local IP and write dev config
    local_ip = _get_local_ip();
    console.print(f"  Detected local IP: {local_ip}", style="muted");
    _write_dev_config(mobile_build_dir, local_ip);

    # Step 1: Build web bundle for dev (for bundled mode)
    console.print("  Step 1: Building web bundle for bundled mode...", style="muted");
    web_bundle_path = super.build(entry_file, project_dir, None);
    console.print(f"  ✔ Web bundle built", style="success");

    # Step 2: Copy and create mobile bundle in .jac/mobile/
    console.print("  Step 2: Creating mobile bundle...", style="muted");
    _copy_web_bundle_to_mobile(web_bundle_path, mobile_build_dir);
    _create_mobile_bundle(mobile_build_dir);

    # Step 3: Start Vite dev server (for HMR mode)
    console.print("  Step 3: Starting Vite dev server on port 5173...", style="muted");
    vite_process = _start_vite_dev_server(entry_file, project_dir, api_port);
    console.print(f"  ✔ Vite dev server running", style="success");

    # Step 4: Start backend server
    console.print(f"  Step 4: Starting backend server on port {api_port}...", style="muted");
    server_process = _start_backend_server(entry_file, project_dir, api_port);
    console.print(f"  ✔ Backend server starting on port {api_port}", style="success");

    # Step 5: Start Expo dev server
    console.print("  Step 5: Starting Expo dev server...", style="muted");
    console.print("  (Press Ctrl+C to stop)", style="muted");

    expo_process = None;
    def cleanup -> None {
        console.print("\n  Stopping dev servers...", style="muted");
        if expo_process {
            try {
                expo_process.terminate();
                expo_process.wait(timeout=5);
            } except Exception {
                expo_process.kill();
            }
        }
        if vite_process {
            try {
                vite_process.terminate();
                vite_process.wait(timeout=5);
            } except Exception {
                vite_process.kill();
            }
        }
        if server_process {
            try {
                server_process.terminate();
                server_process.wait(timeout=5);
            } except Exception {
                server_process.kill();
            }
        }
        console.print("  ✔ Dev servers stopped", style="success");
    }

    def signal_handler(signum: int, frame: Any) -> None {
        cleanup();
        sys.exit(0);
    }

    signal.signal(signal.SIGINT, signal_handler);
    signal.signal(signal.SIGTERM, signal_handler);

    try {
        # Start Expo dev server from .jac/mobile/
        expo_process = subprocess.Popen(
            ["npx", "expo", "start"],
            cwd=str(mobile_build_dir)
        );

        console.success("Expo dev server started!");
        console.print("  Scan QR code with Expo Go app to test on device", style="muted");
        console.print(f"\n  🌐 Dev Server URLs (using IP: {local_ip}):", style="bold");
        console.print(f"     Vite dev server: http://{local_ip}:5173", style="muted");
        console.print(f"     Backend API: http://{local_ip}:{api_port}", style="muted");
        console.print("\n  💡 Two modes available:", style="bold");
        console.print("     Bundle mode (default): Loads pre-built HTML from assets", style="muted");
        console.print("     Dev mode (HMR): Set USE_DEV_SERVER = true in .jac/mobile/app/index.tsx", style="muted");
        console.print("                     Loads from Vite dev server with instant updates", style="muted");

        # Wait for Expo process
        return_code = expo_process.wait();
        if return_code != 0 {
            console.warning(f"  Expo process exited with code {return_code}");
        }
    } except KeyboardInterrupt {
        console.print("\n  Keyboard interrupt detected. Stopping...", style="muted");
    } except Exception as e {
        console.error(f"  Error starting mobile dev: {e}");
    } finally {
        cleanup();
    }
}

"""Start Vite dev server for HMR support."""
def _start_vite_dev_server(
    entry_file: Path, project_dir: Path, api_port: int
) -> subprocess.Popen {
    import from jac_client.plugin.src.vite_bundler { ViteBundler }

    # Start Vite dev server on port 5173
    try {
        bundler = ViteBundler(
            project_dir=project_dir, output_dir=None, minify=False, config_path=None
        );

        # Create vite config for dev mode
        dev_config_path = bundler.create_vite_config(
            entry_file,
            api_base_url_override=f"http://localhost:{api_port}",
            is_dev=True,
            api_port=api_port
        );

        # Start Vite dev server
        process = bundler.start_dev_server(port=5173, suppress_initial_output=True);
        return process;
    } except Exception as e {
        raise RuntimeError(f"Failed to start Vite dev server: {e}") ;
    }
}

"""Start backend server."""
def _start_backend_server(
    entry_file: Path, project_dir: Path, port: int
) -> subprocess.Popen {
    # Start jac serve in background
    try {
        process = subprocess.Popen(
            ["jac", "serve", str(entry_file), "--port", str(port)],
            cwd=str(project_dir),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        );
        return process;
    } except Exception as e {
        raise RuntimeError(f"Failed to start backend server: {e}") ;
    }
}

"""Start mobile app - build web bundle and launch React Native with built bundle."""
impl MobileTarget.start(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    # For mobile, start is the same as dev
    # Users can build production apps separately using expo build
    self.dev(entry_file, project_dir, api_port);
}

# ============================================================================
# EAS (Expo Application Services) Build Functions
# ============================================================================

"""Generate eas.json from jac.toml mobile configuration."""
def _generate_eas_json(mobile_dir: Path, project_dir: Path) -> None {
    console.print("  Generating eas.json from jac.toml...", style="muted");

    try {
        # Load mobile config
        import from jac_client.plugin.src.mobile_config { MobileConfig }
        mobile_config = MobileConfig(project_dir=project_dir);
        eas_config = mobile_config.get_eas_config();

        # Write eas.json
        eas_json_path = mobile_dir / "eas.json";
        with open(eas_json_path, "w") as f {
            json.dump(eas_config, f, indent=2);
        }

        console.print(f"  ✔ Generated eas.json", style="success");
    } except Exception as e {
        console.warning(f"  Failed to generate eas.json: {e}");
        raise;
    }
}

"""Check if EAS is configured and user is logged in.
Returns dict with {is_ready: bool, error_message: str}
"""
def _check_eas_ready(mobile_dir: Path) -> dict {
    # Check if eas-cli is available
    try {
        result = subprocess.run(
            ["eas", "--version"],
            capture_output=True,
            text=True,
            timeout=5
        );
        if result.returncode != 0 {
            return {'is_ready': False, 'error_message': "EAS CLI not found. Install with: npm install -g eas-cli"};
        }
    } except FileNotFoundError {
        return {'is_ready': False, 'error_message': "EAS CLI not found. Install with: npm install -g eas-cli"};
    } except Exception as e {
        return {'is_ready': False, 'error_message': f"Failed to check EAS CLI: {e}"};
    }

    # Check if user is logged in
    try {
        result = subprocess.run(
            ["eas", "whoami"],
            capture_output=True,
            text=True,
            timeout=5
        );
        if result.returncode != 0 or not result.stdout.strip() {
            return {'is_ready': False, 'error_message': "Not logged into EAS. Run: eas login"};
        }
    } except Exception as e {
        return {'is_ready': False, 'error_message': f"Failed to check EAS login status: {e}"};
    }

    # Note: We don't check for eas.json here because it will be generated automatically later
    return {'is_ready': True, 'error_message': ""};
}

"""Build mobile app using EAS.
Args:
    mobile_dir: Path to mobile directory
    project_dir: Path to project root
    build_type: Build type (development/preview/production)
    platform: Platform to build for (android/ios/all)
Returns:
    dict with build info: build_id, build_url, artifact_type, platform
"""
def _build_with_eas(
    mobile_dir: Path,
    project_dir: Path,
    build_type: str = "production",
    platform: str = "android"
) -> dict {
    console.print(f"\n🚀 Starting EAS build...", style="bold");
    console.print(f"  Build type: {build_type}", style="muted");
    console.print(f"  Platform: {platform}", style="muted");

    # Check if EAS CLI is installed
    eas_status = _check_eas_ready(mobile_dir);
    if not eas_status['is_ready'] {
        error_msg = eas_status['error_message'];

        # Handle different error scenarios
        if "EAS CLI not found" in error_msg {
            console.error(f"  {error_msg}");
            raise RuntimeError(error_msg) ;
        } elif "Not logged into EAS" in error_msg {
            # Prompt user to login interactively
            console.warning("  Not logged into EAS");
            console.print("\n💡 EAS login required for building:", style="bold");
            console.print("  - If you have an Expo account: Login now", style="muted");
            console.print("  - If you don't: Sign up at https://expo.dev/signup first", style="muted");

            # Ask user if they want to login now
            console.print("\n🔐 Login to EAS? (You'll be prompted for credentials)", style="bold");
            user_input = input("  Continue with login? [Y/n]: ").strip().lower();

            if user_input in ['', 'y', 'yes'] {
                console.print("\n  Running: eas login", style="muted");
                console.print("  (Follow the prompts to login)\n", style="muted");

                try {
                    # Run eas login interactively (no capture_output)
                    result = subprocess.run(
                        ["eas", "login"],
                        cwd=str(mobile_dir),
                        timeout=300  # 5 minutes for login
                    );

                    if result.returncode != 0 {
                        console.error("  Login failed");
                        raise RuntimeError("EAS login failed") ;
                    }

                    console.success("  ✔ Login successful!");
                } except subprocess.TimeoutExpired {
                    console.error("  Login timed out");
                    raise RuntimeError("EAS login timed out") ;
                } except Exception as e {
                    console.error(f"  Login failed: {e}");
                    raise RuntimeError(f"EAS login failed: {e}") ;
                }
            } else {
                console.print("\n💡 To build later, run: eas login", style="bold");
                console.print("💡 For local dev testing: jac start main.jac --client mobile", style="muted");
                raise RuntimeError("User declined EAS login") ;
            }
        } else {
            console.error(f"  {error_msg}");
            raise RuntimeError(error_msg) ;
        }
    }

    # EAS configuration should already be in place (generated during build step)
    eas_json_path = mobile_dir / "eas.json";
    if not eas_json_path.exists() {
        console.print("  Generating EAS configuration...", style="muted");
        try {
            _generate_eas_json(mobile_dir, project_dir);
            console.success("  ✔ EAS configured");
        } except Exception as e {
            console.warning(f"  Failed to generate eas.json: {e}");
            raise RuntimeError(f"EAS configuration failed: {e}") ;
        }
    } else {
        console.print("  ✔ EAS configuration found", style="success");
    }

    # Build command (run from within mobile directory)
    # EAS CLI must be run from the project directory containing app.json
    cmd = [
        "eas", "build",
        "--profile", build_type,
        "--platform", platform
    ];

    console.print(f"\n  Running: {' '.join(cmd)}", style="muted");
    console.print(f"  (This will upload your project to EAS cloud)", style="muted");
    console.print(f"  (Note: First-time setup may ask to configure project)", style="muted");
    console.print(f"  (Select the platform you chose: {platform})\n", style="muted");

    try {
        # Run from mobile directory (where app.json and eas.json are located)
        result = subprocess.run(
            cmd,
            cwd=str(mobile_dir),
            timeout=600  # 10 minute timeout for build submission
        );

        if result.returncode != 0 {
            console.error(f"\n  EAS build submission failed");
            raise RuntimeError(f"EAS build failed with exit code {result.returncode}") ;
        }

        # Build submitted successfully
        console.success(f"\n✔ Build submitted successfully!");
        console.print(f"\n💡 Your build is now processing on EAS cloud", style="bold");
        console.print(f"   Monitor progress at: https://expo.dev", style="muted");

        # Return minimal info (we can't parse stdout since we didn't capture it)
        return {
            'build_id': 'submitted',
            'build_url': f'https://expo.dev (check your account)',
            'artifact_type': _get_artifact_type(build_type, platform),
            'platform': platform
        };

    } except subprocess.TimeoutExpired {
        console.error("  EAS build submission timed out");
        raise RuntimeError("EAS build submission timed out") ;
    } except Exception as e {
        console.error(f"  EAS build failed: {e}");
        raise RuntimeError(f"EAS build failed: {e}") ;
    }
}

"""Parse EAS CLI output to extract build ID and URL.

Example output:
✔ Build started
Build ID: abc123-def456-ghi789
Build URL: https://expo.dev/accounts/username/projects/projectname/builds/abc123
"""
def _parse_eas_output(output: str, build_type: str, platform: str) -> dict {
    build_id = "";
    build_url = "";

    # Parse output for build ID and URL
    lines = output.split('\n');
    for line in lines {
        # Look for build ID
        if 'Build ID' in line or 'build ID' in line {
            # Extract ID after colon
            parts = line.split(':');
            if len(parts) > 1 {
                build_id = parts[1].strip();
            }
        }

        # Look for build URL
        if 'expo.dev' in line {
            # Extract URL
            import re;
            url_match = re.search(r'https://expo\.dev/[^\s]+', line);
            if url_match {
                build_url = url_match.group(0);
            }
        }
    }

    # If not found in that format, try alternative parsing
    if not build_id or not build_url {
        # Try to find any URL that looks like a build URL
        import re;
        all_urls = re.findall(r'https://[^\s]+', output);
        for url in all_urls {
            if 'expo.dev' in url and 'builds' in url {
                build_url = url;
                # Extract build ID from URL
                id_match = re.search(r'/builds/([a-f0-9\-]+)', url);
                if id_match {
                    build_id = id_match.group(1);
                }
                break;
            }
        }
    }

    # Determine artifact type
    artifact_type = _get_artifact_type(build_type, platform);

    return {
        'build_id': build_id or 'unknown',
        'build_url': build_url or 'Check expo.dev for build status',
        'artifact_type': artifact_type,
        'platform': platform
    };
}

"""Determine output artifact type.

Android:
- development/preview: APK
- production: AAB

iOS:
- development: .app (simulator)
- preview/production: IPA

all: Both
"""
def _get_artifact_type(build_type: str, platform: str) -> str {
    if platform == "android" {
        if build_type == "production" {
            return "AAB (Android App Bundle)";
        } else {
            return "APK";
        }
    } elif platform == "ios" {
        if build_type == "development" {
            return "APP (Simulator)";
        } else {
            return "IPA";
        }
    } elif platform == "all" {
        if build_type == "production" {
            return "AAB + IPA";
        } else {
            return "APK + IPA";
        }
    }

    return "Unknown";
}
