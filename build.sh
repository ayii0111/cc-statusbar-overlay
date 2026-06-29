#!/bin/bash
set -e
cd "$(dirname "$0")"
swiftc overlay.swift -framework Cocoa -o cc-statusbar-overlay
echo "✓ Built: $(pwd)/cc-statusbar-overlay"
