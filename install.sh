#!/bin/bash
# Gemini Orchestrator Installation Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMANDS_DIR="$HOME/.gemini/commands"
SCRIPTS_DIR="$HOME/.gemini/scripts"

echo "🚀 Installing Gemini Multi-Agent Orchestrator..."
echo ""

# Check for gemini CLI
if ! command -v gemini &> /dev/null; then
    echo "⚠️  Gemini CLI not found. Installing..."
    npm install -g @google/gemini-cli
fi

# Create installation directories
mkdir -p "$COMMANDS_DIR"
mkdir -p "$SCRIPTS_DIR"

# Copy custom commands
echo "📦 Installing custom commands..."
cp "$SCRIPT_DIR/commands/"*.toml "$COMMANDS_DIR/"
echo "   ✅ architect.toml"
echo "   ✅ developer.toml"
echo "   ✅ tester.toml"
echo "   ✅ reviewer.toml"
echo "   ✅ orchestrator.toml"

# Copy scripts
echo ""
echo "📦 Installing scripts..."
cp "$SCRIPT_DIR/scripts/gemini-orchestrate.sh" "$SCRIPTS_DIR/"
cp "$SCRIPT_DIR/scripts/gemini-migrate-tests.sh" "$SCRIPTS_DIR/"
chmod +x "$SCRIPTS_DIR/gemini-orchestrate.sh"
chmod +x "$SCRIPTS_DIR/gemini-migrate-tests.sh"
echo "   ✅ gemini-orchestrate.sh"
echo "   ✅ gemini-migrate-tests.sh"

# Check if PATH needs updating
echo ""
if [[ ":$PATH:" != *":$SCRIPTS_DIR:"* ]]; then
    echo "📝 Add the following line to your ~/.zshrc or ~/.bashrc:"
    echo ""
    echo "    export PATH=\"\$HOME/.gemini/scripts:\$PATH\""
    echo ""
    echo "Then run: source ~/.zshrc"
else
    echo "✅ PATH is already configured"
fi

echo ""
echo "🎉 Installation complete!"
echo ""
echo "Installed to:"
echo "  Commands: $COMMANDS_DIR/"
echo "  Scripts:  $SCRIPTS_DIR/"
echo ""
echo "Usage:"
echo "    gemini-orchestrate.sh \"project description\" ./output-directory"
echo ""
echo "Example:"
echo "    gemini-orchestrate.sh \"Create a REST API with Express\" ./my-api"
echo ""
echo "Or use custom commands directly in Gemini CLI:"
echo "    gemini /architect \"Design a REST API\""
echo "    gemini /developer \"Implement the API\""
echo "    gemini /tester \"Create tests\""
