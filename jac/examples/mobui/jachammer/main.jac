"""jachammer — a pocket Jac studio, cross-platform from one source.

The mobile-first counterpart to jacBuilder: describe an app to the AI build
assistant, watch it work, preview it in a device frame, then browse / deploy /
monitor / share your projects and manage billing — all built entirely from
portable `@jac/mobui` primitives, so the same source runs on the web
(react-native-web) and on a real device (Expo / Metro). There is no `<div>` here.

    jac start main.jac --client react-native --dev   # native (primary target)
    jac start main.jac --dev                          # web preview

jachammer is a pure client of the hosted **jacBuilder** backend
(`https://jac-builder-dev.jaseci.org`) — there is no local backend here.

Code layout (organized like jacBuilder — see README):
    services/jacbuilder.cl.jac   walker RPC wrappers (one per endpoint)
    store.cl.jac                 useStudio() + StudioProvider (all state/actions)
    components.cl.jac            shared presentational components
    screens/                     one file per screen family
    theme.cl.jac  icon(.native)  design tokens + platform-split icons

This file is just the entry: it wraps the app in the store provider and switches
between the splash / auth / app surfaces, layering the sheet overlays on top.
"""

cl {
    import from "@jac/mobui" { View, Platform, useWindowDimensions }
    import from .hooks.useStudio { StudioProvider, useStudio }
    import from .screens.AuthScreen { SplashScreen, AuthScreen }
    import from .screens.AppShell { AppShell }
    import from .screens.BillingScreen { BillingScreen }
    import from .screens.Sheets {
        NewModal, NotifsSheet, ModelSheet, ProjMenu, RenameSheet, ShareSheet,
        DeleteSheet, FileSheet
    }
    import from .components.SsoModal { SsoModal }

    # The root surface — consumes the store, switches splash/auth/app, and layers
    # the modal sheets on top. Every child is rendered as a JSX element (not a
    # function call) so each keeps its own hook scope.
    def:pub Root -> JsxElement {
        s = useStudio();
        styles = s["styles"];
        screen = s["screen"];
        viewport_dims = useWindowDimensions();
        # Web needs an explicit height to fill the viewport; native must stay
        # flex:1 (a fixed height blocks KeyboardAvoidingView from lifting inputs).
        rootExtra = {"height": viewport_dims.height} if Platform.OS == "web" else {};
        return
            <View style={[styles.root, rootExtra]}>
                {<SplashScreen/>
                    if (screen == "splash")
                    else (<AuthScreen/> if (screen == "auth") else <AppShell/>)}
                {<NewModal/> if s["showNew"] else <View/>}
                {<NotifsSheet/> if s["notifOpen"] else <View/>}
                {<ModelSheet/> if s["modelSheet"] else <View/>}
                {<ProjMenu/> if (s["projMenu"] != "") else <View/>}
                {<RenameSheet/> if (s["renameId"] != "") else <View/>}
                {<ShareSheet/> if (s["shareId"] != "") else <View/>}
                {<DeleteSheet/> if (s["deleteId"] != "") else <View/>}
                {<FileSheet/> if (s["fileView"] != "") else <View/>}
                {<BillingScreen/> if s["billingOpen"] else <View/>}
                {<SsoModal/> if (s["ssoUrl"] != "") else <View/>}
            </View>;
    }

    def:pub app -> JsxElement {
        return <StudioProvider><Root/></StudioProvider>;
    }
}
