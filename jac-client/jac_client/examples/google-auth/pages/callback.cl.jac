
import from react { useEffect, useContext }
import from "@jac/runtime" { useNavigate, useLocation }
import from '..lib.auth-backend' { AuthContext }

def:pub OAuthCallback() -> any {
    navigate = useNavigate();
    location = useLocation();
    console.log("OAuth Callback Location:", location);
    auth = useContext(AuthContext);

    useEffect(lambda () -> None {
        # Async function to handle SSO callback
        async def handleSSOCallback() -> None {
            console.log("Handling SSO Callback...", window.location.href);
            # Check if we're at the backend callback URL with a code parameter
            if window.location.href.includes('/sso/') and window.location.href.includes('code=') {
                console.log("Detected backend SSO callback, fetching token...");
                
                try {
                    # Fetch the current URL to get the JSON response from backend
                                        # Remove hash (#) from URL to get clean backend callback URL
                    removehash = window.location.href.replace('/#/', '/');
                    
                    response = await fetch(removehash);
                    data = await response.json();
                    
                    console.log("Backend SSO Response:", data);
                    
                    if data.ok and data.data and data.data.token {
                        token = data.data.token;
                        username = data.data.username;
                        
                        console.log('✅ Login successful for:', username);
                        
                        # Store the token
                        localStorage.setItem('auth_token', token);
                        
                        # Redirect to dashboard
                        navigate('/dashboard');
                    } else {
                        console.error('❌ SSO failed:', data);
                        errorMsg = data.error or 'authentication_failed';
                        navigate('/login?error=' + encodeURIComponent(errorMsg));
                    }
                } except error {
                    console.error('Failed to fetch SSO response:', error);
                    navigate('/login?error=fetch_failed');
                }
                
                return;
            }
            
            # # Otherwise, parse query parameters for token (direct callback case)
            # searchParams = Reflect.construct(URLSearchParams,[window.location.search]);
            # console.log("OAuth Callback Params:", searchParams);
            # token = searchParams.get("token") or "";
            # errorParam = searchParams.get("error") or "";

            # if errorParam {
            #     console.error('OAuth error:', errorParam);
            #     # Redirect to login with error message
            #     navigate('/login?error=' + encodeURIComponent(errorParam));
            #     return;
            # }

            # if token {
            #     # Store the token
            #     localStorage.setItem('auth_token', token);
                
            #     # Decode token to get user info (basic info, full validation happens on backend)
            #     try {
            #         # Token is already validated by backend, just extract payload
            #         payload = JSON.parse(atob(token.split('.')[1]));
                    
            #         # Update auth context
            #         # The auth provider will validate with backend on next mount
            #         console.log('Login successful for user:', payload.username);
                    
            #         # Redirect to dashboard
            #         navigate('/dashboard');
            #     } except e {
            #         console.error('Failed to process token:', e);
            #         navigate('/login?error=invalid_token');
            #     }
            # } else {
            #     # No token, something went wrong
            #     navigate('/login?error=no_token');
            # }
        }
        ;
        
        # Call the async function
        handleSSOCallback();
    }, [ navigate]);

    return (
        <div style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            minHeight: '100vh'
        }}>
            <div style={{ textAlign: 'center' }}>
                <h2>Processing authentication...</h2>
                <p>Please wait while we complete your login.</p>
            </div>
        </div>
    );
}
