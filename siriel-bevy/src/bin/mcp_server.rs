use serde_json::{json, Value};
use std::collections::HashMap;
use std::io::{self, BufRead, BufReader, Write};
use std::process::{Command, Stdio};

#[cfg(unix)]
use std::os::unix::process::ExitStatusExt;

/// MCP (Model Context Protocol) server for Siriel development tools
/// Exposes convert_mie, extract_levels, and other auxiliary tools
#[tokio::main]
async fn main() -> io::Result<()> {
    let mut server = MCPServer::new();
    server.run().await
}

struct MCPServer {
    tools: HashMap<String, ToolDefinition>,
}

#[derive(Clone)]
struct ToolDefinition {
    name: String,
    description: String,
    input_schema: Value,
    examples: Vec<String>,
}

impl MCPServer {
    fn new() -> Self {
        let mut tools = HashMap::new();

        // Register convert_mie tool
        tools.insert("convert_mie".to_string(), ToolDefinition {
            name: "convert_mie".to_string(),
            description: "Convert Siriel MIE level files to modern RON format with proper coordinate scaling and Y-axis flipping for Bevy".to_string(),
            input_schema: json!({
                "type": "object",
                "properties": {
                    "mode": {
                        "type": "string",
                        "enum": ["single", "batch", "batch-fmis", "batch-caul", "batch-gball"],
                        "description": "Conversion mode: single file, batch directory, or specific level sets"
                    },
                    "input": {
                        "type": "string",
                        "description": "Input MIE file path or directory (required for single/batch modes)"
                    },
                    "output": {
                        "type": "string",
                        "description": "Output RON file path (optional for single mode, auto-generated if not provided)"
                    }
                },
                "required": ["mode"]
            }),
            examples: vec![
                "Convert single file: {\"mode\": \"single\", \"input\": \"level1.MIE\", \"output\": \"level1.ron\"}".to_string(),
                "Batch convert directory: {\"mode\": \"batch\", \"input\": \"extracted_levels/SIRIEL35/\"}".to_string(),
                "Convert all FMIS levels: {\"mode\": \"batch-fmis\"}".to_string(),
                "Convert all CAUL levels: {\"mode\": \"batch-caul\"}".to_string(),
                "Convert all GBALL levels: {\"mode\": \"batch-gball\"}".to_string(),
            ],
        });

        // Register extract_levels tool
        tools.insert("extract_levels".to_string(), ToolDefinition {
            name: "extract_levels".to_string(),
            description: "Extract and decrypt MIE level files from original Siriel DAT archives with proper line ending conversion".to_string(),
            input_schema: json!({
                "type": "object",
                "properties": {
                    "dat_file": {
                        "type": "string",
                        "description": "Path to specific DAT file (optional - extracts all if not provided)"
                    }
                }
            }),
            examples: vec![
                "Extract all DAT files: {}".to_string(),
                "Extract specific DAT: {\"dat_file\": \"../siriel-3.5-dos/BIN/SIRIEL35.DAT\"}".to_string(),
                "Extract CAULDRON levels: {\"dat_file\": \"../siriel-3.5-dos/BIN/CAULDRON.DAT\"}".to_string(),
                "Extract GBALL levels: {\"dat_file\": \"../siriel-3.5-dos/BIN/GBALL.DAT\"}".to_string(),
            ],
        });

        // Register run_game tool
        tools.insert("run_game".to_string(), ToolDefinition {
            name: "run_game".to_string(),
            description: "Launch Siriel-Bevy game with optional level specification and debugging options".to_string(),
            input_schema: json!({
                "type": "object",
                "properties": {
                    "level": {
                        "type": "string",
                        "description": "Path to specific level RON file to load"
                    },
                    "verbose": {
                        "type": "boolean",
                        "description": "Enable verbose logging output",
                        "default": false
                    },
                    "release": {
                        "type": "boolean", 
                        "description": "Run in release mode for better performance",
                        "default": false
                    }
                }
            }),
            examples: vec![
                "Run with intro screen: {}".to_string(),
                "Run specific level: {\"level\": \"assets/levels/M1.ron\"}".to_string(),
                "Run with verbose logging: {\"verbose\": true}".to_string(),
                "Run in release mode: {\"release\": true, \"level\": \"assets/levels/M1.ron\"}".to_string(),
            ],
        });

        // Register build_project tool
        tools.insert(
            "build_project".to_string(),
            ToolDefinition {
                name: "build_project".to_string(),
                description: "Build the Siriel-Bevy project with various options".to_string(),
                input_schema: json!({
                    "type": "object",
                    "properties": {
                        "target": {
                            "type": "string",
                            "enum": ["all", "game", "convert_mie", "extract_levels", "mcp_server"],
                            "description": "What to build",
                            "default": "all"
                        },
                        "release": {
                            "type": "boolean",
                            "description": "Build in release mode",
                            "default": false
                        }
                    }
                }),
                examples: vec![
                    "Build everything: {}".to_string(),
                    "Build release: {\"release\": true}".to_string(),
                    "Build specific binary: {\"target\": \"convert_mie\"}".to_string(),
                    "Build tools in release: {\"target\": \"convert_mie\", \"release\": true}"
                        .to_string(),
                ],
            },
        );

        // Register level_info tool
        tools.insert(
            "level_info".to_string(),
            ToolDefinition {
                name: "level_info".to_string(),
                description:
                    "Display information about converted RON level files or analyze MIE files"
                        .to_string(),
                input_schema: json!({
                    "type": "object",
                    "properties": {
                        "file": {
                            "type": "string",
                            "description": "Path to level file (RON or MIE)"
                        },
                        "list_all": {
                            "type": "boolean",
                            "description": "List all available levels in assets/levels/",
                            "default": false
                        }
                    }
                }),
                examples: vec![
                    "List all levels: {\"list_all\": true}".to_string(),
                    "Analyze specific RON: {\"file\": \"assets/levels/M1.ron\"}".to_string(),
                    "Analyze MIE file: {\"file\": \"extracted_levels/SIRIEL35/M1.MIE\"}"
                        .to_string(),
                ],
            },
        );

        Self { tools }
    }

