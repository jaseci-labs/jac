"""Implementation of PWATarget methods."""
import from pathlib { Path }
import from typing { Optional }
import from jac_client.plugin.src.vite_bundler { ViteBundler }
import from jaclang.cli.console { console }
import from jaclang.project.config { get_config }
import json;
import shutil;
import sys;

# PWA Constants
glob PWA_DEFAULT_THEME_COLOR = "#000000",
     PWA_DEFAULT_BACKGROUND_COLOR = "#ffffff",
     PWA_DEFAULT_CACHE_NAME = "jac-pwa-cache-v1",
     PWA_ICON_SMALL = "pwa-192x192.png",
     PWA_ICON_LARGE = "pwa-512x512.png",
     PWA_API_PATH_PREFIX = "/api/",
     PWA_CACHEABLE_EXTENSIONS = ['.html', '.js', '.css', '.png', '.json'];

# Install Banner Constants
glob PWA_BANNER_STORAGE_KEY = "__jac_pwa_prefs__",
     PWA_BANNER_DEFAULT_DELAY_MS = 3000,
     PWA_BANNER_DISMISS_DELAYS_DAYS = [7, 14, 28],
     PWA_BANNER_MAX_DISMISSALS = 3,
     PWA_BANNER_ANIMATION_MS = 300,
     PWA_BANNER_Z_INDEX = 9999,
     PWA_IOS_MODAL_Z_INDEX = 10000,
     PWA_MS_PER_DAY = 86400000;

"""Load PWA config with project metadata in a single config fetch."""
def _load_pwa_context -> tuple[dict, str] {
    config = get_config();
    project_name = "Jac App";
    pwa_config: dict = {};

    if config {
        if config.project and config.project.name {
            project_name = config.project.name;
        }
        client_cfg = config.get_plugin_config("client");
        if client_cfg {
            pwa_config = client_cfg.get("pwa", {});
        }
    }
    return (pwa_config, project_name);
}

"""Get default PWA manifest configuration."""
def _get_default_manifest(project_name: str, pwa_config: dict) -> dict {
    theme_color = pwa_config.get("theme_color", PWA_DEFAULT_THEME_COLOR);
    background_color = pwa_config.get("background_color", PWA_DEFAULT_BACKGROUND_COLOR);

    return {
        "name": project_name,
        "short_name": project_name,
        "description": f"{project_name} - Built with Jac",
        "start_url": "/",
        "display": "standalone",
        "background_color": background_color,
        "theme_color": theme_color,
        "icons": [
            {"src": PWA_ICON_SMALL, "sizes": "192x192", "type": "image/png"},
            {"src": PWA_ICON_LARGE, "sizes": "512x512", "type": "image/png"},
            {
                "src": PWA_ICON_LARGE,
                "sizes": "512x512",
                "type": "image/png",
                "purpose": "maskable"
            }
        ]
    };
}

"""Generate a PWA icon using Pillow."""
def _generate_pwa_icon(dest_path: Path, size: int) -> bool {
    import subprocess;
    python_code = f'''
import sys
try:
    from PIL import Image, ImageDraw
    size = {size}
    img = Image.new("RGBA", (size, size), color=(66, 139, 202, 255))
    draw = ImageDraw.Draw(img)
    margin = size // 8
    stroke = size // 16
    draw.rectangle([size//2, margin, size//2 + stroke, size - margin*2], fill=(255, 255, 255, 255))
    draw.rectangle([margin*2, size - margin*2 - stroke, size//2 + stroke, size - margin*2], fill=(255, 255, 255, 255))
    draw.rectangle([size//2 - stroke, margin, size//2 + stroke*2, margin + stroke], fill=(255, 255, 255, 255))
    img.save(sys.argv[1], "PNG")
    sys.exit(0)
except ImportError:
    sys.exit(1)
except Exception:
    sys.exit(1)
''';
    try {
        result = subprocess.run(
            [sys.executable, '-c', python_code, str(dest_path)],
            check=False,
            capture_output=True,
            timeout=30
        );
        return result.returncode == 0;
    } except (subprocess.SubprocessError, FileNotFoundError) {
        return False;
    }
}

