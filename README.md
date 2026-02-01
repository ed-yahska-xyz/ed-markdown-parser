# ed-markdown-parser

A simple markdown parser built in Zig. The implementation is divided into frontend and backend, where the backend parses markdown into an AST and the frontend renders HTML. Initially Claude Code was used for implementation to serve a purpose on a personal project. The overall goal is to use this project to learn Zig and learn to write parsers.

## Usage

### File Mode

Convert a markdown file to an HTML file:

```bash
zig run main.zig -- <input.md> <output.html>
```

Example:

```bash
zig run main.zig -- examples/input/zig-arrays-and-slices.md examples/output/zig-arrays-and-slices.html
```

### Stdio Mode

Read markdown from stdin and write HTML to stdout:

```bash
zig run main.zig -- --stdio
# or
zig run main.zig -- -
```

Example:

```bash
echo "# Hello World" | zig run main.zig -- --stdio
```

This is useful for piping content or integrating with other tools:

```bash
cat document.md | zig run main.zig -- - > output.html
```

## Running Tests

```bash
zig test main.zig
```