    async fn run(&mut self) -> io::Result<()> {
        let stdin = io::stdin();
        let mut stdin = stdin.lock();

        // Send a startup message to stderr for debugging
        eprintln!("Siriel MCP Server starting...");

        loop {
            let mut line = String::new();
            match stdin.read_line(&mut line) {
                Ok(0) => {
                    eprintln!("MCP server received EOF, shutting down");
                    break; // EOF
                }
                Ok(_) => {
                    let trimmed = line.trim();
                    if trimmed.is_empty() {
                        continue;
                    }

                    eprintln!("MCP server received: {}", trimmed);

                    match serde_json::from_str::<Value>(trimmed) {
                        Ok(request) => {
                            // Check if this is a notification (no id) or a request
                            if request.get("id").is_some() {
                                // This is a request, send a response
                                let response = self.handle_request(&request).await;
                                let response_str = serde_json::to_string(&response)?;
                                println!("{}", response_str);
                                eprintln!("MCP server responded: {}", response_str);
                                io::stdout().flush()?;
                            } else {
                                // This is a notification, handle but don't respond
                                eprintln!(
                                    "MCP server handling notification: {}",
                                    request
                                        .get("method")
                                        .unwrap_or(&Value::String("unknown".to_string()))
                                );
                                self.handle_notification(&request).await;
                            }
                        }
                        Err(e) => {
                            eprintln!("MCP server JSON parse error: {}", e);
                            // Send an error response
                            let error_response = json!({
                                "jsonrpc": "2.0",
                                "error": {
                                    "code": -32700,
                                    "message": "Parse error"
                                },
                                "id": null
                            });
                            println!("{}", serde_json::to_string(&error_response)?);
                            io::stdout().flush()?;
                        }
                    }
                }
                Err(e) => {
                    eprintln!("MCP server IO error: {}", e);
                    return Err(e);
                }
            }
        }
        Ok(())
    }

    async fn handle_request(&self, request: &Value) -> Value {
        let method = request.get("method").and_then(|m| m.as_str()).unwrap_or("");
        let id = request.get("id").cloned().unwrap_or(Value::Null);

        let result = match method {
            "initialize" => self.handle_initialize(),
            "tools/list" => self.handle_tools_list(),
            "tools/call" => self.handle_tools_call(request).await,
            _ => {
                return json!({
                    "jsonrpc": "2.0",
                    "error": {
                        "code": -32601,
                        "message": "Method not found"
                    },
                    "id": id
                });
            }
        };

        // Add the ID to the response
        let mut response = result;
        if let Value::Object(ref mut map) = response {
            map.insert("id".to_string(), id);
        }
        response
    }

    async fn handle_notification(&self, notification: &Value) {
        let method = notification
            .get("method")
            .and_then(|m| m.as_str())
            .unwrap_or("");

        match method {
            "initialized" => {
                eprintln!("MCP server initialized successfully");
            }
            _ => {
                eprintln!("Unknown notification method: {}", method);
            }
        }
    }

