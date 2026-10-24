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

def:pub __jacGetRenderer -> any;
def:pub __jacNativeCreate(
    tag: any, props: dict[str, any] = {}, children: any = []
) -> JsxElement;

glob _UNMAPPED_WARNED = {},
     _RELATIVE_IMG_SRC_WARNED = {},
     _JAC_NATIVE_OUTLET_CONTEXT = React.createContext(None),
     _JAC_NATIVE_STACK = jacCreateNativeStackNavigator();

obj RouteDef {
    has name: str,
        path: str,
        element: any = None,
        wrappers: list[any] = [];
}

obj RouteMatch {
    has name: str,
        path: str,
        params: dict[str, any] = {};
}

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

def _adaptProps(tag: str, props: dict[str, any]) -> dict[str, any];
def _isAbsoluteImageUri(src: str) -> bool;
def _adaptImageProps(props: dict[str, any]) -> dict[str, any];
def _textStyleFrom(style: any) -> dict[str, any];
def _makeNativeLink(link_props: dict[str, any], children: list[any]) -> JsxElement;
def _toChildrenArray(children: any) -> list[any];
def _normalizeRoutePath(path: str) -> str;
def _joinRoutePath(parent_path: str, child_path: str) -> str;
def _splitRouteParts(path: str) -> list[str];
def _buildRouteName(path: str) -> str;
def _cacheNativeRoutes(route_defs: list[RouteDef]) -> None;
def _getNativeRoutes -> list[any];
def _matchRoutePattern(pattern_path: str, actual_path: str) -> (dict[str, any] | None);
def _lookupRouteByPath(path: str) -> (RouteMatch | None);
def _lookupRouteByName(name: str) -> (dict[str, any] | None);
def _hydratePath(pattern_path: str, params: any) -> str;
def _stripMetaParams(params: any) -> dict[str, any];
def _performNavigation(nav: any, target: any, options: dict[str, any] = {}) -> None;
def _collectNativeRoutes(
    children: any, parent_path: str, wrappers: list[any], out_routes: list[RouteDef]
) -> None;

def _makeNativeRouteScreen(route: RouteDef) -> any;

def:pub __nativeRouter(props: dict[str, any] = {}) -> JsxElement;
def:pub __nativeRoutes(props: dict[str, any] = {}) -> JsxElement;
def:pub __nativeRoute(props: dict[str, any] = {}) -> (JsxElement | None);
def:pub __nativeLink(props: dict[str, any] = {}) -> JsxElement;
def:pub __nativeNavigate(props: dict[str, any] = {}) -> (JsxElement | None);
def:pub __nativeOutlet(props: dict[str, any] = {}) -> (JsxElement | None);
def:pub useRouter -> dict[str, any];
def:pub useNavigate -> any;
def:pub useLocation -> dict[str, any];
def:pub useParams -> dict[str, any];
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

def:pub AuthGuard(
    redirect: str = "/login", children: any = None
) -> (JsxElement | None);

def:pub ErrorFallback(error: any, resetErrorBoundary: any) -> JsxElement;
def:pub errorOverlay(filePath: str, errors: str) -> JsxElement;
def _changeTextHandler(on_change: any) -> Callable[[any], None];
def _fieldSetter(form: any, field_name: str, value: any) -> Callable[[], None];
def _passwordToggle(
    field_name: str, is_visible: bool, visible: any, set_visible: any
) -> Callable[[], None];

def:pub JacForm(props: dict[str, any]) -> JsxElement;
def:pub __jacInstallErrorHandlers -> None;
def:pub __jacWirePlatformAdapters -> None;

