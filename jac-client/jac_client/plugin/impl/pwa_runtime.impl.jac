"""PWA runtime implementation - install prompts, platform detection, and components."""

# =============================================================================
# CONSTANTS
# =============================================================================
glob PWA_STORAGE_KEY = "__jac_pwa_prefs__",
     PWA_DEFAULT_REPROMPT_DAYS = 7,
     PWA_MAX_REPROMPTS = 3,
     PWA_BACKOFF_MULTIPLIER = 2;

# =============================================================================
# PLATFORM DETECTION
# =============================================================================
impl getPlatform -> str {
    ua = navigator.userAgent;

    # iOS detection (iPhone, iPad, iPod, or iPad masquerading as Mac)
    iosPattern = Reflect.construct(RegExp, ["iPad|iPhone|iPod"]);
    if iosPattern.test(ua)
    or (navigator.platform == "MacIntel" and navigator.maxTouchPoints > 1) {
        return "ios";
    }

    # Android detection
    if ua.includes("Android") {
        return "android";
    }

    return "desktop";
}

impl isIos -> bool {
    return getPlatform() == "ios";
}

impl isAndroid -> bool {
    return getPlatform() == "android";
}

impl isSafari -> bool {
    ua = navigator.userAgent;
    # Safari but not Chrome (Chrome on iOS includes Safari in UA)
    return ua.includes("Safari")
    and not ua.includes("Chrome")
    and not ua.includes("CriOS");
}

impl isMobile -> bool {
    platform = getPlatform();
    return platform == "ios" or platform == "android";
}

# =============================================================================
# STANDALONE DETECTION
# =============================================================================
impl isStandalone -> bool {
    # Check display-mode media query
    if window.matchMedia("(display-mode: standalone)").matches {
        return True;
    }

    # iOS Safari standalone mode
    if window.navigator.standalone == True {
        return True;
    }

    # Android TWA
    if document.referrer.includes("android-app://") {
        return True;
    }

    return False;
}

impl useIsStandalone -> bool {
    [standalone, setStandalone] = reactUseState(isStandalone());

    reactUseEffect(
        lambda -> Any {
            # Listen for display-mode changes
            mediaQuery = window.matchMedia("(display-mode: standalone)");
            handler = lambda e: Any { setStandalone(e.matches);};
            mediaQuery.addEventListener("change", handler);
            return lambda { mediaQuery.removeEventListener("change", handler);};
        },
        []
    );

    return standalone;
}

# =============================================================================
# INSTALL PROMPT CAPTURE
# =============================================================================
impl captureInstallPrompt -> None {
    if window.__jacPwaPromptCaptured {
        return;
    }

    window.__jacPwaPrompt = None;
    window.__jacPwaPromptCaptured = True;

    window.addEventListener(
        "beforeinstallprompt",
        lambda e: Any {
            e.preventDefault();
            window.__jacPwaPrompt = e;
            window.dispatchEvent(
                Reflect.construct(CustomEvent, ["jac:pwa:promptready"])
            );
        }
    );

    window.addEventListener(
        "appinstalled",
        lambda {
            window.__jacPwaInstalled = True;
            window.__jacPwaPrompt = None;
            recordInstallSuccess();
            window.dispatchEvent(Reflect.construct(CustomEvent, ["jac:pwa:installed"]));
        }
    );
}

impl hasInstallPrompt -> bool {
    return window.__jacPwaPrompt != None;
}

impl triggerInstallPrompt -> bool {
    prompt = window.__jacPwaPrompt;

    if not prompt {
        return False;
    }

    recordInstallAttempt();
    prompt.prompt();

    result = await prompt.userChoice;

    if result.outcome == "accepted" {
        window.__jacPwaPrompt = None;
        return True;
    }

    return False;
}

# =============================================================================
# MANIFEST HELPERS
# =============================================================================
impl getManifest -> dict {
    try {
        manifestLink = document.querySelector('link[rel="manifest"]');
        if not manifestLink {
            return {};
        }

        response = await fetch(manifestLink.href);
        if not response.ok {
            return {};
        }

        return await response.json();
    } except Exception as e {
        console.warn("[jac-pwa] Failed to fetch manifest:", e);
        return {};
    }
}

impl getAppIcon -> str {
    try {
        manifest = await getManifest();
        icons = manifest.icons;

        if not icons or len(icons) == 0 {
            return "";
        }

        # Prefer 192x192
        for icon in icons {
            if icon.sizes == "192x192" {
                return icon.src;
            }
        }

        # Fallback to first icon
        return icons[0].src or "";
    } except Exception as e {
        console.warn("[jac-pwa] Failed to get app icon:", e);
        return "";
    }
}

