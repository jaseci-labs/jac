import from 'react' { useState as reactUseState, useEffect as reactUseEffect }

obj:pub ManifestIcon {
    has src: str = "",
        sizes: str = "";
}

obj:pub WebAppManifest {
    has name: str = "",
        short_name: str = "",
        icons: list[ManifestIcon] = [];
}

obj:pub PwaUserPrefs {
    has dismissed: bool = False,
        dismissedAt: float = 0.0,
        dismissCount: int = 0,
        installAttempted: bool = False,
        installAttemptedAt: float = 0.0,
        installed: bool = False,
        installedAt: float = 0.0,
        platform: str = "",
        iosGuideShown: bool = False,
        iosGuideShownAt: float = 0.0;
}

obj:pub InstallChoice {
    has outcome: str = "",
        platform: str = "";
}

obj:pub InstallPromptEvent {
    has userChoice: Promise[InstallChoice],
        prompt: Callable[[], None];
}

obj:pub PwaInstallState {
    has canInstall: bool,
        isInstalled: bool,
        platform: str,
        shouldShowBanner: bool,
        appName: str,
        appIcon: str,
        install: Callable[[], bool],
        showIosGuide: Callable[[], None],
        closeIosGuide: Callable[[], None],
        iosGuideOpen: bool,
        dismiss: Callable[[], None],
        isPending: bool,
        dismissCount: int;
}

def _useBool(initial: bool) -> tuple[bool, Callable[[bool], None]];

def _useStr(initial: str) -> tuple[str, Callable[[str], None]];

def _installPrompt -> (InstallPromptEvent | None);

def _dispatchPwaEvent(name: str) -> None;

def:pub getPlatform -> str;

def:pub isIos -> bool;

def:pub isAndroid -> bool;

def:pub isSafari -> bool;

def:pub isMobile -> bool;

def:pub isStandalone -> bool;

def:pub useIsStandalone -> bool;

def:pub captureInstallPrompt -> None;

def:pub hasInstallPrompt -> bool;

async def:pub triggerInstallPrompt -> bool;

async def:pub getManifest -> WebAppManifest;

async def:pub getAppIcon -> str;

async def:pub getAppName -> str;

def:pub getPwaUserPrefs -> PwaUserPrefs;

def:pub setPwaUserPrefs(prefs: dict[str, object]) -> None;

def:pub resetPwaUserPrefs -> None;

def:pub shouldShowInstallBanner -> bool;

def:pub recordDismiss -> None;

def:pub recordInstallAttempt -> None;

def:pub recordInstallSuccess -> None;

def:pub usePwaInstall -> PwaInstallState;

def:pub PwaInstallBanner(
    title: str = "",
    description: str = "Add to home screen for the best experience",
    installText: str = "Install",
    dismissText: str = "Not now",
    showIcon: bool = True,
    iconSize: int = 52,
    showAfterMs: int = 3000,
    position: str = "bottom",
    className: str = "",
    style: (dict[str, object] | None) = None
) -> JsxElement;

def:pub PwaInstallButton(
    children: object = "Install",
    className: str = "jac-pwa-banner__install",
    style: (dict[str, object] | None) = None,
    onInstalled: (Callable[[], None] | None) = None
) -> JsxElement;

def:pub IosInstallGuide(
    isOpen: bool = False,
    onClose: (Callable[[], None] | None) = None,
    appName: str = "",
    title: str = "",
    className: str = ""
) -> JsxElement;

def:pub __jacPwaInit -> None;

def:pub __getPwaStyles -> str;
