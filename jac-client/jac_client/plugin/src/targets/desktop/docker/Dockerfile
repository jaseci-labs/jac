# Dockerfile for building production-ready Jac desktop apps
# Uses Ubuntu 22.04 for GLIBC 2.35 compatibility (works on most modern Linux distros)
#
# Usage:
#   docker build -t jac-desktop-builder .
#   docker run --rm -v "$(pwd):/project" -w /project jac-desktop-builder jac build desktop

FROM ubuntu:22.04

LABEL maintainer="Jaseci Team"
LABEL description="Build environment for production Jac desktop apps (GLIBC 2.35)"

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install system dependencies for Tauri and WebKit
RUN apt-get update && apt-get install -y \
    # Build essentials
    build-essential \
    pkg-config \
    software-properties-common \
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y \
    # Python 3.12 (jaclang requires >= 3.12)
    python3.12 \
    python3.12-venv \
    python3.12-dev \
    # Tauri/WebKit dependencies
    libwebkit2gtk-4.1-dev \
    libgtk-3-dev \
    libayatana-appindicator3-dev \
    librsvg2-dev \
    libssl-dev \
    # AppImage dependencies
    libfuse2 \
    file \
    patchelf \
    # OpenGL (fixes libGLESv2.so.2 issue)
    libgles2-mesa \
    libgles2-mesa-dev \
    libegl1-mesa-dev \
    # Additional libs that might be needed
    libxdo3 \
    libxcb1 \
    libxcb-shape0 \
    libxcb-xfixes0 \
    # Utilities
    curl \
    wget \
    git \
    unzip \
    ca-certificates \
    # Clean up
    && rm -rf /var/lib/apt/lists/*

# Set Python 3.12 as default
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 \
    && update-alternatives --set python3 /usr/bin/python3.12 \
    && python3.12 -m ensurepip --upgrade \
    && python3.12 -m pip install --upgrade pip \
    && ln -sf /usr/bin/python3.12 /usr/bin/python \
    && ln -sf /usr/local/bin/pip3.12 /usr/bin/pip3 || true

# Install Rust (required for Tauri)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Install Node.js (for Vite/frontend builds)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Bun (faster alternative to npm)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

# Install Tauri CLI
RUN cargo install tauri-cli

# Download linuxdeploy for proper AppImage creation
RUN mkdir -p /opt/linuxdeploy \
    && wget -q https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage \
       -O /opt/linuxdeploy/linuxdeploy \
    && chmod +x /opt/linuxdeploy/linuxdeploy \
    # Extract AppImage (can't run AppImage inside Docker without FUSE)
    && cd /opt/linuxdeploy \
    && ./linuxdeploy --appimage-extract \
    && mv squashfs-root linuxdeploy-extracted \
    && rm linuxdeploy
ENV PATH="/opt/linuxdeploy/linuxdeploy-extracted/usr/bin:${PATH}"

# Download linuxdeploy GTK plugin
RUN wget -q https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gtk/master/linuxdeploy-plugin-gtk.sh \
    -O /opt/linuxdeploy/linuxdeploy-extracted/usr/bin/linuxdeploy-plugin-gtk.sh \
    && chmod +x /opt/linuxdeploy/linuxdeploy-extracted/usr/bin/linuxdeploy-plugin-gtk.sh

# Download appimagetool
RUN wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage \
    -O /opt/linuxdeploy/appimagetool \
    && chmod +x /opt/linuxdeploy/appimagetool \
    && cd /opt/linuxdeploy \
    && ./appimagetool --appimage-extract \
    && mv squashfs-root appimagetool-extracted \
    && rm appimagetool \
    && ln -s /opt/linuxdeploy/appimagetool-extracted/AppRun /usr/local/bin/appimagetool

# Upgrade pip and install Python build tools
RUN pip3 install --upgrade pip setuptools wheel

# Install PyInstaller for sidecar bundling
RUN pip3 install pyinstaller

# Set environment variables for production builds
ENV JAC_SIDECAR_STANDALONE=1
ENV JAC_PRODUCTION_BUILD=1

# Create workspace directory
WORKDIR /project

# Default command shows help
CMD ["echo", "Usage: docker run -v $(pwd):/project jac-desktop-builder jac build main.jac --client desktop"]
