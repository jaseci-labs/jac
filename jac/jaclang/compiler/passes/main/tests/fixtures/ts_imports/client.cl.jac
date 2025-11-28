"""Client-side module that imports from TypeScript."""

cl import from ".utils.ts" { Calculator, greet }
cl import from ".component.js" { Component }

node ClientButton {
    has label: str;
    has onClick: str;
}

def clientSideGreeting(name: str) {
    return greet(name);
}