impl getAppName -> str {
    try {
        manifest = await getManifest();
        return manifest.name or manifest.short_name or "";
    } except Exception as e {
        console.warn("[jac-pwa] Failed to get app name:", e);
        return "";
    }
}

# =============================================================================
# USER PREFERENCES STORAGE
# =============================================================================
impl getPwaUserPrefs -> dict {
    try {
        stored = localStorage.getItem(PWA_STORAGE_KEY);
        if stored {
            return JSON.parse(stored);
        }
    } except Exception as e {
        console.warn(
            "[jac-pwa] Failed to read PWA user preferences from localStorage:", e
        );
    }

    return {
        "dismissed": False,
        "dismissedAt": 0,
        "dismissCount": 0,
        "installAttempted": False,
        "installAttemptedAt": 0,
        "installed": False,
        "installedAt": 0,
        "platform": getPlatform(),
        "iosGuideShown": False,
        "iosGuideShownAt": 0
    };
}

impl setPwaUserPrefs(prefs: dict) -> None {
    try {
        current = getPwaUserPrefs();
        merged = Object.assign({}, current, prefs);
        localStorage.setItem(PWA_STORAGE_KEY, JSON.stringify(merged));
    } except Exception as e {
        console.warn(
            "[jac-pwa] Failed to save PWA user preferences to localStorage:", e
        );
    }
}

impl resetPwaUserPrefs -> None {
    try {
        localStorage.removeItem(PWA_STORAGE_KEY);
    } except Exception as e {
        console.warn("[jac-pwa] Failed to reset PWA user preferences:", e);
    }
}

# =============================================================================
# RE-PROMPT LOGIC
# =============================================================================
impl shouldShowInstallBanner -> bool {
    # Already installed
    if isStandalone() {
        return False;
    }

    prefs = getPwaUserPrefs();

    # Already installed (recorded)
    if prefs.installed {
        return False;
    }

    # Never dismissed
    if not prefs.dismissed {
        return True;
    }

    # Check max reprompts
    if prefs.dismissCount >= PWA_MAX_REPROMPTS {
        return False;
    }

    # Calculate required delay with exponential backoff
    # 7 days -> 14 days -> 28 days
    baseDelay = PWA_DEFAULT_REPROMPT_DAYS;
    multiplier = Math.pow(PWA_BACKOFF_MULTIPLIER, prefs.dismissCount - 1);
    requiredDelayDays = baseDelay * multiplier;

    # Check if enough time has passed
    daysSinceDismiss = (Date.now() - prefs.dismissedAt) / (1000 * 60 * 60 * 24);

    return daysSinceDismiss >= requiredDelayDays;
}

impl recordDismiss -> None {
    prefs = getPwaUserPrefs();
    setPwaUserPrefs(
        {
            "dismissed": True,
            "dismissedAt": Date.now(),
            "dismissCount": (prefs.dismissCount or 0) + 1
        }
    );
}

impl recordInstallAttempt -> None {
    setPwaUserPrefs({"installAttempted": True, "installAttemptedAt": Date.now()});
}

impl recordInstallSuccess -> None {
    setPwaUserPrefs({"installed": True, "installedAt": Date.now()});
}

# =============================================================================
# CORE HOOK
# =============================================================================
impl usePwaInstall -> dict {
    [canInstall, setCanInstall] = reactUseState(hasInstallPrompt() or isIos());
    [isInstalled, setIsInstalled] = reactUseState(isStandalone());
    [isPending, setIsPending] = reactUseState(False);
    [showBanner, setShowBanner] = reactUseState(shouldShowInstallBanner());
    [appName, setAppName] = reactUseState(None);
    [appIcon, setAppIcon] = reactUseState(None);
    [iosGuideOpen, setIosGuideOpen] = reactUseState(False);

    prefs = getPwaUserPrefs();
    platform = getPlatform();

    # Fetch manifest data on mount
    reactUseEffect(
        lambda -> Any {
            async def loadManifest {
                name = await getAppName();
                icon = await getAppIcon();
                setAppName(name);
                setAppIcon(icon);
            }
            loadManifest();
            return None;
        },
        []
    );

    # Listen for prompt ready event
    reactUseEffect(
        lambda -> Any {
            handler = lambda {
                setCanInstall(True);
                setShowBanner(shouldShowInstallBanner());
            };
            window.addEventListener("jac:pwa:promptready", handler);
            return lambda { window.removeEventListener(
                "jac:pwa:promptready", handler
            );};
        },
        []
    );

