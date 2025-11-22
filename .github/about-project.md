# DESCO Messenger Bot - AI Agent Instructions

## Project Overview
Facebook Messenger bot combining DESCO utility account management with advanced AI capabilities via Gemini CLI integration. Built with Flask, follows SOLID principles with layered architecture.

## Architecture Pattern

### Layer Structure (CRITICAL to understand)
```
bot.py                     # Entry point - Flask app initialization
├── src/routes/            # Interface layer - HTTP handlers
│   ├── webhook_routes.py  # Messenger webhook logic + command routing
│   └── cron_routes.py     # Scheduled tasks (retry, broadcast)
├── src/services/          # Business logic layer
│   └── account_service.py # DESCO account operations
├── src/clients/           # External API layer
│   ├── messenger_client.py # Facebook Graph API
│   ├── desco_client.py     # DESCO backend APIs
│   └── gemini_client.py    # Gemini CLI subprocess manager
└── src/tools/             # Gemini tool system (see below)
```

**Key principle**: Routes don't contain business logic. They delegate to services, which use clients.

## Message Routing Logic (webhook_routes.py)

### User Authorization Model
- `AUTHORIZED_PSID` env var defines the single authorized user
- **Authorized user**: No prefix → Gemini AI, `>>` → special Gemini commands, `/` → bot commands
- **Everyone else**: Only `/` commands (public features like `/summary`, `/ask`) + DESCO commands

### Command Prefix Semantics
1. **No prefix** (authorized only): Direct Gemini conversation with context
2. **`>>`** (authorized only): Special Gemini commands (`start new session`, `list tools`, `my session`)
3. **`/`**: Bot commands - mix of public AI features and DESCO utilities

### Critical: Reply Context Security
When users reply to a message, context is ONLY injected for safe `/` commands (`/ask`, `/summarize`, etc). Never inject context for bare messages or auth-only commands to prevent privilege escalation. See lines 640-670 in `webhook_routes.py`.

## Gemini CLI Tool System

### Tool Execution Flow
```
User message → GeminiClient.run_worker() → Gemini CLI subprocess
    → Response parsed by ToolExecutor.parse_tool_call()
    → Tool executed via ToolRegistry
    → Result sent back to Gemini → Final response to user
```

### Adding New Tools (3-step process)
1. Create tool in `src/tools/your_tool.py` inheriting from `BaseTool`
2. Implement `name`, `description`, `parameters`, and `execute()` methods
3. Register in `GeminiClient._register_tools()` in `gemini_client.py`

**Example pattern**: See `src/tools/google_search.py` for reference implementation

### Tool Categories
- **File ops**: read_file, write_file, append_file, replace_in_file, delete_file, list_files
- **Search & OSINT**: google_web_search, web_scrape, social_recon, facebook_scraper, image_intelligence, email_intelligence, phone_intelligence
- **Fabric AI**: fabric_executor (runs Fabric patterns), fabric_analyzer, content_compiler
- **Utility**: execute_command, run_shell_command, http_request, youtube_transcript

## Fabric AI Integration

### What is Fabric?
Fabric is a pattern-based AI system for content analysis. Patterns are stored as `system.md` files in:
- Standard: `src/fabric/patterns/{pattern_name}/system.md`
- Custom: `src/fabric/custom-patterns/{pattern_name}/system.md`

### Executing Fabric Patterns
`FabricExecutorTool` reads pattern's `system.md` and sends it + user content to Gemini CLI as a prompt override. This bypasses the main system prompt to execute pattern instructions exactly.

**Key files**: 
- `src/tools/fabric_executor.py` - Real execution
- `src/tools/fabric_analyzer.py` - Pattern discovery
- `src/routes/webhook_routes.py` lines 200-350 - Public command handlers

### Public Fabric Commands
Available to all users via `/` prefix:
- `/ask <query>` - Smart routing (detects intent, picks pattern automatically)
- `/summarize <text>` - Summarize content
- `/translate <lang> <text>` - Translate (e.g., `bn` for Bengali)
- `/explain <text>` - Explain code or concepts
- `/improve <text>` - Improve writing
- `/ideas <text>` - Extract key ideas
- `/quiz <material>` - Create quiz questions
- `/terms <text>` - Explain technical terms
- `/summary <url> [bn]` - YouTube video summary (uses transcript + extract_wisdom pattern)

## Background Processing Pattern

