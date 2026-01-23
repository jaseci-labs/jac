# Multi-Target Builds

> **New in jac-client**: Build your Jac application for multiple platforms from a single codebase!

Jac now supports building your application for different targets - web browsers, desktop applications, and more. Write your code once, deploy everywhere.

---

## What are Multi-Target Builds?

Multi-target builds allow you to compile the same Jac codebase for different platforms:

- **Web**: Browser-based applications (default)
- **Desktop**: Native desktop applications using Tauri
- **Mobile**: Coming soon (Android, iOS)

Each target uses the same Jac code, but produces platform-specific outputs optimized for that environment.

---

## Quick Start

### Web Target (Default)

The web target requires no setup and works out of the box:

```bash
# Build for web
jac build main.jac --client web

# Or simply (web is default)
jac build main.jac

# Start dev server
jac start main.jac --dev
```

### Desktop Target

Desktop builds create native applications:

```bash
# 1. One-time setup
jac setup desktop

# 2. Build for desktop
jac build main.jac --client desktop

# 3. Start in dev mode (hot reload)
jac start main.jac --client desktop --dev
```

---

## Why Multi-Target Builds?

### Single Codebase, Multiple Platforms

Write your application once in Jac, then build for:

- Web browsers (Chrome, Firefox, Safari, Edge)
- Desktop (Windows, macOS, Linux)
- Mobile (coming soon)

### Consistent Experience

- Same language (Jac) across all platforms
- Same APIs and patterns
- Same development workflow

### Easy Distribution

- Web: Deploy to any web server
- Desktop: Create installers (`.exe`, `.dmg`, `.AppImage`)
- Mobile: Create app packages (`.apk`, `.ipa`)

---

## Target Comparison

| Feature | Web | Desktop |
|---------|-----|---------|
| **Setup Required** | No | Yes (`jac setup desktop`) |
| **Build Command** | `jac build` | `jac build --client desktop` |
| **Dev Command** | `jac start --dev` | `jac start --client desktop --dev` |
| **Output** | `.jac/client/dist/` | Installer (`.exe`, `.dmg`, `.AppImage`) |
| **Distribution** | Web server | Installer file |
| **Hot Reload** | ✅ Yes | ✅ Yes |
| **Native Features** | ❌ Limited | ✅ Full access |

---

## Getting Started

### For Web Applications

If you're building a web app, you don't need to do anything special:

```bash
# Create a new project
jac create --use client my-app

# Start developing
jac start main.jac --dev

# Build for production
jac build main.jac
```

### For Desktop Applications

To add desktop support to your project:

```bash
# Setup desktop target (one-time)
jac setup desktop

# Develop with hot reload
jac start main.jac --client desktop --dev

# Build installer
jac build main.jac --client desktop
```

---

## Next Steps

- **[Web Target Guide](web-target.md)**: Learn about web builds in detail
- **[Desktop Target Guide](desktop-target.md)**: Learn about desktop builds in detail

---

## FAQ

**Q: Can I use the same codebase for web and desktop?**
A: Yes! The same Jac code works for both targets. The build system handles the differences.

**Q: Do I need separate builds for each platform?**
A: For production, yes. Use `--platform` flag to build for specific platforms. For development, Tauri automatically uses your current platform.

**Q: Will adding desktop support break my web app?**
A: No! Web remains the default target with zero breaking changes.

**Q: Can I test my desktop app before building?**
A: Yes! Use `jac start main.jac --client desktop --dev` for hot reload development.

**Q: How do I distribute my desktop app?**
A: After building with `jac build --client desktop`, distribute the installer files from `src-tauri/target/release/bundle/`.

---

Happy building! 🚀