    # Listen for installed event
    reactUseEffect(
        lambda -> Any {
            handler = lambda {
                setIsInstalled(True);
                setCanInstall(False);
                setShowBanner(False);
            };
            window.addEventListener("jac:pwa:installed", handler);
            return lambda { window.removeEventListener("jac:pwa:installed", handler);};
        },
        []
    );

    # Install action
    async def install -> bool {
        if isIos() {
            setIosGuideOpen(True);
            return False;
        }

        if not hasInstallPrompt() {
            return False;
        }

        setIsPending(True);

        try {
            result = await triggerInstallPrompt();
            return result;
        } finally {
            setIsPending(False);
        }
    }

    # Show iOS guide
    def showIosGuide {
        setIosGuideOpen(True);
        setPwaUserPrefs({"iosGuideShown": True, "iosGuideShownAt": Date.now()});
    }

    # Dismiss action
    def dismiss {
        recordDismiss();
        setShowBanner(False);
    }

    # Close iOS guide
    def closeIosGuide {
        setIosGuideOpen(False);
    }

    return {
        "canInstall": canInstall,
        "isInstalled": isInstalled,
        "platform": platform,
        "shouldShowBanner": showBanner,
        "appName": appName,
        "appIcon": appIcon,
        "install": install,
        "showIosGuide": showIosGuide,
        "closeIosGuide": closeIosGuide,
        "iosGuideOpen": iosGuideOpen,
        "dismiss": dismiss,
        "isPending": isPending,
        "dismissCount": prefs.dismissCount or 0
    };
}

