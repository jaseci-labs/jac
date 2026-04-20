const fs = require('fs');
const path = require('path');

// Read the built files
const cssPath = path.join(__dirname, 'styles.css');
const jsPath = path.join(__dirname, 'client.js');
const htmlPath = path.join(__dirname, 'index.html');

if (!fs.existsSync(cssPath) || !fs.existsSync(jsPath) || !fs.existsSync(htmlPath)) {
    console.error('❌ Missing required files. Please build the web app first.');
    process.exit(1);
}

const css = fs.readFileSync(cssPath, 'utf8');
const js = fs.readFileSync(jsPath, 'utf8');
const sourceHtml = fs.readFileSync(htmlPath, 'utf8');

// Extract __jac_init__ config from original HTML
const jacInitMatch = sourceHtml.match(/<script id="__jac_init__" type="application\/json">(.*?)<\/script>/);
const jacInitConfig = jacInitMatch ? jacInitMatch[1].replace(/&quot;/g, '"') : '{"module": "main", "function": "app", "args": {}, "argOrder": [], "globals": {}}';

// Create a complete standalone HTML
const html = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width,initial-scale=1.0,maximum-scale=1.0,user-scalable=no" />
    <title>Jac Mobile App</title>
    <style>${css}</style>
</head>
<body>
    <div id="root"></div>

    <!-- Jac initialization config -->
    <script id="__jac_init__" type="application/json">
    ${jacInitConfig}
    </script>

    <!-- Backend API URL - will be injected by mobile app -->
    <script>
        window.JAC_BACKEND_URL = window.JAC_BACKEND_URL || 'http://localhost:9000';
    </script>

    <!-- Jac client bundle as blob URL -->
    <script>
    (function() {
        const jsCode = atob('${Buffer.from(js).toString('base64')}');
        const blob = new Blob([jsCode], { type: 'text/javascript' });
        const url = URL.createObjectURL(blob);
        const script = document.createElement('script');
        script.type = 'module';
        script.src = url;
        script.onload = function() {
            URL.revokeObjectURL(url);
        };
        script.onerror = function(e) {
            console.error('Failed to load Jac bundle');
        };
        document.body.appendChild(script);
    })();
    </script>
</body>
</html>`;

// Write standalone HTML file
fs.writeFileSync(path.join(__dirname, 'bundle.html'), html);
console.log('✓ Created bundle.html');

// Also create TypeScript export
const tsContent = `// Auto-generated standalone Jac app bundle
export const JAC_BUNDLE_HTML = \`${html.replace(/`/g, '\\`').replace(/\$/g, '\\$')}\`;
`;

fs.writeFileSync(path.join(__dirname, 'bundle.ts'), tsContent);
console.log('✓ Created bundle.ts');
console.log(`Bundle size: ${(html.length / 1024).toFixed(2)} KB`);
