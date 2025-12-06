#!/bin/bash
# Gemini Orchestrator Uninstall Script

set -e

COMMANDS_DIR="$HOME/.gemini/commands"
SCRIPTS_DIR="$HOME/.gemini/scripts"

echo "🗑️  Uninstalling Gemini Multi-Agent Orchestrator..."
echo ""

# Remove custom commands
echo "Removing custom commands..."
rm -f "$COMMANDS_DIR/architect.toml" 2>/dev/null && echo "   ✅ Removed architect.toml" || echo "   ⚠️  architect.toml not found"
rm -f "$COMMANDS_DIR/developer.toml" 2>/dev/null && echo "   ✅ Removed developer.toml" || echo "   ⚠️  developer.toml not found"
rm -f "$COMMANDS_DIR/tester.toml" 2>/dev/null && echo "   ✅ Removed tester.toml" || echo "   ⚠️  tester.toml not found"
rm -f "$COMMANDS_DIR/reviewer.toml" 2>/dev/null && echo "   ✅ Removed reviewer.toml" || echo "   ⚠️  reviewer.toml not found"
rm -f "$COMMANDS_DIR/orchestrator.toml" 2>/dev/null && echo "   ✅ Removed orchestrator.toml" || echo "   ⚠️  orchestrator.toml not found"
rm -f "$COMMANDS_DIR/migrate-tests.toml" 2>/dev/null && echo "   ✅ Removed migrate-tests.toml" || echo "   ⚠️  migrate-tests.toml not found"

# Remove scripts
echo ""
echo "Removing scripts..."
rm -f "$SCRIPTS_DIR/gemini-orchestrate.sh" 2>/dev/null && echo "   ✅ Removed gemini-orchestrate.sh" || echo "   ⚠️  gemini-orchestrate.sh not found"
rm -f "$SCRIPTS_DIR/gemini-migrate-tests.sh" 2>/dev/null && echo "   ✅ Removed gemini-migrate-tests.sh" || echo "   ⚠️  gemini-migrate-tests.sh not found"

echo ""
echo "🎉 Uninstall complete!"
echo ""
echo "Note: You may want to remove this line from your ~/.zshrc or ~/.bashrc:"
echo "    export PATH=\"\$HOME/.gemini/scripts:\$PATH\""
