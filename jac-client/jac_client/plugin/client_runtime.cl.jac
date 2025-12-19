"""Client-side runtime for Jac JSX and walker interactions."""

import from 'react' { * as React }
import from 'react-dom/client' { * as ReactDOM }
import from 'react-router-dom' {
    HashRouter as ReactRouterHashRouter,
    Routes as ReactRouterRoutes,
    Route as ReactRouterRoute,
    Link as ReactRouterLink,
    Navigate as ReactRouterNavigate,
    useNavigate as reactRouterUseNavigate,
    useLocation as reactRouterUseLocation,
    useParams as reactRouterUseParams
}

def __jacJsx(tag: any, props: dict = {}, children: any = []) -> any;

glob Router = ReactRouterHashRouter,
     Routes = ReactRouterRoutes,
     Route = ReactRouterRoute,
     Link = ReactRouterLink,
     Navigate = ReactRouterNavigate,
     useNavigate = reactRouterUseNavigate,
     useLocation = reactRouterUseLocation,
     useParams = reactRouterUseParams;

def useRouter -> dict;
def navigate(path: str) -> None;
async def __jacSpawn(left: str, right: str = "", fields: dict = {}) -> any;
def jacSpawn(left: str, right: str = "", fields: dict = {}) -> any;
async def __jacCallFunction(function_name: str, args: dict = {}) -> any;
async def jacSignup(email: str, password: str) -> dict;
async def jacLogin(email: str, password: str) -> bool;
def jacLogout -> None;
def jacIsLoggedIn -> bool;
def __getLocalStorage(key: str) -> str;
def __setLocalStorage(key: str, value: str) -> None;
def __removeLocalStorage(key: str) -> None;
