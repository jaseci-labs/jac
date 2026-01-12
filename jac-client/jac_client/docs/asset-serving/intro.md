# Asset Serving in Jac

Static assets such as images, fonts, videos, and stylesheets are essential for web applications. Jac provides multiple approaches for serving these assets, each suited for different use cases.

!!! tip "Important"
    All local assets must be placed in the `assets/` folder at the root of your project. The server serves these files from the `/static/` path.

## Overview

Jac supports two primary approaches for asset serving:

- **Remote Assets**: External URLs from CDNs or remote servers
- **Local Assets**: Files stored in your project, served by the Jac server

Local assets can be referenced using either **Static Path** (direct `/static/` URLs) or **Import Alias** (Vite-processed imports with optimization).

## Remote Assets

Use external URLs for assets hosted on CDNs or remote servers.

### Usage

```jac
<img src="https://picsum.photos/400/300" alt="Image" />
<img src="https://via.placeholder.com/400x300" alt="Placeholder" />
```

### When to Use

- CDN-hosted production assets
- Placeholder images during development
- External resources managed outside your project
- Dynamic or user-generated content

## Local Assets

> **Important**: All local assets must be placed in the `assets/` folder at the root of your project. .

Local assets are stored in your project and served by the Jac server. Two methods are available:

### Static Path

Reference assets directly using the `/static/` path prefix.

#### Usage

```jac
<img src="/static/assets/burger.png" alt="Burger" />
<link rel="stylesheet" href="/static/styles.css" />
```

#### How It Works

- Assets in the `assets/` folder are served at `/static/assets/` path
- Assets in `dist/` are also accessible via `/static/`
- Server automatically detects file type and sets correct MIME type
- No build configuration required

#### When to Use

- Quick prototypes and simple applications
- Assets that don't require optimization
- Immediate results without build step

### Import Alias

Import assets using the `@jac-client/assets` alias for Vite-processed assets.

#### Usage

```jac
cl import from "@jac-client/assets/burger.png" { default as burgerImage }

<img src={burgerImage} alt="Burger" />
```

#### How It Works

- Alias configured in `vite.config.js` points to `compiled/assets/`
- Assets from root `assets/` folder are copied to `compiled/assets/` during build
- Vite processes imports and generates optimized asset URLs
- Automatic hash generation for cache busting

#### When to Use

- Production applications
- Assets that benefit from optimization
- Type-safe asset references
- Automatic cache busting

## Using Assets in CSS

Assets can be referenced in CSS files using static paths.

### Usage

**CSS File (`styles.css`):**

```css
.container {
    background-image: url('/static/assets/burger.png');
    background-size: cover;
    background-position: center;
}

.burgerImage {
    width: 200px;
    height: auto;
    border-radius: 10px;
}
```

**Jac File:**

```jac
cl import "./styles.css";

<div className="container">
    <img src="/static/assets/burger.png" className="burgerImage" alt="Burger" />
</div>
```

### Notes

- CSS files reference assets using `/static/` paths
- Assets are resolved at runtime by the server
- Works with both background images and regular image elements

## Supported Asset Types

Jac automatically serves and detects MIME types for:

- **Images**: `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.svg`, `.ico`, `.avif`
- **Fonts**: `.woff`, `.woff2`, `.ttf`, `.otf`, `.eot`
- **Media**: `.mp4`, `.webm`, `.ogg`, `.mov`, `.mp3`, `.wav`, `.m4a`
- **Documents**: `.pdf`
- **Stylesheets**: `.css`, `.scss`, `.sass`, `.less`

## Project Structure

```
project/
├── assets/              # Static assets (served via /static/)
│   ├── images/
│   ├── fonts/
│   └── videos/
├── compiled/
│   └── assets/         # Assets for import alias (@jac-client/assets)
└── dist/               # Vite output (auto-generated)
```

## Examples

Complete working examples are available:

- [`image-asset/`](../../examples/asset-serving/image-asset/) - Static path serving
- [`import-alias/`](../../examples/asset-serving/import-alias/) - Import alias pattern
- [`css-with-image/`](../../examples/asset-serving/css-with-image/) - Assets in CSS

Run any example:

```bash
cd jac-client/jac_client/examples/asset-serving/<example-name>
npm install
jac start main.jac
```

## Quick Reference

### Remote URLs

```jac
<img src="https://example.com/image.jpg" alt="Image" />
```

### Static Path

```jac
<img src="/static/assets/logo.png" alt="Logo" />
```

### Import Alias

```jac
cl import from "@jac-client/assets/logo.png" { default as logo }
<img src={logo} />
```

### CSS Assets

```css
.hero {
    background-image: url('/static/assets/hero.jpg');
}
```

## Troubleshooting

**Asset not found (404)**

- Verify file exists in `assets/` or `dist/` directory
- Check path matches file location exactly

**Import not resolving**

- Ensure `vite.config.js` has `@jac-client/assets` alias configured
- Verify assets are copied to `compiled/assets/` during build

**CSS background image not showing**

- Use `/static/` prefix in CSS `url()` paths
- Verify asset file exists in `assets/` directory

## Related Documentation

- [Import System](../imports.md)
- [Styling](../styling/intro.md)
- [Routing](../routing.md)
