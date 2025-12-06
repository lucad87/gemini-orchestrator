#!/bin/bash
# Gemini Test Migration Tool
# Migrates tests from one framework to another
#
# Usage: gemini-migrate-tests.sh [options] <source-dir> <target-dir>

set -e

VERSION="1.0.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Defaults
PRIMARY_MODEL="${GEMINI_MODEL:-gemini-2.5-flash}"
FALLBACK_MODEL="gemini-2.0-flash"
COOLDOWN_SECONDS="${GEMINI_COOLDOWN:-10}"
DRY_RUN=false
STREAM_OUTPUT=false
SOURCE_FRAMEWORK="wdio"
TARGET_FRAMEWORK="playwright"
SOURCE_LANG="javascript"
TARGET_LANG="typescript"

show_help() {
    echo "Gemini Test Migration Tool v${VERSION}"
    echo ""
    echo "Usage: gemini-migrate-tests.sh [options] <source-dir> <target-dir>"
    echo ""
    echo "Migrates tests from one framework to another (default: WDIO JS → Playwright TS)"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -v, --version           Show version number"
    echo "  -m, --model MODEL       Set the primary model (default: gemini-2.5-flash)"
    echo "  --source-framework FW   Source framework (default: wdio)"
    echo "  --target-framework FW   Target framework (default: playwright)"
    echo "  --source-lang LANG      Source language (default: javascript)"
    echo "  --target-lang LANG      Target language (default: typescript)"
    echo "  --dry-run               Show what would happen without executing"
    echo "  --stream                Enable real-time streaming output"
    echo "  --cooldown SECS         Set cooldown between phases (default: 10)"
    echo ""
    echo "Examples:"
    echo "  gemini-migrate-tests.sh ./wdio-tests ./playwright-tests"
    echo "  gemini-migrate-tests.sh --stream ./old-tests ./new-tests"
    echo "  gemini-migrate-tests.sh --source-framework cypress --target-framework playwright ./src ./dest"
}

show_version() {
    echo "gemini-migrate-tests.sh version ${VERSION}"
}

# Parse arguments
POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            show_version
            exit 0
            ;;
        -m|--model)
            PRIMARY_MODEL="$2"
            shift 2
            ;;
        --source-framework)
            SOURCE_FRAMEWORK="$2"
            shift 2
            ;;
        --target-framework)
            TARGET_FRAMEWORK="$2"
            shift 2
            ;;
        --source-lang)
            SOURCE_LANG="$2"
            shift 2
            ;;
        --target-lang)
            TARGET_LANG="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --stream)
            STREAM_OUTPUT=true
            shift
            ;;
        --cooldown)
            COOLDOWN_SECONDS="$2"
            shift 2
            ;;
        -*|--*)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

set -- "${POSITIONAL_ARGS[@]}"

SOURCE_DIR="$1"
TARGET_DIR="$2"

if [ -z "$SOURCE_DIR" ] || [ -z "$TARGET_DIR" ]; then
    show_help
    exit 1
fi

# Resolve to absolute paths
SOURCE_DIR=$(cd "$SOURCE_DIR" 2>/dev/null && pwd || echo "$SOURCE_DIR")
TARGET_DIR=$(cd "$TARGET_DIR" 2>/dev/null && pwd || echo "$TARGET_DIR")

# Function to run gemini
run_gemini() {
    local prompt="$1"
    local output_format="${2:-text}"
    
    if $STREAM_OUTPUT && [ "$output_format" = "text" ]; then
        output_format="stream-json"
    fi
    
    if $DRY_RUN; then
        echo -e "${CYAN}[DRY-RUN] Would execute: gemini --model $PRIMARY_MODEL -y -p \"...\"${NC}"
        return 0
    fi
    
    if $STREAM_OUTPUT; then
        gemini --model "$PRIMARY_MODEL" --output-format "$output_format" -y -p "$prompt" 2>&1 | while IFS= read -r line; do
            event_type=$(echo "$line" | jq -r '.type // empty' 2>/dev/null)
            case "$event_type" in
                "message")
                    content=$(echo "$line" | jq -r '.content // empty' 2>/dev/null)
                    if [ -n "$content" ]; then
                        echo -e "${NC}$content"
                    fi
                    ;;
                "tool_use")
                    tool_name=$(echo "$line" | jq -r '.tool_name // empty' 2>/dev/null)
                    echo -e "${YELLOW}🔧 Using tool: $tool_name${NC}"
                    ;;
                "tool_result")
                    status=$(echo "$line" | jq -r '.status // empty' 2>/dev/null)
                    if [ "$status" = "success" ]; then
                        echo -e "${GREEN}   ✓ Tool completed${NC}"
                    else
                        echo -e "${RED}   ✗ Tool failed${NC}"
                    fi
                    ;;
            esac
        done
        return ${PIPESTATUS[0]}
    fi
    
    if result=$(gemini --model "$PRIMARY_MODEL" --output-format "$output_format" -y -p "$prompt" 2>&1); then
        echo "$result"
        return 0
    fi
    
    if echo "$result" | grep -q "quota"; then
        echo -e "${YELLOW}⚠️  Rate limit hit, falling back to $FALLBACK_MODEL...${NC}" >&2
        sleep 5
        gemini --model "$FALLBACK_MODEL" --output-format "$output_format" -y -p "$prompt"
        return $?
    fi
    
    echo "$result" >&2
    return 1
}