"""Generate default PWA icons to directory."""
def _generate_default_pwa_icons(dest_dir: Path) -> int {
    dest_dir.mkdir(parents=True, exist_ok=True);
    generated = 0;
    icon_192 = dest_dir / PWA_ICON_SMALL;
    if not icon_192.exists() and _generate_pwa_icon(icon_192, 192) {
        generated += 1;
    }
    icon_512 = dest_dir / PWA_ICON_LARGE;
    if not icon_512.exists() and _generate_pwa_icon(icon_512, 512) {
        generated += 1;
    }
    if generated > 0 {
        console.print(
            f"  ✔ Generated {generated} default PWA icon(s)", style="success"
        );
    }
    return generated;
}

"""Copy PWA icons from source to destination directory."""
def _copy_icons(src_dir: Path, dest_dir: Path) -> int {
    icon_files = list(src_dir.glob("*.png"));
    if not icon_files {
        return 0;
    }
    for icon_file in icon_files {
        shutil.copy2(icon_file, dest_dir / icon_file.name);
    }
    console.print(f"  ✔ Copied {len(icon_files)} PWA icon(s)", style="success");
    return len(icon_files);
}

"""Copy or generate PWA icons to dist directory."""
def _copy_pwa_icons_to_dist(dist_dir: Path, project_dir: Path) -> None {
    try {
        user_icons_dir = project_dir / "pwa_icons";
        if user_icons_dir.exists() {
            user_icons = list(user_icons_dir.glob("*.png"));
            if user_icons {
                _copy_icons(user_icons_dir, dist_dir);
                return;
            }
        }
        generated = _generate_default_pwa_icons(dist_dir);
        if generated == 0 {
            console.warning(
                "  Could not generate default icons (Pillow not available)"
            );
        }
    } except Exception as e {
        console.warning(f"  Failed to set up PWA icons: {e}");
    }
}

"""Generate manifest.json for PWA."""
def _generate_manifest(dist_dir: Path, project_name: str, pwa_config: dict) -> None {
    manifest = _get_default_manifest(project_name, pwa_config);

    user_manifest = pwa_config.get("manifest", {});
    manifest.update(user_manifest);

    try {
        manifest_path = dist_dir / "manifest.json";
        manifest_path.write_text(json.dumps(manifest, indent=2), encoding='utf-8');
        console.print("  ✔ Generated manifest.json", style="success");
    } except Exception as e {
        raise RuntimeError(f"Failed to generate manifest.json: {e}");
    }
}

"""Build list of files to precache from dist directory."""
def _get_precache_files(dist_dir: Path) -> list[str] {
    precache_files: list[str] = [];
    if not dist_dir.exists() {
        return precache_files;
    }
    for f in dist_dir.iterdir() {
        if f.is_file() and f.suffix in PWA_CACHEABLE_EXTENSIONS {
            precache_files.append(f"'./{f.name}'");
        }
    }
    return precache_files;
}

"""Generate service worker JavaScript content."""
def _build_service_worker_content(cache_name: str, precache_files: list[str]) -> str {
    return f'''// Jac PWA Service Worker
const CACHE_NAME = '{cache_name}';
const PRECACHE_ASSETS = [
  './',
  {', '.join(
        precache_files
    )}
];

// Install event - precache assets
self.addEventListener('install', (event) => {{
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(PRECACHE_ASSETS))
      .then(() => self.skipWaiting())
  );
}});

// Activate event - cleanup old caches
self.addEventListener('activate', (event) => {{
  event.waitUntil(
    caches.keys().then((cacheNames) => {{
      return Promise.all(
        cacheNames
          .filter((name) => name !== CACHE_NAME)
          .map((name) => caches.delete(name))
      );
    }}).then(() => self.clients.claim())
  );
}});

// Fetch event - cache-first for assets, network-first for API
self.addEventListener('fetch', (event) => {{
  const url = new URL(event.request.url);

  // Network-first for API calls
  if (url.pathname.startsWith('{PWA_API_PATH_PREFIX}')) {{
    event.respondWith(
      fetch(event.request)
        .then((response) => {{
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
          return response;
        }})
        .catch(() => caches.match(event.request))
    );
    return;
  }}

  // Cache-first for static assets
  event.respondWith(
    caches.match(event.request)
      .then((cached) => cached || fetch(event.request))
  );
}});
''';
}

