# Application Metadata Configuration

Configure custom HTML metadata for your Jac Client application to enhance SEO, social media sharing, and browser display capabilities.

## Overview

By default, Jac Client renders a minimal HTML head with basic charset and title elements. With custom metadata configuration, you can extend this to include descriptions, Open Graph tags for social sharing, favicon, viewport settings, theme colors, and other essential meta tags that improve your application's discoverability and presentation.

## Quick Start

### Configuration Location

Application metadata is configured under `[plugins.client.app_meta_data]` in your `jac.toml`:

```toml
[project]
name = "my-app"
version = "1.0.0"
entry-point = "src/app.jac"

[plugins.client.app_meta_data]
title = "My Awesome App"
description = "A powerful application built with Jac Client"
icon = "/favicon.ico"
viewport = "width=device-width, initial-scale=1.0"
```

**Project Structure:**

```
my-jac-project/
├── jac.toml
├── src/
│   └── app. jac
└── assets/
    └── favicon.ico      # Application icon

```

## Metadata Configuration Keys

**Available Options**:

| Option | Description | Default |
|--------|-------------|---------|
| `charset` | Character encoding for the HTML document | `"UTF-8"` |
| `title` | Application title displayed in browser tab and search results | Function name |
| `viewport` | Viewport meta tag for responsive design | `"width=device-width, initial-scale=1"` |
| `description` | Application description for SEO and social sharing | `None` |
| `robots` | Instructs search engine crawlers how to index the page | `"index, follow"` |
| `canonical` | Canonical URL to prevent duplicate content issues | `None` |
| `og_type` | Open Graph type (e.g., "website", "article") | `"website"` |
| `og_title` | Open Graph title for social media sharing | Same as `title` |
| `og_description` | Open Graph description for social media sharing | Same as `description` |
| `og_url` | Open Graph URL for social media sharing | `None` |
| `og_image` | Open Graph image URL for social media previews | `None` |
| `theme_color` | Browser theme color (affects mobile browser UI) | `"#ffffff"` |
| `icon` | Path to favicon file (relative to assets directory) | `None` |

## How It Works

### Metadata Rendering Workflow

```
1. Developer configures metadata in jac.toml
   ↓
2. render_page() method reads config via get_plugin_config()
   ↓
3.  Metadata values are extracted from [plugins.client.app_meta_data]
   ↓
4. HTML head content is dynamically generated
   ↓
5. Meta tags are injected into <head> section
   ↓
6. Page renders with complete SEO and social sharing support
```

The `render_page` method in `client.impl.jac` processes all metadata configuration and generates standard meta tags, Open Graph tags, and favicon links automatically.

### Generated HTML Structure

The following HTML structure is generated based on your configuration:

```html
<head>
    <meta charset="UTF-8"/>
    <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
    <title>Your App Title</title>
    <meta name="robots" content="index, follow"/>
    <meta name="theme-color" content="#ffffff"/>
    <meta property="og:type" content="website"/>
    <meta property="og:title" content="Your App Title"/>
    <meta name="description" content="Your description"/>
    <link rel="icon" href="/favicon. ico"/>
    <meta property="og:url" content="https://yourapp.com"/>
    <meta property="og: image" content="https://yourapp.com/preview.png"/>
    <meta property="og:description" content="Your description"/>
</head>
```

## Use Cases

### 1. **Complete SEO Setup**

Optimize your application for search engines:

```toml
[plugins.client.app_meta_data]
title = "TaskMaster - Project Management Tool"
description = "Streamline your team's workflow with TaskMaster, the intuitive project management solution"
robots = "index, follow"
canonical = "https://taskmaster.io"
theme_color = "#6366f1"
icon = "/assets/logo.png"
```

### 2. **Social Media Sharing Optimization**

Enhance how your app appears when shared on social platforms:

```toml
[plugins.client.app_meta_data]
title = "Portfolio - John Doe"
description = "Full-stack developer specializing in Jac applications"
og_type = "profile"
og_title = "John Doe - Full Stack Developer"
og_description = "Check out my latest projects and case studies"
og_url = "https://johndoe.dev"
og_image = "https://johndoe.dev/assets/og-preview.png"
icon = "/assets/avatar.png"
```

### 3. **Mobile-Optimized Progressive Web App**

Configure for optimal mobile experience:

```toml
[plugins.client.app_meta_data]
title = "FitTrack - Fitness Companion"
description = "Track your workouts, nutrition, and health goals"
viewport = "width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes"
theme_color = "#10b981"
icon = "/assets/icon-192.png"
```

### 4. **Blog or Content Platform**

Optimize for content discovery and sharing:

```toml
[plugins.client.app_meta_data]
title = "Tech Insights Blog"
description = "Latest trends in software development and technology"
og_type = "article"
og_title = "Tech Insights - Your Daily Tech News"
og_description = "Stay updated with cutting-edge tech articles"
og_url = "https://techinsights.blog"
og_image = "https://techinsights.blog/assets/banner.jpg"
canonical = "https://techinsights.blog"
robots = "index, follow"
```

## Complete Configuration Example

Here's a full example combining all metadata options:

```toml
[project]
name = "my-ecommerce-app"
version = "1.0.0"
entry-point = "src/app.jac"

[plugins. client.app_meta_data]
# Basic metadata
charset = "UTF-8"
title = "ShopHub - Online Marketplace"
viewport = "width=device-width, initial-scale=1.0, maximum-scale=5.0"
description = "Discover thousands of products from local and international sellers"
icon = "/assets/favicon.ico"

# SEO configuration
robots = "index, follow"
canonical = "https://shophub.com"

# Browser customization
theme_color = "#ff6b6b"

# Open Graph (Social Media)
og_type = "website"
og_title = "ShopHub - Your One-Stop Online Marketplace"
og_description = "Shop from thousands of sellers with fast shipping and secure checkout"
og_url = "https://shophub.com"
og_image = "https://shophub.com/assets/og-preview.png"
```

## Related Documentation

- [Custom Configuration](./custom-config.md) - Complete configuration guide including Vite and TypeScript
- [Configuration Overview](./configuration-overview.md) - All available configuration options
- [All-in-One Example](https://github.com/jaseci-labs/jaseci/tree/main/jac-client/jac_client/examples/all-in-one) - Working example with metadata configuration

---
