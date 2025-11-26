cd jac/support/vscode_ext/jac
npm install
npm install -g @vscode/vsce
vsce package
code --install-extension jaclang-*.vsix # aslo works with cursor, etc
cd -