"""Generate service worker for offline support."""
def _generate_service_worker(dist_dir: Path, pwa_config: dict) -> None {
    cache_name = pwa_config.get("cache_name", PWA_DEFAULT_CACHE_NAME);
    precache_files = _get_precache_files(dist_dir);
    sw_content = _build_service_worker_content(cache_name, precache_files);

    try {
        sw_path = dist_dir / "sw.js";
        sw_path.write_text(sw_content, encoding='utf-8');
        console.print("  ✔ Generated sw.js (service worker)", style="success");
    } except Exception as e {
        raise RuntimeError(f"Failed to generate service worker: {e}");
    }
}

"""Build beforeinstallprompt capture script (must be FIRST in head)."""
def _build_install_prompt_capture_script -> str {
    return '''
    <script>
      // Capture beforeinstallprompt EARLY before any modules load
      window.__jacPwaPrompt = null;
      window.__jacPwaPromptCaptured = true;
      window.addEventListener('beforeinstallprompt', function(e) {
        e.preventDefault();
        window.__jacPwaPrompt = e;
        window.dispatchEvent(new CustomEvent('jac:pwa:promptready'));
      });
      window.addEventListener('appinstalled', function() {
        window.__jacPwaInstalled = true;
        window.__jacPwaPrompt = null;
        window.dispatchEvent(new CustomEvent('jac:pwa:installed'));
      });
    </script>''';
}

"""Build PWA head tags for HTML injection."""
def _build_pwa_head_tags(theme_color: str) -> str {
    return f'''
    <link rel="manifest" href="manifest.json">
    <meta name="theme-color" content="{theme_color}">
    <link rel="apple-touch-icon" href="{PWA_ICON_SMALL}">''';
}

"""Build service worker registration script."""
def _build_sw_registration_script -> str {
    return '''
    <script>
      if ('serviceWorker' in navigator) {
        window.addEventListener('load', () => {
          navigator.serviceWorker.register('sw.js')
            .then((reg) => console.log('SW registered:', reg.scope))
            .catch((err) => console.log('SW registration failed:', err));
        });
      }
    </script>''';
}