# =============================================================================
# GLASSMORPHIC STYLES
# =============================================================================
impl __getPwaStyles -> str {
    return '''
/* PWA Install Banner - Glassmorphic Design */
@keyframes jac-pwa-slide-up {
  from { transform: translateY(100%) scale(0.95); opacity: 0; }
  to { transform: translateY(0) scale(1); opacity: 1; }
}

@keyframes jac-pwa-slide-down {
  to { transform: translateY(100%) scale(0.95); opacity: 0; }
}

@keyframes jac-pwa-fade-in {
  from { opacity: 0; transform: scale(0.95); }
  to { opacity: 1; transform: scale(1); }
}

.jac-pwa-banner {
  position: fixed;
  bottom: 16px;
  left: 16px;
  right: 16px;
  max-width: 480px;
  margin: 0 auto;
  background: rgba(15, 15, 25, 0.92);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 20px;
  color: white;
  padding: 16px 20px;
  display: flex;
  align-items: center;
  gap: 14px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4), 0 0 0 1px rgba(255, 255, 255, 0.05) inset;
  z-index: 9999;
  font-family: system-ui, -apple-system, BlinkMacSystemFont, sans-serif;
  animation: jac-pwa-slide-up 0.4s cubic-bezier(0.16, 1, 0.3, 1);
}

.jac-pwa-banner--dismissing {
  animation: jac-pwa-slide-down 0.3s cubic-bezier(0.4, 0, 1, 1) forwards;
}

.jac-pwa-banner--top {
  bottom: auto;
  top: 16px;
}

.jac-pwa-banner__icon {
  width: 52px;
  height: 52px;
  border-radius: 14px;
  object-fit: cover;
  flex-shrink: 0;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.25);
  background: rgba(255, 255, 255, 0.1);
}

.jac-pwa-banner__content {
  flex: 1;
  min-width: 0;
}

.jac-pwa-banner__title {
  font-weight: 600;
  font-size: 15px;
  margin-bottom: 3px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.jac-pwa-banner__description {
  font-size: 13px;
  opacity: 0.75;
  line-height: 1.35;
}

.jac-pwa-banner__actions {
  display: flex;
  gap: 8px;
  flex-shrink: 0;
}

.jac-pwa-banner__install {
  background: linear-gradient(135deg, #6366f1, #8b5cf6, #a855f7);
  color: white;
  border: none;
  padding: 10px 20px;
  border-radius: 12px;
  font-weight: 600;
  font-size: 14px;
  cursor: pointer;
  transition: all 0.2s ease;
  box-shadow: 0 4px 15px rgba(99, 102, 241, 0.4);
}

.jac-pwa-banner__install:hover {
  transform: translateY(-1px);
  box-shadow: 0 6px 20px rgba(99, 102, 241, 0.5);
}

.jac-pwa-banner__install:active {
  transform: translateY(0) scale(0.98);
}

.jac-pwa-banner__dismiss {
  background: rgba(255, 255, 255, 0.08);
  color: rgba(255, 255, 255, 0.85);
  border: 1px solid rgba(255, 255, 255, 0.12);
  padding: 10px 16px;
  border-radius: 12px;
  font-size: 14px;
  cursor: pointer;
  transition: all 0.2s ease;
}

.jac-pwa-banner__dismiss:hover {
  background: rgba(255, 255, 255, 0.12);
  color: white;
}

/* iOS Guide Modal */
.jac-pwa-ios-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.4);
  backdrop-filter: blur(8px);
  -webkit-backdrop-filter: blur(8px);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20px;
  z-index: 10000;
  animation: jac-pwa-fade-in 0.3s ease-out;
}

.jac-pwa-ios-guide {
  background: rgba(20, 20, 30, 0.95);
  backdrop-filter: blur(24px);
  -webkit-backdrop-filter: blur(24px);
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 24px;
  padding: 28px 24px;
  max-width: 340px;
  width: 100%;
  text-align: center;
  color: white;
  box-shadow: 0 24px 48px rgba(0, 0, 0, 0.5);
  animation: jac-pwa-slide-up 0.4s cubic-bezier(0.16, 1, 0.3, 1);
}

.jac-pwa-ios-guide__title {
  font-size: 20px;
  font-weight: 700;
  margin-bottom: 8px;
}

.jac-pwa-ios-guide__subtitle {
  font-size: 14px;
  opacity: 0.7;
  margin-bottom: 24px;
}

.jac-pwa-ios-guide__steps {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin-bottom: 24px;
}

.jac-pwa-ios-guide__step {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 14px 16px;
  text-align: left;
  background: rgba(255, 255, 255, 0.06);
  border-radius: 14px;
  border: 1px solid rgba(255, 255, 255, 0.08);
}

.jac-pwa-ios-guide__step-num {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  background: linear-gradient(135deg, #6366f1, #a855f7);
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 600;
  font-size: 13px;
  flex-shrink: 0;
}

.jac-pwa-ios-guide__step-icon {
  font-size: 20px;
  width: 28px;
  text-align: center;
  flex-shrink: 0;
}

.jac-pwa-ios-guide__step-text {
  font-size: 14px;
  line-height: 1.4;
}

.jac-pwa-ios-guide__close {
  width: 100%;
  background: rgba(255, 255, 255, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.15);
  color: white;
  padding: 14px;
  border-radius: 14px;
  font-size: 15px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s ease;
}

.jac-pwa-ios-guide__close:hover {
  background: rgba(255, 255, 255, 0.15);
}

/* Mobile responsive */
@media (max-width: 520px) {
  .jac-pwa-banner {
    bottom: 12px;
    left: 12px;
    right: 12px;
    flex-wrap: wrap;
    padding: 14px 16px;
    border-radius: 16px;
  }
  .jac-pwa-banner__icon {
    width: 44px;
    height: 44px;
  }
  .jac-pwa-banner__actions {
    width: 100%;
    margin-top: 14px;
  }
  .jac-pwa-banner__install,
  .jac-pwa-banner__dismiss {
    flex: 1;
    text-align: center;
    padding: 12px 16px;
  }
}
''';
}

# =============================================================================
# COMPONENTS
# =============================================================================
impl PwaInstallBanner(props: dict) -> JsxElement {
    pwa = usePwaInstall();
    [visible, setVisible] = reactUseState(False);
    [dismissing, setDismissing] = reactUseState(False);

    # Props with defaults
    title = props.title or pwa.appName or "Install App";
    description = props.description or "Add to home screen for the best experience";
    installText = props.installText or "Install";
    dismissText = props.dismissText or "Not now";
    showIcon = props.showIcon if props.showIcon != None else True;
    iconSize = props.iconSize or 52;
    showAfterMs = props.showAfterMs or 3000;
    position = props.position or "bottom";
    className = props.className or "";
    style = props.style or {};

    # Show after delay
    reactUseEffect(
        lambda -> Any {
            if not pwa.shouldShowBanner or pwa.isInstalled { return None;  }
            timer = setTimeout(lambda { setVisible(True);}, showAfterMs);
            return lambda { clearTimeout(timer);};
        },
        [pwa.shouldShowBanner, pwa.isInstalled]
    );

    # Handle dismiss with animation
    def handleDismiss {
        setDismissing(True);
        setTimeout(
            lambda {
                pwa.dismiss();
                setVisible(False);
                setDismissing(False);
            },
            300
        );
    }

    # Handle install
    async def handleInstall {
        result = await pwa.install();
        if result {
            setVisible(False);
        }
    }

    # Don't render if not visible
    if not visible {
        return
            <></>;
    }

