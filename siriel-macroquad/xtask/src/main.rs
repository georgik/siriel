use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use tokio::fs as async_fs;

#[derive(Parser)]
#[command(name = "xtask")]
#[command(about = "Siriel Macroquad - Build and Development Tools")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Build WASM for web deployment
    BuildWasm {
        #[arg(long, short)]
        verbose: bool,
    },
    /// Build and serve WASM locally for development
    ServeWasm {
        #[arg(long, short)]
        verbose: bool,
        #[arg(long)]
        port: Option<u16>,
    },
    /// Clean build artifacts
    Clean,
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::BuildWasm { verbose } => build_wasm(verbose).await,
        Commands::ServeWasm { verbose, port } => serve_wasm(verbose, port).await,
        Commands::Clean => clean(),
    }
}

async fn build_wasm(verbose: bool) -> Result<()> {
    println!("Building Siriel WASM...");
    println!();

    let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let project_root = manifest_dir.parent().unwrap();
    let target_dir = project_root.join("target");
    let dist_dir = project_root.join("dist");

    // Build WASM
    let mut cmd = Command::new("cargo");
    cmd.arg("build")
        .arg("--target")
        .arg("wasm32-unknown-unknown")
        .arg("--release")
        .current_dir(project_root);

    if verbose {
        cmd.arg("--verbose");
        println!("Running: {:?}", cmd);
    }

    let status = cmd.status().context("Failed to build WASM")?;

    if !status.success() {
        anyhow::bail!("WASM build failed");
    }

    // Create dist directory
    async_fs::create_dir_all(&dist_dir).await?;
    async_fs::create_dir_all(dist_dir.join("assets")).await?;

    // Copy WASM file
    let wasm_src = target_dir
        .join("wasm32-unknown-unknown")
        .join("release")
        .join("siriel.wasm");

    if !wasm_src.exists() {
        anyhow::bail!("WASM file not found at {:?}", wasm_src);
    }

    let wasm_dest = dist_dir.join("siriel.wasm");
    async_fs::copy(&wasm_src, &wasm_dest).await?;
    println!("Copied WASM to {:?}", wasm_dest);

    // Copy index.html
    let html_src = project_root.join("index.html");
    if html_src.exists() {
        async_fs::copy(&html_src, dist_dir.join("index.html")).await?;
        println!("Copied index.html");
    }

    // Copy favicon if exists
    let favicon_src = project_root.join("favicon.ico");
    if favicon_src.exists() {
        async_fs::copy(&favicon_src, dist_dir.join("favicon.ico")).await?;
    }

    // Copy assets
    let assets_src = project_root.join("assets");
    if assets_src.exists() {
        copy_dir_recursive(&assets_src, &dist_dir.join("assets")).await?;
        println!("Copied assets/");
    }

    println!();
    println!("Build complete! Output: {}/", dist_dir.display());
    println!("To test locally: cargo xtask serve-wasm");

    Ok(())
}

async fn serve_wasm(verbose: bool, port: Option<u16>) -> Result<()> {
    let port = port.unwrap_or(8000);

    // Build first
    build_wasm(verbose).await?;

    println!();
    println!("Starting HTTP server on http://localhost:{}", port);
    println!("Press Ctrl+C to stop");
    println!();

    let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let dist_dir = manifest_dir.parent().unwrap().join("dist");

    // Use tiny_http for serving - spawn in thread to handle blocking
    let server = tiny_http::Server::http(&format!("0.0.0.0:{}", port))
        .map_err(|e| anyhow::anyhow!("Failed to bind to port: {}", e))?;

    println!("Serving from: {}", dist_dir.display());

    for request in server.incoming_requests() {
        let url = request.url().to_string();
        let path = if url == "/" {
            "index.html"
        } else {
            url.trim_start_matches('/')
        };

        let file_path = dist_dir.join(path);

        if let Ok(content) = fs::read(&file_path) {
            let mime = mime_guess::from_path(&file_path)
                .first_or_octet_stream()
                .to_string();

            let response = tiny_http::Response::from_data(content).with_header(
                tiny_http::Header::from_bytes(&b"Content-Type"[..], mime.as_bytes()).unwrap(),
            );

            let _ = request.respond(response);
        } else {
            let response = tiny_http::Response::from_string("404 Not Found").with_status_code(404);
            let _ = request.respond(response);
        }
    }

    Ok(())
}

fn clean() -> Result<()> {
    println!("Cleaning build artifacts...");

    let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let project_root = manifest_dir.parent().unwrap();
    let dist_dir = project_root.join("dist");

    if dist_dir.exists() {
        fs::remove_dir_all(&dist_dir)?;
        println!("Removed {}", dist_dir.display());
    }

    println!("Clean complete!");
    Ok(())
}

async fn copy_dir_recursive(src: &Path, dst: &Path) -> Result<()> {
    let mut entries = async_fs::read_dir(src).await?;

    while let Some(entry) = entries.next_entry().await? {
        let ty = entry.file_type().await?;
        let src_path = entry.path();
        let dst_path = dst.join(entry.file_name());

        if ty.is_dir() {
            async_fs::create_dir_all(&dst_path).await?;
            Box::pin(copy_dir_recursive(&src_path, &dst_path)).await?;
        } else {
            async_fs::copy(&src_path, &dst_path).await?;
        }
    }

    Ok(())
}