### Why Threading?
Long-running operations (Gemini calls, YouTube processing, Fabric analysis) use background threads to avoid blocking. Critical pattern:

```python
self.messenger_client.send_typing_indicator(psid)
thread = threading.Thread(target=self._process_worker, args=(psid, content), daemon=True)
thread.start()
```

### Keep-Alive Typing Indicator
For 60+ second operations, use a timer thread to send typing indicators every 15 seconds:
```python
stop_typing = threading.Event()
def keep_typing():
    while not stop_typing.is_set():
        time.sleep(15)
        if not stop_typing.is_set():
            self.messenger_client.send_typing_indicator(psid)
```
See `webhook_routes.py` lines 230-250 for reference implementation.

## Database & State Management

### Simple JSON Storage
`users.json` stores user state with auto-repair for malformed JSON (see `src/utils/database.py`).

**User structure**:
```python
{
  "psid": {
    "step": "active",  # State machine: intro → awaiting_consent → awaiting_account → active
    "user_name": "John Doe",
    "account_no": "34393408",
    "source": "unified" | "tkdes",
    "active": True,
    "retry": {"attempts": 1, "next_retry_at": "ISO8601"},
    "gemini_session_id": "use_latest",  # Gemini session tracking
    "message_history": [{"mid": "...", "text": "...", "timestamp": 123}]  # Reply context
  }
}
```

**Critical**: Always `load_db()` at start of request, modify, then `save_db()` at end. Concurrent requests may cause race conditions but acceptable for this scale.

## Gemini CLI Session Management

### Session Strategy
- Default: `"use_latest"` - Gemini CLI auto-resumes most recent session (fast, no session ID tracking)
- On `>> start new session`: Clears session marker, next call loads full context from GEMINI_SYSTEM_PROMPT.md
- Never manually track session IDs unless user explicitly requests

**System prompt**: `GEMINI_SYSTEM_PROMPT.md` (~15KB) defines Gemini's personality, capabilities, tool usage instructions

## Testing & Development

### Local Development
```bash
# Activate virtual environment
source env/bin/activate

# Run bot
python bot.py

# Watch logs
tail -f bot.log  # If logging to file, or use print() statements
```

### Testing Tools Directly
```bash
python test_fabric_executor.py  # Test Fabric patterns
python test_youtube_summary.py  # Test YouTube transcript extraction
```

### Environment Variables Required
- `PAGE_ACCESS_TOKEN`, `VERIFY_TOKEN`, `PAGE_ID` - Facebook Messenger
- `AUTHORIZED_PSID` - Single authorized user PSID
- `GOOGLE_API_KEY`, `GOOGLE_SEARCH_ENGINE_ID` - Google Custom Search
- `GEMINI_SYSTEM_FILE` - Path to system prompt (defaults to `GEMINI_SYSTEM_PROMPT.md`)
- `GEMINI_WORKING_DIR` - Gemini CLI working directory (defaults to project root)

## Common Pitfalls

1. **Don't block the webhook**: Use threading for long operations, always return `"ok", 200` immediately
2. **Don't parse messages twice**: Store original message before context injection, use for routing decisions
3. **Don't forget typing indicators**: User feedback essential for 10+ second operations
4. **Don't mix command prefixes**: Each prefix has specific semantics and security implications
5. **Tool execution is async**: Parse tool calls from Gemini response, execute, send result back to Gemini for final analysis
6. **Fabric pattern override**: Use CRITICAL INSTRUCTION block to ensure pattern takes precedence over system prompt

## Code Style & Conventions

- Docstrings: Google style with type hints
- Logging: Use `log()` from `src/utils/logger.py` with emoji prefixes for categories
- Error handling: Wrap tool execution in try/except, return `{"error": "message"}` format
- Message formatting: Emoji-first for visual clarity (🔍, 📹, ✅, ❌, 🔧, 🧠)
- File organization: One class per file, grouped by responsibility

## Debugging Workflow

1. Check logs for `[Category]` prefixes: `[Gemini Worker]`, `[Tool Executor]`, `[Fabric Command]`, etc.
2. For tool issues: Verify tool is registered in `gemini_client.py` and name matches exactly
3. For Gemini issues: Check `GEMINI_SYSTEM_PROMPT.md` loaded successfully (logs show char count)
4. For webhook issues: Facebook sends malformed data sometimes - validate structure before accessing fields