# Header
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔄 GEMINI TEST MIGRATION TOOL v${VERSION}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "📂 Source: ${GREEN}$SOURCE_DIR${NC} (${SOURCE_FRAMEWORK}/${SOURCE_LANG})"
echo -e "📂 Target: ${GREEN}$TARGET_DIR${NC} (${TARGET_FRAMEWORK}/${TARGET_LANG})"
echo -e "🤖 Model: ${GREEN}$PRIMARY_MODEL${NC}"
if $DRY_RUN; then echo -e "🏃 Mode: ${CYAN}DRY-RUN${NC}"; fi
if $STREAM_OUTPUT; then echo -e "📡 Streaming: ${GREEN}ENABLED${NC}"; fi
echo ""

# Validate directories
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}❌ Source directory does not exist: $SOURCE_DIR${NC}"
    exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${RED}❌ Target directory does not exist: $TARGET_DIR${NC}"
    exit 1
fi

# Phase 1: Analyze source tests
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📊 PHASE 1: ANALYZE SOURCE TESTS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

ANALYSIS_RESULT=$(run_gemini "
You are analyzing a test project for migration.

Source Framework: ${SOURCE_FRAMEWORK} (${SOURCE_LANG})
Source Directory: ${SOURCE_DIR}

Please:
1. Read the test files in the source directory
2. List all test files found
3. For each test file, identify:
   - Test suites (describe blocks)
   - Test cases (it blocks)
   - Page objects or helpers used
   - Any setup/teardown hooks

Output a structured summary of what needs to be migrated.
Do NOT create any files yet - just analyze and report.
" "json")

echo "$ANALYSIS_RESULT" | jq -r '.response // .' 2>/dev/null || echo "$ANALYSIS_RESULT"
echo ""
echo -e "${GREEN}✅ Source analysis complete${NC}"

echo ""
echo -e "${YELLOW}⏳ Cooling down (${COOLDOWN_SECONDS}s)...${NC}"
$DRY_RUN || sleep "$COOLDOWN_SECONDS"

# Phase 2: Analyze target project
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📊 PHASE 2: ANALYZE TARGET PROJECT${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

run_gemini "
You are analyzing the target test project to understand its conventions.

Target Framework: ${TARGET_FRAMEWORK} (${TARGET_LANG})
Target Directory: ${TARGET_DIR}

Please analyze and report:
1. Read existing test files to understand the patterns
2. Identify the file structure and naming conventions
3. Find TypeScript import aliases (look in tsconfig.json for paths)
4. Identify existing page objects, fixtures, or utilities
5. Note the assertion style and common patterns used

Output a summary of the target project conventions that must be followed during migration.
Do NOT create any files yet - just analyze and report.
"

echo ""
echo -e "${GREEN}✅ Target analysis complete${NC}"

echo ""
echo -e "${YELLOW}⏳ Cooling down (${COOLDOWN_SECONDS}s)...${NC}"
$DRY_RUN || sleep "$COOLDOWN_SECONDS"

# Phase 3: Execute migration
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔄 PHASE 3: EXECUTE MIGRATION${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

run_gemini "
You are migrating tests from ${SOURCE_FRAMEWORK} (${SOURCE_LANG}) to ${TARGET_FRAMEWORK} (${TARGET_LANG}).

Source Directory: ${SOURCE_DIR}
Target Directory: ${TARGET_DIR}

Based on your previous analysis of both projects, now perform the migration:

1. For each test file in the source:
   - Create the equivalent test in the target project
   - Convert all ${SOURCE_FRAMEWORK} commands to ${TARGET_FRAMEWORK} equivalents
   - Use TypeScript types appropriately
   - Follow the target project's import alias conventions
   - Match the existing code style in the target project

2. Create or extend page objects/fixtures as needed

3. Create a MIGRATION.md file in the target directory with:
   - List of migrated files (source → target)
   - Any new page objects or utilities created
   - Notes on any manual review needed
   - Mapping of old patterns to new patterns used

IMPORTANT:
- Match the EXACT style and conventions of existing tests in the target project
- Use the target project's existing page objects when applicable
- Add proper TypeScript types
- Preserve all test logic and assertions
"

echo ""
echo -e "${GREEN}✅ Migration complete${NC}"

# Summary
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}📊 MIGRATION COMPLETE${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Source: ${BLUE}$SOURCE_DIR${NC}"
echo -e "Target: ${BLUE}$TARGET_DIR${NC}"
echo ""
echo "New/Modified files in target:"
find "$TARGET_DIR" -type f -name "*.ts" -newer "$0" 2>/dev/null | head -20 || echo "(check target directory)"
echo ""
echo -e "${YELLOW}📋 Review MIGRATION.md in the target directory for details${NC}"
echo ""
echo -e "${GREEN}🎉 Done!${NC}"
