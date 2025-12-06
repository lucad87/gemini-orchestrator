#!/bin/bash
# Gemini Multi-Agent Orchestrator
# Coordinates multiple AI agents to build complete software projects
#
# Usage: gemini-orchestrate.sh [options] "project description" [output-directory]

set -e

VERSION="1.0.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default configuration
PRIMARY_MODEL="${GEMINI_MODEL:-gemini-2.5-flash}"
FALLBACK_MODEL="gemini-2.0-flash"
COOLDOWN_SECONDS="${GEMINI_COOLDOWN:-10}"
SKIP_TESTS=false
SKIP_REVIEW=false
DRY_RUN=false
STREAM_OUTPUT=false

# Parse command line options
show_help() {
    echo "Gemini Multi-Agent Orchestrator v${VERSION}"
    echo ""
    echo "Usage: gemini-orchestrate.sh [options] \"project description\" [output-directory]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -v, --version       Show version number"
    echo "  -m, --model MODEL   Set the primary model (default: gemini-2.5-flash)"
    echo "  --skip-tests        Skip the tester agent phase"
    echo "  --skip-review       Skip the reviewer agent phase"
    echo "  --dry-run           Show what would happen without executing"
    echo "  --stream            Enable real-time streaming output from agents"
    echo "  --cooldown SECS     Set cooldown between phases (default: 10)"
    echo ""
    echo "Environment Variables:"
    echo "  GEMINI_MODEL        Primary model to use"
    echo "  GEMINI_API_KEY      API key for higher rate limits"
    echo "  GEMINI_COOLDOWN     Seconds between phases"
    echo ""
    echo "Examples:"
    echo "  gemini-orchestrate.sh \"Create a REST API with Express\" ./my-api"
    echo "  gemini-orchestrate.sh --skip-tests \"Build a CLI tool\" ./cli-project"
    echo "  gemini-orchestrate.sh --model gemini-2.5-pro \"Complex app\" ./app"
    echo "  gemini-orchestrate.sh --dry-run \"Test project\" ./test"
}

show_version() {
    echo "gemini-orchestrate.sh version ${VERSION}"
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
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --skip-review)
            SKIP_REVIEW=true
            shift
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

# Restore positional arguments
set -- "${POSITIONAL_ARGS[@]}"

PROMPT="$1"
OUTPUT_DIR="${2:-./generated-project}"

# Show usage if no prompt provided
if [ -z "$PROMPT" ]; then
    show_help
    exit 1
fi

# Function to run gemini with fallback on rate limit
run_gemini() {
    local prompt="$1"
    local output_format="${2:-text}"
    
    # Override output format if streaming is enabled
    if $STREAM_OUTPUT && [ "$output_format" = "text" ]; then
        output_format="stream-json"
    fi
    
    if $DRY_RUN; then
        echo -e "${CYAN}[DRY-RUN] Would execute: gemini --model $PRIMARY_MODEL --output-format $output_format -y -p \"...\"${NC}"
        return 0
    fi
    
    if $STREAM_OUTPUT; then
        # Stream output directly to terminal for real-time feedback
        gemini --model "$PRIMARY_MODEL" --output-format "$output_format" -y -p "$prompt" 2>&1 | while IFS= read -r line; do
            # Parse stream-json events and display relevant info
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
                "error")
                    error_msg=$(echo "$line" | jq -r '.message // .error // empty' 2>/dev/null)
                    echo -e "${RED}❌ Error: $error_msg${NC}"
                    ;;
            esac
        done
        return ${PIPESTATUS[0]}
    fi
    
    if result=$(gemini --model "$PRIMARY_MODEL" --output-format "$output_format" -y -p "$prompt" 2>&1); then
        echo "$result"
        return 0
    fi
    
    # Check if it's a quota error
    if echo "$result" | grep -q "quota"; then
        echo -e "${YELLOW}⚠️  Rate limit hit, falling back to $FALLBACK_MODEL...${NC}" >&2
        sleep 5
        gemini --model "$FALLBACK_MODEL" --output-format "$output_format" -y -p "$prompt"
        return $?
    fi
    
    # Other error - don't exit, report and continue
    echo -e "${RED}❌ Error occurred:${NC}" >&2
    echo "$result" >&2
    return 1
}

# Track phase success
PHASE_RESULTS=()

run_phase() {
    local phase_name="$1"
    local phase_func="$2"
    
    if ! $phase_func; then
        PHASE_RESULTS+=("❌ $phase_name: FAILED")
        echo -e "${RED}❌ Phase failed, continuing...${NC}"
        return 1
    else
        PHASE_RESULTS+=("✅ $phase_name: SUCCESS")
        return 0
    fi
}

# Header
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🚀 GEMINI MULTI-AGENT ORCHESTRATOR v${VERSION}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "📁 Output directory: ${GREEN}$OUTPUT_DIR${NC}"
echo -e "🤖 Primary Model: ${GREEN}$PRIMARY_MODEL${NC} (fallback: $FALLBACK_MODEL)"
echo -e "⏱️  Cooldown: ${GREEN}${COOLDOWN_SECONDS}s${NC}"
if $SKIP_TESTS; then echo -e "🧪 Tests: ${YELLOW}SKIPPED${NC}"; fi
if $SKIP_REVIEW; then echo -e "🔍 Review: ${YELLOW}SKIPPED${NC}"; fi
if $DRY_RUN; then echo -e "🏃 Mode: ${CYAN}DRY-RUN${NC}"; fi
if $STREAM_OUTPUT; then echo -e "📡 Streaming: ${GREEN}ENABLED${NC}"; fi
echo ""

