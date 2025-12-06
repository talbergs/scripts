#!/bin/bash

# Script to ensure Docker CLI is available on macOS (Apple Silicon)

echo "🔍 Checking Docker setup on macOS..."

# Check if Docker Desktop is installed
if [ -d "/Applications/Docker.app" ]; then
    echo "✓ Docker Desktop is installed"

    # Check if Docker CLI is in PATH
    if command -v docker &> /dev/null; then
        echo "✓ Docker CLI is already in PATH"
        docker --version
    else
        echo "⚠ Docker CLI not in PATH. Adding it now..."

        # Add Docker CLI to PATH for this session
        export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"

        # Check which shell is being used and update the appropriate config file
        if [ -n "$ZSH_VERSION" ]; then
            SHELL_CONFIG="$HOME/.zshrc"
        elif [ -n "$BASH_VERSION" ]; then
            SHELL_CONFIG="$HOME/.bash_profile"
        else
            SHELL_CONFIG="$HOME/.profile"
        fi

        # Add to shell config if not already there
        if ! grep -q "/Applications/Docker.app/Contents/Resources/bin" "$SHELL_CONFIG" 2>/dev/null; then
            echo "" >> "$SHELL_CONFIG"
            echo "# Docker Desktop CLI" >> "$SHELL_CONFIG"
            echo 'export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"' >> "$SHELL_CONFIG"
            echo "✓ Added Docker CLI to $SHELL_CONFIG"
            echo "  Run: source $SHELL_CONFIG (or restart your terminal)"
        fi
    fi

    # Check if Docker daemon is running
    if docker ps &> /dev/null; then
        echo "✓ Docker daemon is running"
        echo ""
        echo "🎉 Docker is ready! You can now run: docker ps"
    else
        echo "⚠ Docker daemon is not running"
        echo "  Starting Docker Desktop..."
        open -a Docker
        echo "  Waiting for Docker to start (this may take 30-60 seconds)..."

        # Wait for Docker to be ready
        COUNT=0
        while ! docker ps &> /dev/null && [ $COUNT -lt 60 ]; do
            sleep 2
            COUNT=$((COUNT + 2))
            echo -n "."
        done
        echo ""

        if docker ps &> /dev/null; then
            echo "✓ Docker is now running!"
            echo ""
            echo "🎉 Docker is ready! You can now run: docker ps"
        else
            echo "❌ Docker failed to start. Please open Docker Desktop manually."
        fi
    fi
else
    echo "❌ Docker Desktop is not installed"
    echo ""
    echo "To install Docker Desktop for Apple Silicon (M3):"
    echo "1. Download from: https://desktop.docker.com/mac/main/arm64/Docker.dmg"
    echo "2. Open the .dmg file and drag Docker to Applications"
    echo "3. Run Docker Desktop from Applications"
    echo "4. Run this script again"
    echo ""
    echo "Or install via Homebrew:"
    echo "  brew install --cask docker"
fi