    fn handle_initialize(&self) -> Value {
        json!({
            "jsonrpc": "2.0",
            "result": {
                "protocolVersion": "2024-11-05",
                "capabilities": {
                    "tools": {}
                },
                "serverInfo": {
                    "name": "siriel-dev-tools",
                    "version": "1.0.0",
                    "description": "MCP server for Siriel game development tools"
                }
            }
        })
    }

    fn handle_tools_list(&self) -> Value {
        let tools: Vec<Value> = self
            .tools
            .values()
            .map(|tool| {
                json!({
                    "name": tool.name,
                    "description": tool.description,
                    "inputSchema": tool.input_schema
                })
            })
            .collect();

        json!({
            "jsonrpc": "2.0",
            "result": {
                "tools": tools
            }
        })
    }

    async fn handle_tools_call(&self, request: &Value) -> Value {
        let params = request.get("params").unwrap_or(&Value::Null);
        let tool_name = params.get("name").and_then(|n| n.as_str()).unwrap_or("");
        let default_args = Value::Object(Default::default());
        let arguments = params.get("arguments").unwrap_or(&default_args);

        match tool_name {
            "convert_mie" => self.call_convert_mie(arguments).await,
            "extract_levels" => self.call_extract_levels(arguments).await,
            "run_game" => self.call_run_game(arguments).await,
            "build_project" => self.call_build_project(arguments).await,
            "level_info" => self.call_level_info(arguments).await,
            _ => json!({
                "jsonrpc": "2.0",
                "error": {
                    "code": -32602,
                    "message": format!("Unknown tool: {}", tool_name)
                }
            }),
        }
    }

    async fn call_convert_mie(&self, args: &Value) -> Value {
        let mode = args
            .get("mode")
            .and_then(|m| m.as_str())
            .unwrap_or("single");
        let input = args.get("input").and_then(|i| i.as_str());
        let output = args.get("output").and_then(|o| o.as_str());

        let mut cmd_args = vec!["run", "--bin", "convert_mie", "--"];

        match mode {
            "batch" => {
                cmd_args.push("--batch");
                if let Some(input_path) = input {
                    cmd_args.push(input_path);
                } else {
                    return json!({
                        "jsonrpc": "2.0",
                        "error": {
                            "code": -32602,
                            "message": "Input path required for batch mode"
                        }
                    });
                }
            }
            "batch-fmis" => cmd_args.push("--batch-fmis"),
            "batch-caul" => cmd_args.push("--batch-caul"),
            "batch-gball" => cmd_args.push("--batch-gball"),
            "single" => {
                if let Some(input_path) = input {
                    cmd_args.push(input_path);
                    if let Some(output_path) = output {
                        cmd_args.push(output_path);
                    }
                } else {
                    return json!({
                        "jsonrpc": "2.0",
                        "error": {
                            "code": -32602,
                            "message": "Input path required for single mode"
                        }
                    });
                }
            }
            _ => {
                return json!({
                    "jsonrpc": "2.0",
                    "error": {
                        "code": -32602,
                        "message": format!("Unknown mode: {}", mode)
                    }
                })
            }
        }

        self.run_cargo_command(&cmd_args).await
    }

    async fn call_extract_levels(&self, args: &Value) -> Value {
        let mut cmd_args = vec!["run", "--bin", "extract_levels", "--"];

        if let Some(dat_file) = args.get("dat_file").and_then(|f| f.as_str()) {
            cmd_args.push(dat_file);
        }

        self.run_cargo_command(&cmd_args).await
    }

    async fn call_run_game(&self, args: &Value) -> Value {
        let mut cmd_args = vec!["run"];

        if args
            .get("release")
            .and_then(|r| r.as_bool())
            .unwrap_or(false)
        {
            cmd_args.push("--release");
        }

        cmd_args.push("--");

        if let Some(level) = args.get("level").and_then(|l| l.as_str()) {
            cmd_args.push("--level");
            cmd_args.push(level);
        }

        if args
            .get("verbose")
            .and_then(|v| v.as_bool())
            .unwrap_or(false)
        {
            cmd_args.push("--verbose");
        }

        self.run_cargo_command(&cmd_args).await
    }

    async fn call_build_project(&self, args: &Value) -> Value {
        let target = args.get("target").and_then(|t| t.as_str()).unwrap_or("all");
        let release = args
            .get("release")
            .and_then(|r| r.as_bool())
            .unwrap_or(false);

        let mut cmd_args = vec!["build"];

        if release {
            cmd_args.push("--release");
        }

        if target != "all" {
            cmd_args.push("--bin");
            cmd_args.push(target);
        }

        self.run_cargo_command(&cmd_args).await
    }

