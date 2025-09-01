#!/bin/bash

# Build script for generating book.pdf from LaTeX sources
# This script compiles the Jaseci book.tex file into a PDF

echo "📚 Building Jaseci book from LaTeX sources..."

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

# Clean up any previous build artifacts
echo "🧹 Cleaning up previous build artifacts..."
rm -f book.aux book.log book.out book.toc book.lof book.lot book.bbl book.blg book.fdb_latexmk book.fls book.run.xml

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

# Optional: Clean up auxiliary files
if [ "$1" = "--clean" ]; then
    echo "🧹 Cleaning up auxiliary files..."
    rm -f book.aux book.log book.out book.toc book.lof book.lot book.bbl book.blg book.fdb_latexmk book.fls book.run.xml
    echo "✅ Cleanup complete"
fi

echo ""
echo "💡 Tips:"
echo "  - Run with --clean to remove auxiliary files after building"
echo "  - If you encounter errors, check book.log for details"
echo "  - For a clean build, run: ./build.sh --clean"
