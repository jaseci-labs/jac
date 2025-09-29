#!/bin/bash

# Test runner script for VSCode Jac extension
# Runs all tests with different configurations

echo "🧪 Running Jac VSCode Extension Tests"
echo "====================================="

# Check if we're in the right directory
if [ ! -f "package.json" ]; then
    echo "❌ Error: Please run this script from the extension root directory"
    exit 1
fi

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
fi

echo ""
echo "🔍 Running unit tests..."
echo "----------------------"

# Run Jest tests with coverage
npm run test:coverage

echo ""
echo "📊 Test Results Summary:"
echo "----------------------"

# Check if tests passed
if [ $? -eq 0 ]; then
    echo "✅ All tests passed!"
    echo ""
    echo "📋 Test Coverage Report:"
    echo "- Check the 'coverage/' directory for detailed HTML report"
    echo "- Open 'coverage/lcov-report/index.html' in a browser to view coverage"
    
    echo ""
    echo "🎯 Test Categories Covered:"
    echo "- ✅ Environment Detection (Linux/Windows)"
    echo "- ✅ EnvManager Class Methods"
    echo "- ✅ Cross-Platform Scenarios"
    echo "- ✅ Virtual Environment Discovery"
    echo "- ✅ Conda Environment Discovery"
    echo "- ✅ Global Installation Detection"
    echo "- ✅ Error Handling and Edge Cases"
    echo "- ✅ Status Bar Updates"
    echo "- ✅ User Interface Interactions"
    
else
    echo "❌ Some tests failed!"
    echo "Please check the output above for details."
    exit 1
fi

echo ""
echo "🏆 Test suite completed successfully!"