"""Build CSS styles for PWA install banner."""
def _build_banner_css(position: str) -> str {
    pos_style = "bottom: 16px;" if position == "bottom" else "top: 16px;";
    return f'''
          .jac-pwa-banner {{
            position: fixed; {pos_style} left: 16px; right: 16px;
            max-width: 480px; margin: 0 auto;
            background: rgba(15,15,25,0.92);
            backdrop-filter: blur(20px); -webkit-backdrop-filter: blur(20px);
            border: 1px solid rgba(255,255,255,0.12); border-radius: 20px;
            color: #fff; padding: 16px 20px; display: flex; align-items: center; gap: 14px;
            box-shadow: 0 8px 32px rgba(0,0,0,0.4);
            z-index: {PWA_BANNER_Z_INDEX}; font-family: system-ui, -apple-system, sans-serif;
            animation: jac-pwa-in 0.4s cubic-bezier(0.16,1,0.3,1);
          }}
          .jac-pwa-banner.dismissing {{ animation: jac-pwa-out 0.3s ease forwards; }}
          @keyframes jac-pwa-in {{ from {{ transform: translateY(100%); opacity: 0; }} }}
          @keyframes jac-pwa-out {{ to {{ transform: translateY(100%); opacity: 0; }} }}
          .jac-pwa-banner img {{ width: 52px; height: 52px; border-radius: 14px; background: rgba(255,255,255,0.1); }}
          .jac-pwa-banner .content {{ flex: 1; min-width: 0; }}
          .jac-pwa-banner .title {{ font-weight: 600; font-size: 15px; margin-bottom: 3px; }}
          .jac-pwa-banner .desc {{ font-size: 13px; opacity: 0.75; }}
          .jac-pwa-banner .actions {{ display: flex; gap: 8px; }}
          .jac-pwa-banner .install {{
            background: linear-gradient(135deg,#6366f1,#a855f7); color: #fff;
            border: none; padding: 10px 20px; border-radius: 12px;
            font-weight: 600; font-size: 14px; cursor: pointer;
            box-shadow: 0 4px 15px rgba(99,102,241,0.4);
          }}
          .jac-pwa-banner .dismiss {{
            background: rgba(255,255,255,0.1); color: rgba(255,255,255,0.9);
            border: 1px solid rgba(255,255,255,0.15); padding: 10px 16px;
            border-radius: 12px; font-size: 14px; cursor: pointer;
          }}
          .jac-pwa-ios {{ position: fixed; inset: 0; background: rgba(0,0,0,0.5);
            backdrop-filter: blur(8px); display: flex; align-items: center;
            justify-content: center; z-index: {PWA_IOS_MODAL_Z_INDEX}; padding: 20px; }}
          .jac-pwa-ios-box {{ background: rgba(20,20,30,0.95); backdrop-filter: blur(24px);
            border: 1px solid rgba(255,255,255,0.12); border-radius: 24px;
            padding: 28px 24px; max-width: 340px; text-align: center; color: #fff; }}
          .jac-pwa-ios h3 {{ font-size: 20px; margin: 0 0 8px; }}
          .jac-pwa-ios p {{ font-size: 14px; opacity: 0.7; margin: 0 0 24px; }}
          .jac-pwa-ios .step {{ display: flex; align-items: center; gap: 14px;
            padding: 14px 16px; background: rgba(255,255,255,0.08);
            border-radius: 14px; margin-bottom: 8px; text-align: left; font-size: 14px; }}
          .jac-pwa-ios .num {{ width: 28px; height: 28px; border-radius: 50%;
            background: linear-gradient(135deg,#6366f1,#a855f7);
            display: flex; align-items: center; justify-content: center;
            font-weight: 600; font-size: 13px; flex-shrink: 0; }}
          .jac-pwa-ios .close {{ width: 100%; background: rgba(255,255,255,0.12);
            border: 1px solid rgba(255,255,255,0.15); color: #fff;
            padding: 14px; border-radius: 14px; font-size: 15px;
            font-weight: 600; cursor: pointer; margin-top: 16px; }}
          @media (max-width: 520px) {{
            .jac-pwa-banner {{ flex-wrap: wrap; }}
            .jac-pwa-banner .actions {{ width: 100%; margin-top: 14px; }}
            .jac-pwa-banner .install, .jac-pwa-banner .dismiss {{ flex: 1; text-align: center; }}
          }}''';
}

