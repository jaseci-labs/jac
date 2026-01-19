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

## Metadata Configuration Keys

### Standard Metadata Fields

These fields are processed as standard `<meta name="..." content="...">` tags:

| Field | Description | Default |
|-------|-------------|---------|
| `charset` | Character encoding for the HTML document | `"UTF-8"` |
| `title` | Application title displayed in browser tab and search results | funtion_name |
| `viewport` | Viewport meta tag for responsive design | `"width=device-width,initial-scale=1"` |
| `description` | Application description for SEO and social sharing | `None` |
| `keywords` | SEO keywords (comma-separated) | `None` |
| `author` | Author or creator of the application | `None` |
| `robots` | Instructs search engine crawlers how to index the page | `None` |
| `theme_color` | Browser theme color (affects mobile browser UI) | `None` |

### Open Graph Tags

| Field | Converts To | Description |
|-------|-------------|-------------|
| `og_type` | `og:type` | Open Graph type (e.g., "website", "article") |
| `og_title` | `og:title` | Open Graph title for social media sharing |
| `og_description` | `og:description` | Open Graph description for social media sharing |
| `og_url` | `og:url` | Open Graph URL for social media sharing |
| `og_image` | `og:image` | Open Graph image URL for social media previews |
| `og_site_name` | `og:site:name` | Name of the overall site |

**Example conversion:**

```toml
og_image_width = "1200"  # Becomes: <meta property="og:image:width" content="1200" />
```

### Link Tags

| Field | Rel Attribute | Description |
|-------|---------------|-------------|
| `canonical` | `canonical` | Canonical URL to prevent duplicate content issues |
| `icon` | `icon` | Path to favicon file |
| `apple_touch_icon` | `apple-touch-icon` | Apple touch icon for iOS devices |
| `manifest` | `manifest` | Web app manifest file |

```toml
link_preconnect = "https://fonts.googleapis.com"
# Becomes: <link rel="preconnect" href="https://fonts.googleapis.com" />
```

### Generic Meta Tags

Any field prefixed with `meta_` creates a custom meta tag. The prefix is removed and underscores are converted to hyphens:

```toml
meta_application_name = "MyApp"
# Becomes: <meta name="application-name" content="MyApp" />

meta_custom_field = "custom value"
# Becomes: <meta name="custom-field" content="custom value" />
```

## Use Cases

### 1. **Complete SEO Setup**

Optimize your application for search engines:

```toml
[plugins.client.app_meta_data]
title = "TaskMaster - Project Management Tool"
description = "Streamline-your-team's-workflow-with-TaskMaster,-the-intuitive-project-management-solution"
keywords = "project-management,task-tracking,team-collaboration"
author = "TaskMaster-Team"
robots = "index,follow"
canonical = "https://taskmaster.io"
theme_color = "#6366f1"
icon = ".assets/logo.png"
```

### 2. **Social Media Sharing Optimization**

Enhance how your app appears when shared on social platforms:

```toml
[plugins.client.app_meta_data]
title = "Portfolio - John Doe"
description = "Full-stack-developer-specializing-in-Jac-applications"
og_type = "profile"
og_title = "John-Doe-Full-Stack-Developer"
og_description = "Check-out-my-latest-projects-and-case-studies"
og_url = "https://johndoe.dev"
og_image = "https://johndoe.dev/assets/og-preview.png"
og_image_width = "1200"
og_image_height = "630"
icon = ".assets/avatar.png"
```

### 3. **Blog or Content Platform**

Optimize for content discovery and sharing:

```toml
[plugins.client.app_meta_data]
title = "Tech Insights Blog"
description = "Latest-trends-in-software-development-and-technology"
author = "Tech-Insights-Editorial-Team"
keywords = "technology,software-development,programming,tech news"
og_type = "article"
og_title = "Tech-Insights-Your-Daily-Tech-News"
og_description = "Stay-updated-with-cutting-edge-tech-articles"
og_url = "https://techinsights.blog"
og_image = "https://techinsights.blog/assets/banner.jpg"
canonical = "https://techinsights.blog"
robots = "index,follow"
```

### 4. **Custom Meta and Link Tags**

Using the flexible prefix system for advanced configuration:

```toml
[plugins.client.app_meta_data]
title = "Advanced App"
description = "App-with-custom-metadata-configuration"

# Custom meta tags (meta_ prefix)
meta_application_name = "AdvancedApp"
meta_google_site_verification = "your-verification-code"
meta_msapplication_TileColor = "#da532c"

# Custom link tags (link_ prefix)
link_preconnect = "https://fonts.googleapis.com"
link_dns_prefetch = "https://cdn.example.com"
link_stylesheet = "https://fonts.googleapis.com/css2?family=Roboto"

# Standard tags
theme_color = "#ffffff"
canonical = "https://example.com"
```

## Complete Configuration Example

Here's a full example combining all metadata options:

```toml
[project]
name = "my-ecommerce-app"
version = "1.0.0"
entry-point = "src/app.jac"

[plugins.client.app_meta_data]
# Special tags (processed first)
charset = "UTF-8"
title = "ShopHub - Online Marketplace"
viewport = "width=device-width, initial-scale=1.0, maximum-scale=5.0"

# Standard meta tags
description = "Discover thousands of products from local and international sellers"
keywords = "ecommerce, online shopping, marketplace, retail"
author = "ShopHub Inc."
robots = "index, follow"
theme_color = "#ff6b6b"

# Link tags
icon = "/assets/favicon.ico"
canonical = "https://shophub.com"
apple_touch_icon = "/assets/apple-touch-icon.png"
manifest = "/manifest.json"

# Open Graph (Social Media)
og_type = "website"
og_title = "ShopHub - Your One-Stop Online Marketplace"
og_description = "Shop from thousands of sellers with fast shipping and secure checkout"
og_url = "https://shophub.com"
og_image = "https://shophub.com/assets/og-preview.png"
og_image_width = "1200"
og_image_height = "630"
og_site_name = "ShopHub"

# Custom meta tags
meta_application_name = "ShopHub"
meta_google_site_verification = "abc123xyz"

# Custom link tags
link_preconnect = "https://fonts.googleapis.com"
```

## Key Implementation Details

1. **Processing Order**: Tags are built in a specific order - special tags first, followed by standard meta tags, Open Graph tags, link tags, and finally generic meta tags.

2. **Name Normalization**: Underscores in field names are automatically converted to hyphens for proper HTML attribute formatting.

3. **Open Graph Conversion**: The `og_` prefix is replaced with `og:`, and underscores become colons (e.g., `og_image_width` → `og:image:width`).

4. **Flexible Prefixes**: Use `meta_` for custom meta tags and `link_` for custom link tags to extend beyond the standard fields.

5. **HTML Escaping**: All values are automatically HTML-escaped to prevent injection vulnerabilities.

6. **Defaults**: Only `charset` and `viewport` have default values. All other fields are optional.

## Related Documentation

- [Custom Configuration](./custom-config.md) - Complete configuration guide including Vite and TypeScript
- [Configuration Overview](./configuration-overview.md) - All available configuration options
- [All-in-One Example](https://github.com/jaseci-labs/jaseci/tree/main/jac-client/jac_client/examples/all-in-one) - Working example with metadata configuration

---
