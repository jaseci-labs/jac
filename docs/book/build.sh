#!/bin/bash

# Build script for generating book.pdf from LaTeX sources
# This script compiles the Jaseci book.tex file into a PDF

echo "📚 Building Jaseci book from LaTeX sources (PDF + HTML)..."

# Check if we're in the right directory
if [ ! -f "book.tex" ]; then
    echo "❌ Error: book.tex not found in current directory"
    echo "Please run this script from the docs/book directory"
    exit 1
fi

# Check if LaTeX is available
if ! command -v pdflatex >/dev/null 2>&1; then
    echo "❌ Error: pdflatex not found"
    echo "Please run setup.sh first to install LaTeX dependencies"
    exit 1
fi

# HTML toolchain availability (optional)
MAKE4HT_AVAILABLE=false
if command -v make4ht >/dev/null 2>&1; then
    MAKE4HT_AVAILABLE=true
fi

# Clean up any previous build artifacts
echo "🧹 Cleaning up previous build artifacts..."
rm -f book.aux book.log book.out book.toc book.lof book.lot book.bbl book.blg book.fdb_latexmk book.fls book.run.xml
rm -rf html

# First pass - generate auxiliary files
echo "🔄 First pass: Generating auxiliary files..."
pdflatex -interaction=nonstopmode book.tex > /dev/null 2>&1 || {
    echo "⚠️  First pass had warnings (this is normal for TOC generation)"
}

# Generate bibliography if it exists
if [ -f "book.bib" ]; then
    echo "📖 Generating bibliography..."
    bibtex book > /dev/null 2>&1 || {
        echo "⚠️  Bibliography generation had warnings"
    }
fi

# Second pass - resolve references and generate TOC
echo "🔄 Second pass: Resolving references and generating TOC..."
pdflatex -interaction=nonstopmode book.tex > /dev/null 2>&1 || {
    echo "⚠️  Second pass had warnings"
}

# Third pass - final compilation to ensure everything is resolved
echo "🔄 Third pass: Final compilation..."
pdflatex -interaction=nonstopmode book.tex > /dev/null 2>&1 || {
    echo "⚠️  Third pass had warnings"
}

# Check if PDF was generated successfully
if [ -f "book.pdf" ]; then
    echo "✅ Successfully generated book.pdf"

    # Get file size
    FILE_SIZE=$(du -h book.pdf | cut -f1)
    echo "📄 File size: $FILE_SIZE"

    # Show PDF info
    if command -v pdfinfo >/dev/null 2>&1; then
        echo "📋 PDF information:"
        pdfinfo book.pdf | grep -E "(Pages|Title|Author|Creator)" | sed 's/^/  /'
    fi

    echo ""
    echo "🎉 Book compilation complete! You can find book.pdf in the current directory."
else
    echo "❌ Error: book.pdf was not generated"
    echo "Check the log files for compilation errors"
    exit 1
fi

# ----------------------------------------------------------------------------
# Build HTML using make4ht if available
# ----------------------------------------------------------------------------
HTML_DIR="../book_html"
if [ "$MAKE4HT_AVAILABLE" = true ]; then
    echo "🌐 Generating HTML with make4ht (SVG for TikZ, Pygments for code)..."
    mkdir -p "$HTML_DIR"

    # Use make4ht with common options:
    # -u: use UTF-8
    # -c config: optional config file (not used here)
    # -d output dir
    # xhtml: output format
    # Options: mathjax, dvisvgm for pictures
    make4ht -u -d "$HTML_DIR" -f html5+mathjax+svg -a debug "book.tex" "svg"

    if [ -f "$HTML_DIR/book.html" ] || ls "$HTML_DIR"/*.html >/dev/null 2>&1; then
        echo "✅ Successfully generated HTML in $HTML_DIR/"
    else
        echo "⚠️  HTML build did not produce an index. Check logs in $HTML_DIR/"
    fi
else
    echo "ℹ️  make4ht not found. Skipping HTML build. Run setup.sh to install HTML toolchain."
fi

# Optional: Clean up auxiliary files
if [ "$1" = "--clean" ]; then
    echo "🧹 Cleaning up auxiliary files..."
    rm -f book.aux book.log book.out book.toc book.lof book.lot book.bbl book.blg book.fdb_latexmk book.fls book.run.xml
    # Remove HTML artifacts as well
    rm -rf "$HTML_DIR"
    echo "✅ Cleanup complete"
fi

echo ""
echo "💡 Tips:"
echo "  - Run with --clean to remove auxiliary files after building"
echo "  - If you encounter errors, check book.log for details"
echo "  - For a clean build, run: ./build.sh --clean"
echo "  - HTML output (if make4ht is installed) is in the html/ directory"