"""Build PWA install banner auto-injection script (self-contained, no imports)."""
def _build_pwa_install_banner_script(pwa_config: dict) -> str {
    if not pwa_config.get("install_banner", True) {
        return "";
    }

    # Get configuration with defaults from constants
    delay = pwa_config.get("install_banner_delay", PWA_BANNER_DEFAULT_DELAY_MS);
    position = pwa_config.get("install_banner_position", "bottom");
    title = pwa_config.get("install_title", "");
    description = pwa_config.get(
        "install_description", "Add to home screen for the best experience"
    );
    install_text = pwa_config.get("install_button_text", "Install");
    dismiss_text = pwa_config.get("install_dismiss_text", "Not now");

    # Get CSS from helper and escape for JS template literal
    banner_css = _build_banner_css(position);

    # Use constants for magic numbers
    max_dismissals = PWA_BANNER_MAX_DISMISSALS;
    dismiss_delays = PWA_BANNER_DISMISS_DELAYS_DAYS;
    ms_per_day = PWA_MS_PER_DAY;
    animation_ms = PWA_BANNER_ANIMATION_MS;

    return f'''
    <script>
      (function() {{
        // PWA Install Banner - Configuration
        var STORAGE_KEY = '{PWA_BANNER_STORAGE_KEY}';
        var DELAY = {delay};
        var TITLE = '{title}';
        var DESC = '{description}';
        var INSTALL_TEXT = '{install_text}';
        var DISMISS_TEXT = '{dismiss_text}';
        var MAX_DISMISSALS = {max_dismissals};
        var DISMISS_DELAYS = {dismiss_delays};
        var MS_PER_DAY = {ms_per_day};
        var ANIMATION_MS = {animation_ms};

        // Skip if already installed (standalone mode)
        if (window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone) {{
          return;
        }}

        // Helper to dismiss banner with animation
        function dismissBanner(banner) {{
          banner.classList.add('dismissing');
          setTimeout(function() {{ banner.remove(); }}, ANIMATION_MS);
        }}

        // Check dismiss history
        function shouldShow() {{
          try {{
            var prefs = JSON.parse(localStorage.getItem(STORAGE_KEY) || '{{}}');
            if (prefs.installed) return false;
            if (!prefs.dismissed) return true;
            if (prefs.dismissCount >= MAX_DISMISSALS) return false;
            var reqDelay = DISMISS_DELAYS[Math.min(prefs.dismissCount - 1, 2)] || 7;
            var daysSince = (Date.now() - prefs.dismissedAt) / MS_PER_DAY;
            return daysSince >= reqDelay;
          }} catch(e) {{ return true; }}
        }}

        function recordDismiss() {{
          try {{
            var prefs = JSON.parse(localStorage.getItem(STORAGE_KEY) || '{{}}');
            prefs.dismissed = true;
            prefs.dismissedAt = Date.now();
            prefs.dismissCount = (prefs.dismissCount || 0) + 1;
            localStorage.setItem(STORAGE_KEY, JSON.stringify(prefs));
          }} catch(e) {{}}
        }}

        function isIos() {{
          return /iPad|iPhone|iPod/.test(navigator.userAgent) ||
            (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
        }}

        // Get app info from manifest
        function getManifestInfo(cb) {{
          var link = document.querySelector('link[rel="manifest"]');
          if (!link) return cb(null, null);
          fetch(link.href).then(function(r) {{ return r.json(); }})
            .then(function(m) {{
              var icon = (m.icons || []).find(function(i) {{ return i.sizes === '192x192'; }}) || (m.icons || [])[0];
              cb(m.name || m.short_name || '', icon ? icon.src : null);
            }})
            .catch(function() {{ cb(null, null); }});
        }}

        if (!shouldShow()) return;

        var css = `{banner_css}`;

        function showBanner() {{
          var style = document.createElement('style');
          style.textContent = css;
          document.head.appendChild(style);

          getManifestInfo(function(name, icon) {{
            var banner = document.createElement('div');
            banner.className = 'jac-pwa-banner';
            banner.innerHTML = (icon ? '<img src="' + icon + '" alt="">' : '') +
              '<div class="content">' +
                '<div class="title">' + (TITLE || name || 'Install App') + '</div>' +
                '<div class="desc">' + DESC + '</div>' +
              '</div>' +
              '<div class="actions">' +
                '<button class="install">' + INSTALL_TEXT + '</button>' +
                '<button class="dismiss">' + DISMISS_TEXT + '</button>' +
              '</div>';

            var installBtn = banner.querySelector('.install');
            var dismissBtn = banner.querySelector('.dismiss');

            installBtn.onclick = function() {{
              if (isIos()) {{
                // Show iOS guide
                var ios = document.createElement('div');
                ios.className = 'jac-pwa-ios';
                ios.innerHTML = '<div class="jac-pwa-ios-box">' +
                  '<h3>Install ' + (name || 'App') + '</h3>' +
                  '<p>Add to your home screen</p>' +
                  '<div class="step"><span class="num">1</span><span>Tap the <b>Share</b> button</span></div>' +
                  '<div class="step"><span class="num">2</span><span>Tap <b>Add to Home Screen</b></span></div>' +
                  '<div class="step"><span class="num">3</span><span>Tap <b>Add</b> to confirm</span></div>' +
                  '<button class="close">Got it</button></div>';
                ios.querySelector('.close').onclick = function() {{ ios.remove(); }};
                ios.onclick = function(e) {{ if (e.target === ios) ios.remove(); }};
                document.body.appendChild(ios);
                dismissBanner(banner);
              }} else if (window.__jacPwaPrompt) {{
                window.__jacPwaPrompt.prompt();
                window.__jacPwaPrompt.userChoice.then(function(r) {{
                  if (r.outcome === 'accepted') {{
                    dismissBanner(banner);
                  }}
                }});
              }}
            }};

            dismissBtn.onclick = function() {{
              recordDismiss();
              dismissBanner(banner);
            }};

            document.body.appendChild(banner);
          }});
        }}

        // Show banner after delay - install button handles prompt availability
        setTimeout(showBanner, DELAY);
      }})();
    </script>''';
}