    # Build class names
    bannerClass = "jac-pwa-banner";
    if dismissing {
        bannerClass = bannerClass + " jac-pwa-banner--dismissing";
    }
    if position == "top" {
        bannerClass = bannerClass + " jac-pwa-banner--top";
    }
    if className {
        bannerClass = bannerClass + " " + className;
    }

    return (
        <>
            <style>{__getPwaStyles()}</style>
            <div className={bannerClass} style={style}>
                {showIcon
                and pwa.appIcon
                and (
                    <img
                        className="jac-pwa-banner__icon"
                        src={pwa.appIcon}
                        alt=""
                        style={{width: iconSize, height: iconSize}}
                    />
                )}
                <div className="jac-pwa-banner__content">
                    <div className="jac-pwa-banner__title">{title}</div>
                    <div className="jac-pwa-banner__description">{description}</div>
                </div>
                <div className="jac-pwa-banner__actions">
                    <button
                        className="jac-pwa-banner__install"
                        onClick={handleInstall}
                        disabled={pwa.isPending}
                    >
                        {pwa.isPending and "..." or installText}
                    </button>
                    <button className="jac-pwa-banner__dismiss" onClick={handleDismiss}>
                        {dismissText}
                    </button>
                </div>
            </div>
            {pwa.iosGuideOpen
            and (
                <IosInstallGuide
                    isOpen={pwa.iosGuideOpen}
                    onClose={pwa.closeIosGuide}
                    appName={pwa.appName}
                />
            )}
        </>
    );
}

impl PwaInstallButton(props: dict) -> JsxElement {
    pwa = usePwaInstall();

    children = props.children or "Install";
    className = props.className or "jac-pwa-banner__install";
    style = props.style or {};
    onInstalled = props.onInstalled;

    async def handleClick {
        result = await pwa.install();
        if result and onInstalled {
            onInstalled();
        }
    }

    if not pwa.canInstall or pwa.isInstalled {
        return
            <></>;
    }

    return (
        <>
            <style>{__getPwaStyles()}</style>
            <button
                className={className}
                style={style}
                onClick={handleClick}
                disabled={pwa.isPending}
            >
                {children}
            </button>
            {pwa.iosGuideOpen
            and (
                <IosInstallGuide
                    isOpen={pwa.iosGuideOpen}
                    onClose={pwa.closeIosGuide}
                    appName={pwa.appName}
                />
            )}
        </>
    );
}

impl IosInstallGuide(props: dict) -> JsxElement {
    isOpen = props.isOpen;
    onClose = props.onClose;
    appName = props.appName or "this app";
    title = props.title or f"Install {appName}";
    className = props.className or "";

    if not isOpen {
        return
            <></>;
    }

    return (
        <>
            <style>{__getPwaStyles()}</style>
            <div className="jac-pwa-ios-overlay" onClick={onClose}>
                <div
                    className={"jac-pwa-ios-guide " + className}
                    onClick={lambda e: Any { e.stopPropagation();}}
                >
                    <div className="jac-pwa-ios-guide__title">{title}</div>
                    <div className="jac-pwa-ios-guide__subtitle">
                        Add to your home screen
                    </div>
                    <div className="jac-pwa-ios-guide__steps">
                        <div className="jac-pwa-ios-guide__step">
                            <span className="jac-pwa-ios-guide__step-num">1</span>
                            <span className="jac-pwa-ios-guide__step-icon">↑</span>
                            <span className="jac-pwa-ios-guide__step-text">
                                Tap the
                                <strong>Share</strong>
                                button
                            </span>
                        </div>
                        <div className="jac-pwa-ios-guide__step">
                            <span className="jac-pwa-ios-guide__step-num">2</span>
                            <span className="jac-pwa-ios-guide__step-icon">+</span>
                            <span className="jac-pwa-ios-guide__step-text">
                                Tap
                                <strong>Add to Home Screen</strong>
                            </span>
                        </div>
                        <div className="jac-pwa-ios-guide__step">
                            <span className="jac-pwa-ios-guide__step-num">3</span>
                            <span className="jac-pwa-ios-guide__step-icon">✓</span>
                            <span className="jac-pwa-ios-guide__step-text">
                                Tap
                                <strong>Add</strong>
                                to confirm
                            </span>
                        </div>
                    </div>
                    <button className="jac-pwa-ios-guide__close" onClick={onClose}>
                        Got it
                    </button>
                </div>
            </div>
        </>
    );
}

# =============================================================================
# INITIALIZATION
# =============================================================================
impl __jacPwaInit -> None {
    # Capture install prompt as early as possible
    captureInstallPrompt();
}
