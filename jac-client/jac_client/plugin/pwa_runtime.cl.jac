"""PWA runtime for Jac client - install prompts and platform detection.

This module is only bundled when PWA is enabled via `jac setup pwa`.
Import alias: @jac/pwa

Usage (automatic - no imports needed):
  After `jac setup pwa`, the install banner appears automatically.

Usage (manual control):
  import from '@jac/pwa' { usePwaInstall, PwaInstallButton }
"""

import from 'react' { useState as reactUseState, useEffect as reactUseEffect }

# =============================================================================
# PLATFORM DETECTION
# =============================================================================
"""Detect current platform: 'ios' | 'android' | 'desktop' | 'unknown'"""
def:pub getPlatform -> str;

"""Check if running on iOS (iPhone, iPad, iPod)."""
def:pub isIos -> bool;

"""Check if running on Android."""
def:pub isAndroid -> bool;

"""Check if running in Safari browser."""
def:pub isSafari -> bool;

"""Check if running on mobile (iOS or Android)."""
def:pub isMobile -> bool;

# =============================================================================
# STANDALONE DETECTION
# =============================================================================
"""Check if app is running as installed PWA (standalone mode)."""
def:pub isStandalone -> bool;

"""React hook - returns true if running as installed PWA."""
def:pub useIsStandalone -> bool;

# =============================================================================
# INSTALL PROMPT CAPTURE
# =============================================================================
"""Capture beforeinstallprompt event. Called automatically, exposed for manual use."""
def:pub captureInstallPrompt -> None;

"""Check if install prompt was captured and is available."""
def:pub hasInstallPrompt -> bool;

"""Trigger the native install prompt. Returns true if user accepted."""
async def:pub triggerInstallPrompt -> bool;

# =============================================================================
# MANIFEST HELPERS
# =============================================================================
"""Fetch and parse the PWA manifest.json."""
async def:pub getManifest -> dict;

"""Get the best app icon URL from manifest (prefers 192x192)."""
async def:pub getAppIcon -> str;

"""Get the app name from manifest."""
async def:pub getAppName -> str;

# =============================================================================
# USER PREFERENCES STORAGE
# =============================================================================
"""Get PWA user preferences from localStorage."""
def:pub getPwaUserPrefs -> dict;

"""Update PWA user preferences (merges with existing)."""
def:pub setPwaUserPrefs(prefs: dict) -> None;

"""Reset all PWA user preferences."""
def:pub resetPwaUserPrefs -> None;

# =============================================================================
# RE-PROMPT LOGIC
# =============================================================================
"""Check if install banner should be shown (considers dismiss history + backoff)."""
def:pub shouldShowInstallBanner -> bool;

"""Record that user dismissed the install banner."""
def:pub recordDismiss -> None;

"""Record that user attempted to install."""
def:pub recordInstallAttempt -> None;

"""Record successful installation."""
def:pub recordInstallSuccess -> None;

# =============================================================================
# CORE HOOK
# =============================================================================
"""Main PWA install hook - handles all install logic.

Returns:
  {
    canInstall: bool,        # True if install prompt available (or iOS)
    isInstalled: bool,       # True if running as standalone PWA
    platform: str,           # 'ios' | 'android' | 'desktop' | 'unknown'
    shouldShowBanner: bool,  # Considers dismiss history + backoff

    appName: str | None,     # App name from manifest
    appIcon: str | None,     # Best icon URL from manifest

    install: () -> Promise[bool],  # Trigger install
    showIosGuide: () -> None,      # Show iOS instructions
    dismiss: () -> None,           # Record dismiss

    isPending: bool,         # Install in progress
    dismissCount: int,       # Times user has dismissed
  }
"""
def:pub usePwaInstall -> dict;

# =============================================================================
# COMPONENTS
# =============================================================================
"""Install banner component - glassmorphic floating banner.

Props:
  title?: str                 # Banner title (default: app name from manifest)
  description?: str           # Description text
  installText?: str           # Install button text (default: "Install")
  dismissText?: str           # Dismiss button text (default: "Not now")
  showIcon?: bool             # Show app icon (default: true)
  iconSize?: int              # Icon size in px (default: 52)
  animation?: str             # 'slide' | 'fade' | 'none' (default: 'slide')
  position?: str              # 'bottom' | 'top' (default: 'bottom')
  showAfterMs?: int           # Delay before showing (default: 3000)
  repromptAfterDays?: int     # Days before re-showing (default: 7)
  maxReprompts?: int          # Max re-prompts (default: 3)
  className?: str             # Custom CSS class
  style?: dict                # Custom inline styles
"""
def:pub PwaInstallBanner(props: dict) -> JsxElement;

"""Standalone install button component.

Props:
  children?: Any              # Button content
  className?: str             # Custom CSS class
  style?: dict                # Custom inline styles
  onInstalled?: () -> None    # Callback after successful install
"""
def:pub PwaInstallButton(props: dict) -> JsxElement;

"""iOS install instructions modal.

Props:
  isOpen: bool                # Whether modal is open
  onClose: () -> None         # Close callback
  title?: str                 # Modal title (default: "Install [App Name]")
  className?: str             # Custom CSS class
"""
def:pub IosInstallGuide(props: dict) -> JsxElement;

# =============================================================================
# INTERNAL - Called by build system
# =============================================================================
"""Initialize PWA runtime. Called automatically during app bootstrap."""
def:pub __jacPwaInit -> None;

"""Get the CSS styles for PWA components."""
def:pub __getPwaStyles -> str;
