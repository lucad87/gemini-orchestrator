# Gemini Multi-Agent Orchestrator

A shell-based multi-agent orchestration system for [Gemini CLI](https://github.com/google-gemini/gemini-cli) that coordinates specialized AI agents to build complete software projects.

## Overview

This orchestrator spawns multiple Gemini CLI sessions, each with a specific role:

| Phase | Agent | Role |
|-------|-------|------|
| 1 | 🏗️ **Architect** | Designs system structure, APIs, data models |
| 2 | 👨‍💻 **Developer** | Implements all code based on architecture |
| 3 | 🧪 **Tester** | Creates unit and integration tests |
| 4 | 🔍 **Reviewer** | Reviews code for quality and security |

## Prerequisites

- Node.js 20+
- [Gemini CLI](https://github.com/google-gemini/gemini-cli) installed globally
- `jq` (for JSON parsing)

## Installation

### 1. Install Gemini CLI globally

```bash
npm install -g @google/gemini-cli
```

### 2. Install the orchestrator

```bash
# Clone this repository
git clone https://github.com/YOUR_USERNAME/gemini-orchestrator.git
cd gemini-orchestrator

# Run the install script
./install.sh
```

### 3. Add to PATH

Add this line to your `~/.zshrc` or `~/.bashrc`:

```bash
export PATH="$HOME/.gemini/scripts:$PATH"
```

Then reload: `source ~/.zshrc`

### Uninstall

To remove the orchestrator:

```bash
./uninstall.sh
```

## Project Structure

```
gemini-orchestrator/
├── commands/
│   ├── architect.toml      # Architect agent custom command
│   ├── developer.toml      # Developer agent custom command
│   ├── tester.toml         # Tester agent custom command
│   ├── reviewer.toml       # Reviewer agent custom command
│   └── orchestrator.toml   # Orchestrator custom command
├── scripts/
│   └── gemini-orchestrate.sh   # Main orchestration script
├── install.sh              # Installation script
├── uninstall.sh            # Uninstallation script
├── LICENSE
└── README.md
```

## Usage

### Basic Usage

```bash
gemini-orchestrate.sh "Your project description" ./output-directory
```

### Command Line Options

```
Options:
  -h, --help          Show help message
  -v, --version       Show version number
  -m, --model MODEL   Set the primary model (default: gemini-2.5-flash)
  --skip-tests        Skip the tester agent phase
  --skip-review       Skip the reviewer agent phase
  --dry-run           Show what would happen without executing
  --stream            Enable real-time streaming output from agents
  --cooldown SECS     Set cooldown between phases (default: 10)
```

### Examples

**Basic project:**
```bash
gemini-orchestrate.sh "Create a TODO list API with Node.js and Express" ./todo-api
```

**With streaming output (see agent progress in real-time):**
```bash
gemini-orchestrate.sh --stream "Build a REST API" ./api
```

**Skip tests for faster iteration:**
```bash
gemini-orchestrate.sh --skip-tests "Build a CLI tool in Python" ./my-cli
```

**Use a different model:**
```bash
gemini-orchestrate.sh --model gemini-2.5-pro "Complex microservices app" ./app
```

**Dry run to see what would happen:**
```bash
gemini-orchestrate.sh --dry-run "Test project" ./test
```

**Skip both tests and review:**
```bash
gemini-orchestrate.sh --skip-tests --skip-review "Quick prototype" ./prototype
```

### Using Custom Commands Directly

You can also use the individual agent commands directly in Gemini CLI:

```bash
# Architect agent
gemini /architect "Design a REST API for a blog platform"

# Developer agent
gemini /developer "Implement based on this architecture: ..."

# Tester agent
gemini /tester "Create tests for the current project"

# Reviewer agent
gemini /reviewer "Review code in this directory"

# Full orchestration
gemini /orchestrator "Build a complete TODO app with Node.js"
```

## Configuration

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `GEMINI_MODEL` | `gemini-2.5-flash` | Primary model to use |
| `GEMINI_API_KEY` | (none) | API key for higher rate limits |
| `GEMINI_COOLDOWN` | `10` | Seconds to wait between phases |

## How It Works

1. **Architect Agent** analyzes requirements and outputs `architecture.md` with:
   - Project structure
   - Component design
   - API specifications
   - Data models
   - Implementation steps

2. **Developer Agent** reads the architecture and creates all files:
   - Source code
   - Configuration files
   - Package manifests
   - Documentation

3. **Tester Agent** reviews the code and creates:
   - Unit tests
   - Integration tests
   - Test configuration
   - Updated README with test instructions

4. **Reviewer Agent** performs code review and creates `REVIEW.md` with:
   - Critical issues (must fix)
   - Warnings (should fix)
   - Suggestions (nice to have)
   - Overall quality score

Each phase includes a configurable cooldown period to respect API rate limits.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `gemini: command not found` | Run `npm install -g @google/gemini-cli` |
| Rate limit errors | Use `gemini-2.5-flash` or set `GEMINI_API_KEY` |
| Script not found | Ensure `~/.gemini/scripts` is in your `$PATH` |
| Custom commands not found | Run `./install.sh` to copy commands |

## License

MIT License - see [LICENSE](LICENSE) for details.

---

## Test Migration Tool

A specialized tool for migrating tests between frameworks (e.g., WDIO → Playwright).

### Usage

```bash
gemini-migrate-tests.sh [options] <source-dir> <target-dir>
```

### Options

```
  -h, --help              Show help message
  -v, --version           Show version number
  -m, --model MODEL       Set the primary model (default: gemini-2.5-flash)
  --source-framework FW   Source framework (default: wdio)
  --target-framework FW   Target framework (default: playwright)
  --source-lang LANG      Source language (default: javascript)
  --target-lang LANG      Target language (default: typescript)
  --dry-run               Show what would happen without executing
  --stream                Enable real-time streaming output
```

### Examples

**Migrate WDIO (JS) to Playwright (TS):**
```bash
gemini-migrate-tests.sh ./wdio-project/tests ./playwright-project/tests
```

**With streaming output:**
```bash
gemini-migrate-tests.sh --stream ./old-tests ./new-tests
```

**Migrate Cypress to Playwright:**
```bash
gemini-migrate-tests.sh --source-framework cypress ./cypress/e2e ./playwright/tests
```

### What It Does

1. **Analyzes Source Tests** - Reads all test files, identifies test suites, cases, page objects
2. **Analyzes Target Project** - Learns the existing conventions, import aliases, file structure
3. **Executes Migration** - Creates equivalent tests following target project patterns

### Migration Features

- Converts framework-specific commands (e.g., `$(selector)` → `page.locator(selector)`)
- Adapts to TypeScript with proper types
- Uses target project's import aliases (e.g., `@pages/`, `@utils/`)
- Matches existing code style and patterns
- Creates/extends page objects as needed
- Generates `MIGRATION.md` report

### Using Custom Command Directly

You can also use the migration command directly in Gemini CLI:

```bash
gemini /migrate-tests "
Source: /path/to/wdio-tests (wdio/javascript)
Target: /path/to/playwright-tests (playwright/typescript)

Migrate all login and checkout tests.
"
```

---

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Acknowledgments

Built on top of [Gemini CLI](https://github.com/google-gemini/gemini-cli) by Google.
