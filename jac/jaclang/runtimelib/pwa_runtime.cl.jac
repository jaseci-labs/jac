import from 'react' { useState as reactUseState, useEffect as reactUseEffect }

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

async def:pub getManifest -> dict;

async def:pub getAppIcon -> str;

async def:pub getAppName -> str;

def:pub getPwaUserPrefs -> dict;

def:pub setPwaUserPrefs(prefs: dict) -> None;

def:pub resetPwaUserPrefs -> None;

def:pub shouldShowInstallBanner -> bool;

def:pub recordDismiss -> None;

def:pub recordInstallAttempt -> None;

def:pub recordInstallSuccess -> None;

def:pub usePwaInstall -> dict;

def:pub PwaInstallBanner(props: dict) -> JsxElement;

def:pub PwaInstallButton(props: dict) -> JsxElement;

def:pub IosInstallGuide(props: dict) -> JsxElement;

def:pub __jacPwaInit -> None;

def:pub __getPwaStyles -> str;
