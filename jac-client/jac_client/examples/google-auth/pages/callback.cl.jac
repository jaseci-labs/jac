import from react { useEffect, useContext }
import from "@jac/runtime" { useNavigate, useLocation }
import from '..lib.auth' { AuthContext }

def:pub OAuthCallback -> JsxElement {
    navigate = useNavigate();
    location = useLocation();
    console.log("OAuth Callback Location:", location);
    auth = useContext(AuthContext);

    useEffect(
        lambda() -> None {
        # Async function to handle SSO callback
        async def handleSSOCallback -> None {
            console.log("Handling SSO Callback...", window.location.href);

            # Parse query parameters for token (backend redirects here after OAuth)
            searchParams = Reflect.construct(URLSearchParams, [window.location.search]);
            console.log("OAuth Callback Params:", searchParams);
            token = searchParams.get("token") or "";
            errorParam = searchParams.get("error") or "";

            if errorParam {
                console.error('OAuth error:', errorParam);
                # Redirect to login with error message
                navigate('/login?error=' + encodeURIComponent(errorParam));
                return;
            }

            if token {
                # Store the token
                localStorage.setItem('auth_token', token);
                # Decode token to get user info for logging
                try {
                    payload = JSON.parse(atob(token.split('.')[1]));
                    console.log('✅ Login successful for user:', payload.username);
                } except e {
                    console.error('Failed to decode token:', e);
                }
                # Full page reload to /dashboard so AuthProvider validates token before Protected route checks
                # This ensures user state is loaded before the Protected component renders
                window.location.href = '/dashboard';
            } else {
                # No token, something went wrong
                navigate('/login?error=no_token');
            }
        } ;
        # Call the async function
        handleSSOCallback();},
        [navigate]
    );

    return (
        <div
            style={{
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                minHeight: '100vh'
            }}
        >
            <div style={{textAlign: 'center'}}>
                <h2>
                    Processing authentication...
                </h2>
                <p>
                    Please wait while we complete your login.
                </p>
            </div>
        </div>
    );
}