"""Update index.html to include PWA meta tags, service worker, and install banner."""
def _update_html_for_pwa(dist_dir: Path, pwa_config: dict) -> None {
    index_path = dist_dir / "index.html";
    if not index_path.exists() {
        console.warning("  index.html not found, skipping PWA HTML update");
        return;
    }

    theme_color = pwa_config.get("theme_color", PWA_DEFAULT_THEME_COLOR);

    try {
        html_content = index_path.read_text(encoding='utf-8');
        modified = False;

        # 1. Inject beforeinstallprompt capture script FIRST in <head>
        if '<head>' in html_content {
            install_capture = _build_install_prompt_capture_script();
            html_content = html_content.replace('<head>', f'<head>{install_capture}');
            modified = True;
        }

        # 2. Inject PWA meta tags before </head>
        if '</head>' in html_content {
            pwa_head = _build_pwa_head_tags(theme_color);
            html_content = html_content.replace('</head>', f'{pwa_head}\n  </head>');
            modified = True;
        } else {
            console.warning("  No </head> tag found, skipping PWA head injection");
        }

        # 3. Inject SW registration and install banner before </body>
        if '</body>' in html_content {
            sw_script = _build_sw_registration_script();
            banner_script = _build_pwa_install_banner_script(pwa_config);
            body_scripts = sw_script + banner_script;
            html_content = html_content.replace('</body>', f'{body_scripts}\n  </body>');
            modified = True;
        } else {
            console.warning(
                "  No </body> tag found, skipping SW registration injection"
            );
        }

        if modified {
            index_path.write_text(html_content, encoding='utf-8');
            console.print("  ✔ Updated index.html with PWA support", style="success");
            if pwa_config.get("install_banner", True) {
                console.print("  ✔ Added PWA install banner", style="success");
            }
        }
    } except Exception as e {
        raise RuntimeError(f"Failed to update index.html for PWA: {e}");
    }
}

"""Setup PWA target - copies default icons and configures jac.toml."""
impl PWATarget.setup(project_dir: Path) -> None {
    console.print("\n📱 Setting up PWA target", style="bold");
    icons_dest = project_dir / "pwa_icons";
    if not icons_dest.exists() {
        icons_dest.mkdir(parents=True);
        _copy_pwa_icons_to_project(icons_dest);
    } else {
        console.print("  ✔ pwa_icons/ directory already exists", style="muted");
    }
    _ensure_pwa_config(project_dir);
    console.print("\n✅ PWA setup complete!", style="bold green");
    console.print(
        "  Run 'jac build --client pwa' or 'jac start --client pwa'", style="muted"
    );
}