# Create output directory
if ! $DRY_RUN; then
    mkdir -p "$OUTPUT_DIR"
    cd "$OUTPUT_DIR"
else
    echo -e "${CYAN}[DRY-RUN] Would create directory: $OUTPUT_DIR${NC}"
fi

# ============================================================
# Phase 1: Architect
# ============================================================
phase_architect() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}🏗️  PHASE 1: ARCHITECT AGENT${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    ARCHITECT_RESULT=$(run_gemini "
You are a Software Architect. Analyze these requirements and design the system:

$PROMPT

Output a detailed architecture plan including:
1. Project structure (all files/folders to create)
2. Component design
3. API specifications  
4. Data models
5. Implementation steps

Be specific about file paths and contents needed.
" "json")

    if ! $DRY_RUN; then
        # Extract response from JSON or use raw output
        if echo "$ARCHITECT_RESULT" | jq -r '.response' > architecture.md 2>/dev/null; then
            echo -e "${GREEN}✅ Architecture saved to architecture.md${NC}"
        else
            echo "$ARCHITECT_RESULT" > architecture.md
            echo -e "${GREEN}✅ Architecture saved to architecture.md${NC}"
        fi
    fi

    return 0
}

# ============================================================
# Phase 2: Developer
# ============================================================
phase_developer() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}👨‍💻 PHASE 2: DEVELOPER AGENT${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if ! $DRY_RUN; then
        ARCHITECTURE=$(cat architecture.md)
    else
        ARCHITECTURE="[Architecture from Phase 1]"
    fi

    run_gemini "
You are a Software Developer. Implement ALL the code based on this architecture:

$ARCHITECTURE

IMPORTANT:
- Create ALL files mentioned in the architecture
- Write complete, working code (no placeholders)
- Include proper error handling
- Add comments and documentation
- Create package.json, configuration files, etc.
"

    echo ""
    echo -e "${GREEN}✅ Code implementation complete${NC}"
    return 0
}

# ============================================================
# Phase 3: Tester
# ============================================================
phase_tester() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}🧪 PHASE 3: TESTER AGENT${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    run_gemini "
You are a Software Tester. Create comprehensive tests for the code in this directory.

Review all source files and create:
1. Unit tests for all functions/methods
2. Integration tests for API endpoints
3. Test configuration files
4. README updates with test instructions

Use appropriate testing frameworks for the language/stack.
"

    echo ""
    echo -e "${GREEN}✅ Tests created${NC}"
    return 0
}

# ============================================================
# Phase 4: Reviewer
# ============================================================
phase_reviewer() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}🔍 PHASE 4: REVIEWER AGENT${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    run_gemini "
You are an expert Code Reviewer and Security Auditor. Review all code in this directory.

Perform the following checks:

## Code Quality
- Code organization and structure
- Naming conventions and readability
- Error handling and edge cases
- Code duplication (DRY principle)

## Security
- Input validation and sanitization
- SQL injection vulnerabilities
- XSS vulnerabilities
- Hardcoded secrets or credentials

## Best Practices
- SOLID principles adherence
- Design patterns usage
- Performance considerations

Create a REVIEW.md file with your findings organized as:
1. **Critical Issues** - Must fix before production
2. **Warnings** - Should fix for better quality
3. **Suggestions** - Nice to have improvements
4. **Summary** - Overall code quality assessment (score out of 10)
"

    echo ""
    echo -e "${GREEN}✅ Code review complete${NC}"
    return 0
}

# ============================================================
# Execute Phases
# ============================================================

run_phase "Architect" phase_architect

echo ""
echo -e "${YELLOW}⏳ Cooling down (${COOLDOWN_SECONDS}s)...${NC}"
$DRY_RUN || sleep "$COOLDOWN_SECONDS"

run_phase "Developer" phase_developer

if ! $SKIP_TESTS; then
    echo ""
    echo -e "${YELLOW}⏳ Cooling down (${COOLDOWN_SECONDS}s)...${NC}"
    $DRY_RUN || sleep "$COOLDOWN_SECONDS"
    
    run_phase "Tester" phase_tester
fi

if ! $SKIP_REVIEW; then
    echo ""
    echo -e "${YELLOW}⏳ Cooling down (${COOLDOWN_SECONDS}s)...${NC}"
    $DRY_RUN || sleep "$COOLDOWN_SECONDS"
    
    run_phase "Reviewer" phase_reviewer
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}📊 ORCHESTRATION COMPLETE${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Show phase results
echo "Phase Results:"
for result in "${PHASE_RESULTS[@]}"; do
    echo "  $result"
done
echo ""

if ! $DRY_RUN; then
    echo -e "Project created in: ${BLUE}$(pwd)${NC}"
    echo ""
    echo "Files created:"
    find . -type f \( -name "*.js" -o -name "*.ts" -o -name "*.py" -o -name "*.json" -o -name "*.md" -o -name "*.html" -o -name "*.css" \) 2>/dev/null | sort | head -30
fi

echo ""
echo -e "${GREEN}🎉 Done! Your project is ready.${NC}"
