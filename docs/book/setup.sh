#!/bin/bash

# Setup script for compiling Jaseci book.tex
# This script installs all necessary LaTeX packages and dependencies

echo "🚀 Setting up LaTeX environment for Jaseci book compilation..."

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect package manager
detect_package_manager() {
    if command_exists apt-get; then
        echo "apt"
    elif command_exists dnf; then
        echo "dnf"
    elif command_exists yum; then
        echo "yum"
    elif command_exists pacman; then
        echo "pacman"
    elif command_exists zypper; then
        echo "zypper"
    else
        echo "unknown"
    fi
}

# Function to install packages based on package manager
install_packages() {
    local pkg_mgr="$1"
    local packages="$2"

    case "$pkg_mgr" in
        "apt")
            sudo apt-get update
            sudo apt-get install -y $packages
            ;;
        "dnf")
            sudo dnf install -y $packages
            ;;
        "yum")
            sudo yum install -y $packages
            ;;
        "pacman")
            sudo pacman -S --noconfirm $packages
            ;;
        "zypper")
            sudo zypper install -y $packages
            ;;
        *)
            echo "❌ Unsupported package manager: $pkg_mgr"
            exit 1
            ;;
    esac
}

# Detect package manager
PKG_MGR=$(detect_package_manager)
echo "📦 Detected package manager: $PKG_MGR"

if [ "$PKG_MGR" = "unknown" ]; then
    echo "❌ Could not detect package manager. Please install LaTeX manually."
    exit 1
fi

# Install basic LaTeX distribution and essential packages
echo "📚 Installing basic LaTeX distribution..."
case "$PKG_MGR" in
    "apt")
        install_packages "$PKG_MGR" "texlive-full texlive-latex-extra texlive-fonts-recommended texlive-fonts-extra texlive-latex-recommended texlive-science texlive-publishers texlive-lang-english"
        ;;
    "dnf"|"yum")
        install_packages "$PKG_MGR" "texlive-scheme-full"
        ;;
    "pacman")
        install_packages "$PKG_MGR" "texlive-most"
        ;;
    "zypper")
        install_packages "$PKG_MGR" "texlive"
        ;;
esac

# Install additional LaTeX packages that are used in the book
echo "🔧 Installing additional LaTeX packages..."
case "$PKG_MGR" in
    "apt")
        install_packages "$PKG_MGR" "texlive-latex-extra texlive-science texlive-publishers texlive-fonts-extra"
        ;;
    "dnf"|"yum")
        # texlive-scheme-full should include most packages
        echo "ℹ️  Most packages should be included with texlive-scheme-full"
        ;;
    "pacman")
        # texlive-most should include most packages
        echo "ℹ️  Most packages should be included with texlive-most"
        ;;
    "zypper")
        # texlive should include most packages
        echo "ℹ️  Most packages should be included with texlive"
        ;;
esac

# Install specific packages that might be missing
echo "📦 Installing specific LaTeX packages..."
case "$PKG_MGR" in
    "apt")
        install_packages "$PKG_MGR" "texlive-latex-extra texlive-science texlive-publishers"
        ;;
esac

# Install Python for potential Python code listings
echo "🐍 Installing Python (for code listings)..."
case "$PKG_MGR" in
    "apt")
        install_packages "$PKG_MGR" "python3 python3-pip"
        ;;
    "dnf"|"yum")
        install_packages "$PKG_MGR" "python3 python3-pip"
        ;;
    "pacman")
        install_packages "$PKG_MGR" "python python-pip"
        ;;
    "zypper")
        install_packages "$PKG_MGR" "python3 python3-pip"
        ;;
esac

# Install additional tools that might be needed
echo "🛠️  Installing additional tools..."
case "$PKG_MGR" in
    "apt")
        install_packages "$PKG_MGR" "build-essential make git"
        ;;
    "dnf"|"yum")
        install_packages "$PKG_MGR" "gcc make git"
        ;;
    "pacman")
        install_packages "$PKG_MGR" "base-devel git"
        ;;
    "zypper")
        install_packages "$PKG_MGR" "gcc make git"
        ;;
esac

# Check if LaTeX is working
echo "🔍 Testing LaTeX installation..."
if command_exists pdflatex; then
    echo "✅ pdflatex is available"
    pdflatex --version | head -1
else
    echo "❌ pdflatex not found. LaTeX installation may have failed."
    exit 1
fi

if command_exists xelatex; then
    echo "✅ xelatex is available"
    xelatex --version | head -1
else
    echo "⚠️  xelatex not found. Some features may not work."
fi

if command_exists lualatex; then
    echo "✅ lualatex is available"
    lualatex --version | head -1
else
    echo "⚠️  lualatex not found. Some features may not work."
fi

# Check for required LaTeX packages
echo "🔍 Checking for required LaTeX packages..."

# Create a minimal test file to check package availability
cat > test_packages.tex << 'EOF'
\documentclass{article}
\usepackage{minitoc}
\usepackage{xcolor}
\usepackage{graphicx}
\usepackage{longtable}
\usepackage{booktabs}
\usepackage{enumitem}
\usepackage{glossaries}
\usepackage{hyperref}
\usepackage{geometry}
\usepackage{tocloft}
\usepackage{pagecolor}
\usepackage{setspace}
\usepackage{ulem}
\usepackage{listings}
\usepackage{tcolorbox}
\usepackage{wrapfig}
\usepackage{python}
\usepackage{lmodern}
\usepackage{amssymb}
\usepackage{amsmath}
\usepackage{fontspec}
\usepackage{microtype}
\usepackage{url}
\usepackage{fancyvrb}
\usepackage{parskip}
\begin{document}
Test document
\end{document}
EOF

echo "🧪 Testing package compilation..."
if pdflatex -interaction=nonstopmode test_packages.tex > /dev/null 2>&1; then
    echo "✅ Basic package compilation successful"
else
    echo "⚠️  Some packages may have issues. Check the log file for details."
fi

# Clean up test files
rm -f test_packages.tex test_packages.aux test_packages.log test_packages.out test_packages.pdf

echo ""
echo "🎉 Setup complete! You should now be able to compile the book.tex file."
echo ""
echo "To compile the book, run:"
echo "  cd docs/book"
echo "  pdflatex book.tex"
echo "  pdflatex book.tex  # Run twice for proper TOC"
echo ""
echo "Note: You may need to run pdflatex multiple times to resolve references."
echo "If you encounter any missing package errors, you can install them manually:"
echo "  sudo apt-get install texlive-latex-extra  # For Ubuntu/Debian"
echo "  sudo dnf install texlive-latex-extra      # For Fedora/RHEL"