impl _renderSelectField(
    form: any,
    field_name: str,
    selected_value: str,
    options: list[str],
    placeholder: str
) -> JsxElement {
    option_children = [];
    if placeholder and selected_value == "" {
        option_children.append(
            React.createElement(
                RNText,
                {
                    "key": "__placeholder__",
                    "style": {
                        "marginBottom": 8,
                        "color": "#6b7280",
                        "fontStyle": "italic"
                    }
                },
                placeholder
            )
        );
    }
    for opt in options {
        opt_value = str(opt);
        is_selected = selected_value == opt_value;
        option_children.append(
            React.createElement(
                RNPressable,
                {
                    "key": f"{field_name}:{opt_value}",
                    "onPress": _fieldSetter(form, field_name, opt_value),
                    "style": {
                        "borderWidth": 1,
                        "borderColor": ("#2563eb" if is_selected else "#d1d5db"),
                        "paddingVertical": 10,
                        "paddingHorizontal": 12,
                        "borderRadius": 6,
                        "marginBottom": 6,
                        "backgroundColor": ("#eff6ff" if is_selected else "#ffffff")
                    }
                },
                React.createElement(RNText, {"style": {"color": "#111827"}}, opt_value)
            )
        );
    }
    return React.createElement(RNView, {"style": {"marginTop": 2}}, *option_children);
}

impl _renderRadioField(
    form: any, field_name: str, selected_value: str, options: list[str]
) -> JsxElement {
    option_children = [];
    for opt in options {
        opt_value = str(opt);
        is_selected = selected_value == opt_value;
        option_children.append(
            React.createElement(
                RNPressable,
                {
                    "key": f"{field_name}:{opt_value}",
                    "onPress": _fieldSetter(form, field_name, opt_value),
                    "style": {
                        "flexDirection": "row",
                        "alignItems": "center",
                        "paddingVertical": 8
                    }
                },
                React.createElement(
                    RNText,
                    {
                        "style": {
                            "fontSize": 16,
                            "color": "#2563eb" if is_selected else "#9ca3af",
                            "marginRight": 8
                        }
                    },
                    "◉" if is_selected else "○"
                ),
                React.createElement(RNText, {"style": {"color": "#111827"}}, opt_value)
            )
        );
    }
    return React.createElement(RNView, {"style": {"marginTop": 2}}, *option_children);
}

impl _renderTextField(
    field: any,
    placeholder: str,
    value: str,
    on_change: any,
    secure: bool,
    has_error: bool
) -> JsxElement {
    return React.createElement(
        RNTextInput,
        {
            "placeholder": placeholder,
            "value": value,
            "onChangeText": on_change,
            "onBlur": field.onBlur,
            "secureTextEntry": secure,
            "style": {
                "borderWidth": 1,
                "borderColor": "#ef4444" if has_error else "#e5e7eb",
                "padding": 10,
                "borderRadius": 6,
                "backgroundColor": "#ffffff",
                "flex": 1
            }
        }
    );
}

impl _renderPasswordRow(
    input_row: JsxElement, is_visible: bool, on_toggle: any
) -> JsxElement {
    toggle = React.createElement(
        RNPressable,
        {
            "onPress": on_toggle,
            "style": {"marginLeft": 8, "paddingVertical": 8, "paddingHorizontal": 10}
        },
        React.createElement(
            RNText,
            {"style": {"color": "#2563eb", "fontWeight": "600"}},
            "Hide" if is_visible else "Show"
        )
    );
    return React.createElement(
        RNView,
        {"style": {"flexDirection": "row", "alignItems": "center"}},
        input_row,
        toggle
    );
}

impl _renderSubmitButton(
    is_submitting: bool, is_dirty: bool, submit_label: str, on_press: any
) -> JsxElement {
    return React.createElement(
        RNPressable,
        {
            "onPress": on_press,
            "disabled": is_submitting or not is_dirty,
            "style": {
                "backgroundColor": "#2563eb"
                    if (is_dirty and not is_submitting)
                    else "#9ca3af",
                "padding": 12,
                "borderRadius": 6,
                "marginTop": 12
            }
        },
        React.createElement(
            RNText,
            {"style": {"color": "white", "textAlign": "center", "fontWeight": "600"}},
            "Submitting..." if is_submitting else submit_label
        )
    );
}
