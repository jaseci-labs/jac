import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, Platform, ActivityIndicator } from 'react-native';
import { WebView } from 'react-native-webview';

// Dev mode: load from Vite dev server for HMR
// Production: load from bundled HTML
const USE_DEV_SERVER = __DEV__ && false; // Set to true for dev server mode

let JAC_BUNDLE_HTML: string | null = null;
if (!USE_DEV_SERVER) {
  try {
    const bundle = require('../assets/jac-app/bundle');
    JAC_BUNDLE_HTML = bundle.JAC_BUNDLE_HTML;
  } catch (e) {
    console.warn('Bundle not found, will use dev server');
  }
}

// Load dev server configuration
let DEV_CONFIG = { localIP: '127.0.0.1' };
try {
  const config = require('../dev-config.json');
  DEV_CONFIG = config;
} catch (e) {
  console.warn('Dev config not found, using defaults');
}

// Configuration for URLs
const getDevServerUrl = () => {
  const localIP = DEV_CONFIG.localIP || '127.0.0.1';
  return `http://${localIP}:5173`;
};

const getBackendApiUrl = () => {
  if (__DEV__) {
    if (Platform.OS === 'android') {
      return 'http://10.0.2.2:9000';
    }
    // Use local network IP for iOS
    const localIP = DEV_CONFIG.localIP || '127.0.0.1';
    return `http://${localIP}:9000`;
  }
  return 'https://your-production-url.com';
};

export default function JacWebViewScreen() {
  const [isLoading, setIsLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [htmlContent, setHtmlContent] = useState<string>('');
  const [devServerUrl, setDevServerUrl] = useState<string>('');
  const backendApiUrl = getBackendApiUrl();

  useEffect(() => {
    if (USE_DEV_SERVER || !JAC_BUNDLE_HTML) {
      // Dev mode: use Vite dev server
      setDevServerUrl(getDevServerUrl());
      setIsLoading(false);
    } else {
      // Production mode: use bundled HTML
      prepareBundle();
    }
  }, []);

  const prepareBundle = () => {
    try {
      if (!JAC_BUNDLE_HTML) {
        throw new Error('Bundle not available');
      }
      // Inject the backend API URL into the bundle
      const html = JAC_BUNDLE_HTML.replace(
        `window.JAC_BACKEND_URL = window.JAC_BACKEND_URL || 'http://localhost:9000';`,
        `window.JAC_BACKEND_URL = '${backendApiUrl}';`
      );

      setHtmlContent(html);
    } catch (error) {
      setLoadError('Failed to load app bundle');
      setIsLoading(false);
    }
  };

  const handleError = (syntheticEvent: any) => {
    const { nativeEvent } = syntheticEvent;
    setLoadError(nativeEvent.description || 'Failed to load app');
    setIsLoading(false);
  };

  const handleLoadEnd = () => {
    setIsLoading(false);
    setLoadError(null);
  };

  const handleMessage = (event: any) => {
    try {
      const message = JSON.parse(event.nativeEvent.data);

      if (message.type === 'error') {
        console.error('[WebView Error]', ...message.data);
      }
    } catch {
      // Ignore non-JSON messages
    }
  };

  const renderWebView = () => {
    if (devServerUrl) {
      // Dev mode: load from Vite dev server
      return (
        <WebView
          source={{ uri: devServerUrl }}
          style={styles.webview}
          javaScriptEnabled={true}
          domStorageEnabled={true}
          mixedContentMode="always"
          onLoadEnd={handleLoadEnd}
          onError={handleError}
          onMessage={handleMessage}
          startInLoadingState={true}
          cacheEnabled={false}
          originWhitelist={['*']}
          injectedJavaScript={`
            (function() {
              const originalError = console.error;
              console.error = function(...args) {
                window.ReactNativeWebView?.postMessage(JSON.stringify({type: 'error', data: args}));
                originalError.apply(console, args);
              };
              window.addEventListener('error', function(e) {
                console.error('Error:', e.message);
              });
              window.addEventListener('unhandledrejection', function(e) {
                console.error('Unhandled rejection:', e.reason);
              });
            })();
            true;
          `}
        />
      );
    } else if (htmlContent) {
      // Production mode: load from bundled HTML
      return (
        <WebView
          source={{
            html: htmlContent,
            baseUrl: 'http://localhost/'
          }}
          style={styles.webview}
          javaScriptEnabled={true}
          domStorageEnabled={true}
          mixedContentMode="always"
          onLoadEnd={handleLoadEnd}
          onError={handleError}
          onMessage={handleMessage}
          allowFileAccess={true}
          allowFileAccessFromFileURLs={true}
          allowUniversalAccessFromFileURLs={true}
          startInLoadingState={true}
          cacheEnabled={false}
          originWhitelist={['*']}
          injectedJavaScript={`
            (function() {
              const originalError = console.error;
              console.error = function(...args) {
                window.ReactNativeWebView?.postMessage(JSON.stringify({type: 'error', data: args}));
                originalError.apply(console, args);
              };
              window.addEventListener('error', function(e) {
                console.error('Error:', e.message);
              });
              window.addEventListener('unhandledrejection', function(e) {
                console.error('Unhandled rejection:', e.reason);
              });
            })();
            true;
          `}
        />
      );
    }
    return null;
  };

  return (
    <View style={styles.container}>
      {isLoading && (
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color="#0066cc" />
          <Text style={styles.loadingText}>Loading Jac App...</Text>
          <Text style={styles.urlText}>
            {devServerUrl ? `From dev server: ${devServerUrl}` : 'From local bundle'}
          </Text>
        </View>
      )}

      {loadError && (
        <View style={styles.errorContainer}>
          <Text style={styles.errorTitle}>⚠️ Error</Text>
          <Text style={styles.errorMessage}>{loadError}</Text>
          <Text style={styles.errorHelp}>
            Failed to load the Jac app.{'\n'}
            {devServerUrl
              ? `Make sure dev server is running at ${devServerUrl}`
              : 'Make sure the app was built correctly.'}
          </Text>
        </View>
      )}

      {renderWebView()}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#ffffff',
  },
  webview: {
    flex: 1,
  },
  loadingContainer: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#ffffff',
    zIndex: 10,
  },
  loadingText: {
    marginTop: 16,
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
  },
  urlText: {
    marginTop: 8,
    fontSize: 12,
    color: '#666',
  },
  errorContainer: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#fff3cd',
    padding: 20,
    zIndex: 10,
  },
  errorTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#856404',
    marginBottom: 12,
  },
  errorMessage: {
    fontSize: 16,
    color: '#856404',
    marginBottom: 16,
    textAlign: 'center',
  },
  errorHelp: {
    fontSize: 12,
    color: '#666',
    textAlign: 'center',
    fontFamily: Platform.OS === 'ios' ? 'Courier' : 'monospace',
    backgroundColor: '#f8f9fa',
    padding: 12,
    borderRadius: 8,
  },
});
