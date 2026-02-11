# PWA Default Icons

PWA icons are generated dynamically using Pillow (PIL) during build.

Required icon sizes:

- `pwa-192x192.png` - 192x192 pixel PNG icon
- `pwa-512x512.png` - 512x512 pixel PNG icon

To use custom icons, place your own PNG files in your project's `pwa_icons/` directory.
If no custom icons are provided, placeholder icons will be generated automatically.

Note: Pillow must be installed (`pip install Pillow`) for automatic icon generation.
