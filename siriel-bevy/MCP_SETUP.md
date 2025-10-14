# Siriel MCP Integration Setup

This document explains how to set up the Model Context Protocol (MCP) integration for Siriel development tools with Warp terminal.

## What is MCP?

MCP (Model Context Protocol) allows AI assistants to access and use your development tools directly. Instead of manually running commands like `cargo run --bin convert_mie --batch`, the AI can invoke these tools automatically when you ask questions like "convert all the FMIS levels".

## Available Tools

Our MCP server exposes these Siriel development tools:

### 1. `convert_mie` 
Convert MIE level files to RON format with proper coordinate scaling
- **single**: Convert one MIE file 
- **batch**: Batch convert a directory of MIE files
- **batch-fmis**: Convert all FMIS*.MIE levels
- **batch-caul**: Convert all CAUL*.MIE levels  
- **batch-gball**: Convert all GBALL*.MIE levels

### 2. `extract_levels`
Extract and decrypt levels from DAT archives
- Supports SIRIEL35.DAT, CAULDRON.DAT, GBALL.DAT, WAY.DAT
- Handles line ending conversion automatically

### 3. `run_game`
Launch the Siriel-Bevy game
- Optional level specification
- Verbose logging mode
- Release mode for better performance

### 4. `build_project`  
Build the project with various options
- Specific binary targets (game, convert_mie, extract_levels, mcp_server)
- Debug or release mode

### 5. `level_info`
Analyze level files and project state
- List all converted levels
- Examine RON or MIE file contents
- Show level statistics

## Setup Instructions

### Step 1: Build the MCP Server

```bash
cd siriel/siriel-bevy
cargo build --bin mcp_server
```

### Step 2: Configure Warp Terminal

1. Open Warp terminal settings
2. Navigate to the MCP configuration section  
3. Add the configuration from `warp_mcp_config.json`:

**Important**: Make sure the `working_directory` field points to your actual project directory.

```json
{
  "siriel-dev-tools": {
    "command": "cargo",
    "args": [
      "run",
      "--bin", 
      "mcp_server"
    ],
    "env": {},
    "working_directory": "....siriel/siriel-bevy"
  }
}
```

### Step 3: Restart Warp

Restart Warp terminal to activate the MCP integration.

### Step 4: Test the Integration

You should now be able to ask the AI assistant:

- **"Convert all FMIS levels"** → Uses `convert_mie` with `batch-fmis` mode
- **"Extract levels from the DAT files"** → Uses `extract_levels` 
- **"Run the game with level M1"** → Uses `run_game` with level parameter
- **"Show me all available levels"** → Uses `level_info` with list_all option
- **"Build the project in release mode"** → Uses `build_project` with release flag

## Workflows

The MCP server understands these common workflows:

### Full Level Conversion
1. Extract all DAT files → `extract_levels`
2. Convert each level set → `convert_mie` in batch modes
3. Verify conversions → `level_info`

### Single Level Test  
1. Convert specific level → `convert_mie` single mode
2. Run game with level → `run_game` 
3. Build if needed → `build_project`

### Development Cycle
1. Build changes → `build_project`
2. Test game → `run_game`
3. Convert levels if data changed → `convert_mie`
4. Analyze results → `level_info`

## Benefits

With MCP integration, you can:

- **Forget command syntax**: Just describe what you want to do
- **Automatic tool selection**: AI picks the right tool and parameters  
- **Workflow automation**: Complex multi-step processes handled automatically
- **Context awareness**: AI remembers your project structure and available tools
- **Consistent results**: Same coordinate conversion and file handling every time

## Troubleshooting

### MCP Server Won't Start
```bash
# Check if it builds correctly
cargo build --bin mcp_server

# Test it manually
cargo run --bin mcp_server
```

### Tools Not Appearing in Warp
1. Verify the configuration path matches your project directory
2. Check that Warp has been restarted after configuration
3. Ensure the `cargo` command is in your PATH

### Command Execution Fails
- Verify you're in the correct working directory
- Check that all project dependencies are installed
- Make sure DAT files exist in the expected location

## Advanced Configuration

You can modify `src/bin/mcp_server.rs` to:
- Add new tools
- Change command parameters
- Add project-specific validation
- Customize error handling
- Add logging and debugging features

The MCP server automatically discovers available Cargo binary targets and exposes them through the protocol.
