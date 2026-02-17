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
        raise RuntimeError(f"Failed to generate manifest.json: {e}") ;
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
  {', '.join(precache_files)}
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
        raise RuntimeError(f"Failed to generate service worker: {e}") ;
    }
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

"""Update index.html to include PWA meta tags and service worker registration."""
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

        if '</head>' in html_content {
            pwa_head = _build_pwa_head_tags(theme_color);
            html_content = html_content.replace('</head>', f'{pwa_head}\n  </head>');
            modified = True;
        } else {
            console.warning("  No </head> tag found, skipping PWA head injection");
        }

        if '</body>' in html_content {
            sw_script = _build_sw_registration_script();
            html_content = html_content.replace('</body>', f'{sw_script}\n  </body>');
            modified = True;
        } else {
            console.warning(
                "  No </body> tag found, skipping SW registration injection"
            );
        }

        if modified {
            index_path.write_text(html_content, encoding='utf-8');
            console.print("  ✔ Updated index.html with PWA support", style="success");
        }
    } except Exception as e {
        raise RuntimeError(f"Failed to update index.html for PWA: {e}") ;
    }
}

"""Setup PWA target - copies default icons and configures jac.toml."""
impl PWATarget.setup(self: PWATarget, project_dir: Path) -> None {
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
    self: PWATarget,
    entry_file: Path,
    project_dir: Path,
    platform: Optional[str] = None
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
impl PWATarget.dev(
    self: PWATarget, entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
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
    self: PWATarget, entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    # Build PWA first (which calls super().build() + adds PWA artifacts)
    self.build(entry_file, project_dir, None);
    # Then serve using inherited WebTarget.start()
    super.start(entry_file, project_dir, api_port);
}
