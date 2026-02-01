# ed-markdown-parser

A simple markdown parser built in Zig. The implementation is divided into frontend and backend, where the backend parses markdown into an AST and the frontend renders HTML. Initially Claude Code was used for implementation to serve a purpose on a personal project. The overall goal is to use this project to learn Zig and learn to write parsers.

## Building

### Debug Build

```bash
zig build
```

The executable will be at `zig-out/bin/md2html`.

### Release Build

Build an optimized release for your current platform:

```bash
zig build release
```

### Cross-Compile for All Platforms

Build optimized binaries for all supported platforms:

```bash
zig build build-all
```

This creates binaries in `zig-out/bin/`:

| Binary | Platform |
|--------|----------|
| `md2html-darwin-arm64` | macOS Apple Silicon |
| `md2html-darwin-x64` | macOS Intel |
| `md2html-linux-arm64` | Linux ARM64 |
| `md2html-linux-x64` | Linux x64 |
| `md2html-win32-arm64.exe` | Windows ARM64 |
| `md2html-win32-x64.exe` | Windows x64 |

## Usage

### File Mode

Convert a markdown file to an HTML file:

```bash
zig build run -- <input.md> <output.html>
```

Example:

```bash
zig build run -- examples/input/zig-arrays-and-slices.md examples/output/zig-arrays-and-slices.html
```

Or use the built executable directly:

```bash
./zig-out/bin/md2html input.md output.html
```

### Stdio Mode

Read markdown from stdin and write HTML to stdout:

```bash
zig build run -- --stdio
# or
zig build run -- -
```

Example:

```bash
echo "# Hello World" | ./zig-out/bin/md2html --stdio
```

This is useful for piping content or integrating with other tools:

```bash
cat document.md | ./zig-out/bin/md2html - > output.html
```

### Worker Mode

Long-running worker mode with a length-prefixed framing protocol. Useful for integration with web servers or other processes:

```bash
./zig-out/bin/md2html --worker
```

Protocol:
- Request: `<LEN>\n<LEN bytes of markdown>`
- Response: `<LEN>\n<LEN bytes of html>`

The worker processes requests sequentially and exits cleanly on EOF.

## Running Tests

Run all tests:

```bash
zig build test
```

Run specific test suites:

```bash
zig build test-main      # Integration and worker tests
zig build test-parser    # Parser unit tests
zig build test-html      # HTML renderer tests
```
