import from "vscode" { window }

def:pub activate(context: any) {
    window.showInformationMessage("hi");
}

def:pub deactivate {
    print("cleanup");
}
