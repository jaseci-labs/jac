import from 'react' { * as React }
import from 'react' { useState as reactUseState, useEffect as reactUseEffect }
import from 'react-native' {
    View as RNView,
    Text as RNText,
    Pressable as RNPressable,
    TextInput as RNTextInput,
    Image as RNImage,
    Linking as RNLinking
}
import from '@react-navigation/native' {
    NavigationContainer as JacNavigationContainer,
    CommonActions as JacCommonActions,
    useNavigation as jacUseNavigation,
    useRoute as jacUseRoute
}
import from '@react-navigation/native-stack' {
    createNativeStackNavigator as jacCreateNativeStackNavigator
}
import from 'expo-secure-store' { * as SecureStore }
import from 'expo-constants' { * as ExpoConstants }
import from 'react-error-boundary' { ErrorBoundary }
import from 'zod' { z }
import from client_runtime_core {
    __createJacSchema,
    jacIsLoggedIn,
    useJacForm,
    __jacReportError
}
import from jaclang.runtimelib.client.targets.react_native.html_tag_map {
    RN_HTML_VIEW_TAGS as _VIEW_TAGS,
    RN_HTML_TEXT_TAGS as _TEXT_TAGS
}

def:pub __jacGetRenderer -> any;
def:pub __jacNativeCreate(
    tag: any, props: dict = {}, children: any = []
) -> JsxElement;

glob _UNMAPPED_WARNED = {},
     _RELATIVE_IMG_SRC_WARNED = {},
     _JAC_NATIVE_OUTLET_CONTEXT = React.createContext(None),
     _JAC_NATIVE_STACK = jacCreateNativeStackNavigator();

glob:pub useState = reactUseState,
     useEffect = reactUseEffect,
     Router = __nativeRouter,
     Routes = __nativeRoutes,
     Route = __nativeRoute,
     Link = __nativeLink,
     Navigate = __nativeNavigate,
     Outlet = __nativeOutlet,
     JacClientErrorBoundary = ErrorBoundary,
     JacSchema = __createJacSchema(z);

def _adaptProps(tag: str, props: dict) -> dict;
def _isAbsoluteImageUri(src: str) -> bool;
def _adaptImageProps(props: dict) -> dict;
def _textStyleFrom(style: any) -> dict;
def _prepend_args(comp: any, props: any, children: list) -> list;
def _makeNativeLink(props: dict, children: list) -> JsxElement;
def _toChildrenArray(children: any) -> list;
def _normalizeRoutePath(path: str) -> str;
def _joinRoutePath(parent_path: str, child_path: str) -> str;
def _splitRouteParts(path: str) -> list[str];
def _buildRouteName(path: str) -> str;
def _cacheNativeRoutes(route_defs: list) -> None;
def _getNativeRoutes -> list;
def _matchRoutePattern(pattern_path: str, actual_path: str) -> (dict | None);
def _lookupRouteByPath(path: str) -> (dict | None);
def _lookupRouteByName(name: str) -> (dict | None);
def _hydratePath(pattern_path: str, params: any) -> str;
def _stripMetaParams(params: any) -> dict;
def _performNavigation(nav: any, target: any, options: dict = {}) -> None;
def _collectNativeRoutes(
    children: any, parent_path: str, wrappers: list, out_routes: list
) -> None;

def _makeNativeRouteScreen(route: dict) -> any;

def:pub __nativeRouter(props: dict = {}) -> JsxElement;
def:pub __nativeRoutes(props: dict = {}) -> JsxElement;
def:pub __nativeRoute(props: dict = {}) -> JsxElement;
def:pub __nativeLink(props: dict = {}) -> JsxElement;
def:pub __nativeNavigate(props: dict = {}) -> JsxElement;
def:pub __nativeOutlet(props: dict = {}) -> JsxElement;
def:pub useRouter -> dict;
def:pub useNavigate -> any;
def:pub useLocation -> dict;
def:pub useParams -> dict;
def:pub navigate(path: str) -> None;
def:pub __getApiBaseUrl -> str;
def:pub __getLocalStorage(key: str) -> str;
def:pub __setLocalStorage(key: str, value: str) -> None;
def:pub __removeLocalStorage(key: str) -> None;
async def:pub __getLocalStorageAsync(key: str) -> str;
async def:pub __setLocalStorageAsync(key: str, value: str) -> None;
async def:pub __removeLocalStorageAsync(key: str) -> None;
async def:pub __primeNativeTokenCache -> None;
def:pub __ensureNativeTokenPrimed -> any;
def:pub AuthGuard(redirect: str = "/login") -> JsxElement;
def:pub ErrorFallback(error: str, resetErrorBoundary: any) -> JsxElement;
def:pub errorOverlay(filePath: str, errors: str) -> JsxElement;
def:pub JacForm(props: dict) -> JsxElement;
def:pub __jacInstallErrorHandlers -> None;
def:pub __jacWirePlatformAdapters -> None;