"""Generate PWA icons to project directory."""
def _copy_pwa_icons_to_project(dest_dir: Path) -> None {
    try {
        generated = _generate_default_pwa_icons(dest_dir);
        if generated == 0 {
            console.print(
                "  Created pwa_icons/ directory (add pwa-192x192.png and pwa-512x512.png)",
                style="muted"
            );
            console.print(
                "  Note: Install Pillow to auto-generate placeholder icons",
                style="muted"
            );
        }
    } except Exception as e {
        console.warning(f"  Failed to generate default icons: {e}");
    }
}

"""Ensure PWA config section exists in jac.toml."""
def _ensure_pwa_config(project_dir: Path) -> None {
    import tomllib;

    toml_path = project_dir / "jac.toml";
    if not toml_path.exists() {
        console.print("  No jac.toml found, skipping config update", style="muted");
        return;
    }

    try {
        content = toml_path.read_text(encoding='utf-8');
        config = tomllib.loads(content);

        client_cfg = config.get('plugins', {}).get('client', {});
        if 'pwa' in client_cfg {
            console.print("  ✔ PWA config already exists in jac.toml", style="muted");
            return;
        }

        pwa_section = '''
[plugins.client.pwa]
theme_color = "#000000"
background_color = "#ffffff"
# cache_name = "jac-pwa-cache-v1"

# Install banner configuration
install_banner = true              # Enable auto-injected install banner
install_banner_delay = 3000        # Ms before showing banner
install_banner_position = "bottom" # "bottom" | "top"
# install_title = ""               # Empty = use manifest name
install_description = "Add to home screen for the best experience"
install_button_text = "Install"
install_dismiss_text = "Not now"

# [plugins.client.pwa.manifest]
# name = "My App"
# short_name = "App"
''';

        with open(toml_path, 'a', encoding='utf-8') as f {
            f.write(pwa_section);
        }
        console.print(
            "  ✔ Added [plugins.client.pwa] section to jac.toml", style="success"
        );
    } except Exception as e {
        console.warning(f"  Failed to update jac.toml: {e}");
    }
}

"""Build PWA bundle - web bundle + manifest + service worker.

Uses super().build() to get the web bundle, then adds PWA artifacts.
"""
impl PWATarget.build(
    entry_file: Path, project_dir: Path, platform: Optional[str] = None
) -> Path {
    console.print("\n📱 Building PWA target", style="bold");
    # Use inherited WebTarget.build() via super()
    bundle_path = super.build(entry_file, project_dir, platform);
    bundler = ViteBundler(project_dir=project_dir);
    dist_dir = bundler.output_dir;
    (pwa_config, project_name) = _load_pwa_context();
    console.print("\n  Adding PWA features...", style="muted");
    _copy_pwa_icons_to_dist(dist_dir, project_dir);
    _generate_manifest(dist_dir, project_name, pwa_config);
    _generate_service_worker(dist_dir, pwa_config);
    _update_html_for_pwa(dist_dir, pwa_config);
    console.print("\n✅ PWA build complete!", style="bold green");
    console.print(f"  Output: {dist_dir}", style="muted");
    return bundle_path;
}

"""Start PWA dev server - delegates to WebTarget.dev() via super().

Service worker is disabled in dev mode for better developer experience.
"""
impl PWATarget.dev(entry_file: Path, project_dir: Path, api_port: int = 8000) -> None {
    console.print("\n📱 Starting PWA dev server", style="bold");
    console.print(
        "  Note: Service worker is disabled in dev mode for better DX", style="muted"
    );
    # Delegate to inherited WebTarget.dev()
    super.dev(entry_file, project_dir, api_port);
}

"""Start PWA in production preview mode - builds PWA then serves.

Delegates to WebTarget.start() via super() after building PWA artifacts.
"""
impl PWATarget.start(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    # Build PWA first (which calls super().build() + adds PWA artifacts)
    self.build(entry_file, project_dir, None);
    # Then serve using inherited WebTarget.start()
    super.start(entry_file, project_dir, api_port);
}