    async fn call_level_info(&self, args: &Value) -> Value {
        if args
            .get("list_all")
            .and_then(|l| l.as_bool())
            .unwrap_or(false)
        {
            // List all available levels
            match std::fs::read_dir("assets/levels") {
                Ok(entries) => {
                    let mut levels = Vec::new();
                    for entry in entries {
                        if let Ok(entry) = entry {
                            let path = entry.path();
                            if path.extension().and_then(|s| s.to_str()) == Some("ron") {
                                levels
                                    .push(path.file_name().unwrap().to_string_lossy().to_string());
                            }
                        }
                    }
                    levels.sort();

                    json!({
                        "jsonrpc": "2.0",
                        "result": {
                            "content": [{
                                "type": "text",
                                "text": format!("Available levels ({}):\n{}", levels.len(), levels.join("\n"))
                            }]
                        }
                    })
                }
                Err(e) => json!({
                    "jsonrpc": "2.0",
                    "error": {
                        "code": -32603,
                        "message": format!("Failed to read levels directory: {}", e)
                    }
                }),
            }
        } else if let Some(file_path) = args.get("file").and_then(|f| f.as_str()) {
            // Analyze specific file
            match std::fs::read_to_string(file_path) {
                Ok(content) => {
                    let info = if file_path.ends_with(".ron") {
                        format!(
                            "RON Level File: {}\n\nContent preview:\n{}",
                            file_path,
                            &content[..content.len().min(500)]
                        )
                    } else if file_path.ends_with(".MIE") {
                        format!("MIE Level File: {}\n\nSize: {} bytes\n\nTo convert to RON, use: convert_mie with single mode", 
                               file_path, content.len())
                    } else {
                        format!("File: {}\n\nSize: {} bytes", file_path, content.len())
                    };

                    json!({
                        "jsonrpc": "2.0",
                        "result": {
                            "content": [{
                                "type": "text",
                                "text": info
                            }]
                        }
                    })
                }
                Err(e) => json!({
                    "jsonrpc": "2.0",
                    "error": {
                        "code": -32603,
                        "message": format!("Failed to read file: {}", e)
                    }
                }),
            }
        } else {
            json!({
                "jsonrpc": "2.0",
                "error": {
                    "code": -32602,
                    "message": "Either 'file' or 'list_all' parameter required"
                }
            })
        }
    }

    async fn run_cargo_command(&self, args: &[&str]) -> Value {
        match Command::new("cargo")
            .args(args)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
        {
            Ok(mut child) => {
                let stdout = child.stdout.take().unwrap();
                let stderr = child.stderr.take().unwrap();

                let stdout_reader = BufReader::new(stdout);
                let stderr_reader = BufReader::new(stderr);

                let mut output_lines = Vec::new();
                let mut error_lines = Vec::new();

                // Read stdout
                for line in stdout_reader.lines() {
                    if let Ok(line) = line {
                        output_lines.push(line);
                    }
                }

                // Read stderr
                for line in stderr_reader.lines() {
                    if let Ok(line) = line {
                        error_lines.push(line);
                    }
                }

                let exit_status = match child.wait() {
                    Ok(status) => status,
                    Err(_) => {
                        #[cfg(unix)]
                        {
                            std::process::ExitStatus::from_raw(1)
                        }
                        #[cfg(not(unix))]
                        {
                            // On non-Unix systems, we'll have to simulate an exit status
                            // This is a fallback - ideally we'd handle the error properly
                            return json!({
                                "jsonrpc": "2.0",
                                "error": {
                                    "code": -32603,
                                    "message": "Failed to wait for process"
                                }
                            });
                        }
                    }
                };

                let output_text = if !output_lines.is_empty() {
                    output_lines.join("\n")
                } else {
                    "No output".to_string()
                };

                let error_text = if !error_lines.is_empty() {
                    format!("\n\nErrors/Warnings:\n{}", error_lines.join("\n"))
                } else {
                    String::new()
                };

                json!({
                    "jsonrpc": "2.0",
                    "result": {
                        "content": [{
                            "type": "text",
                            "text": format!("Command: cargo {}\n\nExit code: {}\n\nOutput:\n{}{}",
                                          args.join(" "),
                                          exit_status.code().unwrap_or(-1),
                                          output_text,
                                          error_text)
                        }]
                    }
                })
            }
            Err(e) => json!({
                "jsonrpc": "2.0",
                "error": {
                    "code": -32603,
                    "message": format!("Failed to execute command: {}", e)
                }
            }),
        }
    }
}
