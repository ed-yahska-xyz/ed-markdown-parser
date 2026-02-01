## Markdown to HTML

I am planning to create a Markdown to Html program in Zig.
The project is conceptualized in 2 stages, Frontend and Backend, as most code translation/compilation like projects are.

### Backend

The parser.zig will take in string contents of a markdown file and create an AST. The module in fe-html.zig will take the AST as input and output html string.

This program will use a tagged union to represent blocks of markdown.
Following are examples of the structs in Zig that will represent the markdown blocks:

```
const Node = union(enum) {
    document: Document,
    heading: Heading,
    paragraph: Paragraph,
    text: Text,
    blockquote: Blockquote,
    list: List,
    list_item: ListItem,
    code: Code,
    code_block: CodeBlock,
    inline_bold: InlineBold,
    inline_italics: InlineItalics,
    image: Image,
    link: Link,
    horizontal_rule: HorizontalRule,
    line_break: void,
};

const Document = struct {
    children: []const *Node,
};

const Heading = struct {
    level: u8,
    children: []const *Node, // inline nodes
};

const Paragraph = struct {
    children: []const *Node, // inline nodes
};

const Text = struct {
    value: []const u8,
};

const Blockquote = struct {
    children: []const *Node,
};

const List = struct {
    ordered: bool,
    marker: u8, // '-', '*', '+' for unordered; start number for ordered
    children: []const *Node, // list items
};

const HorizontalRule = struct {};

const CodeBlock = struct {
    language: ?[]const u8,
    value: []const u8,
};

const ListItem = struct {
    children: []const *Node,
};

const Code = struct {
    value: []const u8,
};

const InlineBold = struct {
    children: []const *Node,
};

const InlineItalics = struct {
    children: []const *Node,
};

const Image = struct {
    alt: []const u8,
    src: []const u8,
    title: ?[]const u8,
};

const Link = struct {
    children: []const *Node, // link text can contain inline nodes
    href: []const u8,
    title: ?[]const u8,
};
```

The parser will likely be a recursive function that accepts a `Node`. It scans the input text line by line, separated by newline \n.
The parser then reads the beginning of the like and checks if it is one of the following syntax elements of markdown:

- tab or 4 spaces (indent)
    - close the previous node by pushing it in the children array of the parent, create a new node and recursively start the parser operation.
- \ (single backward slash as escape)
    - Ignore this specific instance of \ and consider the following character as plain text and not markdown syntax.
- \# (pound sign)
    - Determine how many pound signs follow and record in level of the heading struct. There are 6 possible levels of headings.
    - Once a `space` character is found, record the remaining text in the children of the Heading struct as inline nodes.
- \> (right angle bracket used for blockquote)
    - Once a blockquote starts, scan all the lines followed by this line until an empty line is discovered. An empty line is a newline followed by another new line. Ignore whitespace between the 2 newlines
    - If an indent (tab or 4 spaces) is encountered, create a `Node`, push this node in the children of blockquote and recursively start the parser operation.
- \-, \*, \+ (list item)
    - Once any of the list item characters are encountered, record it as the current list item character and scan all the remaining lines until a space is found or a different list element is found.
    - if an indent is found close the current Node by putting it in the children of the parent node, create a new node and recursively start a new parser operation
- \` (tick / code)
    - This is an inline markdown syntax, which means close the current text node by entering it into parent children array and start a new `Tick` node.
    - Check if a tick is followed by another tick.
        - if yes, ignore all following single instances of tick as markdown syntax and treat them as escaped. continue to parse until double tick is encountered.
        - if no, create a text node from the following string until anoter tick is encountered.
- \*\* bold, two consecutive asterisk
    - This is an inline markdown syntax, which means close the current text node by entering it into parent children array and start a new `InlineBold` node.
    - Start a recursive parser operation to parse the text until the end of `InlineBold`.
    - Once another 2 consecutive asterisk are found close the current `InlineBold` node by putting it in the children of the parent.
- \* single asterisk (not followed by another \*)
    - This is an inline markdown syntax, which means close the current text node by entering it into parent children array and start a new `InlineItalics` node.
    - Start a recursive parser operation to parse the text until the end of `InlineItalics`.
    - Once another single asterisk is found, close the current `InlineItalics` node by putting it in the children of the parent.
- \! Image
    - \[ start of image alt text, read the text in a text node
        - read the text until a \] 
        - \] The alt text has ended, this should ideally be followed by
        - \( This starts the location or `uri` of the image, read the image source until a \) or \" is found.
            - \" start of image title
                - read the following text as the title of the image until another \" is found.
            - \) end the `Image` node.
- \[ Link
    - This is an inline markdown syntax, which means close the current text node by entering it into parent children array and start a new `Link` node.
    - Read the text until a \] is found
    - \] The link text has ended, this should ideally be followed by
    - \( This starts the `uri` of the link, read the link href until a \) or \" is found.
        - \" start of link title
            - read the following text as the title of the link until another \" is found.
        - \) end the `Link` node.
    - If \] is not followed by \(, treat the entire sequence as plain text (not a link).
- \-\-\- or \*\*\* or \_\_\_ (horizontal rule)
    - Three or more consecutive dashes, asterisks, or underscores on a line by themselves.
    - Create a `HorizontalRule` node (no children or content).
- \`\`\` or \~\~\~ (fenced code block)
    - Triple backticks or tildes start a code block.
    - Optionally followed by a language identifier on the same line (e.g., \`\`\`zig).
    - Read all lines until closing triple backticks/tildes are found.
    - Store content in `CodeBlock` with `language` and `value` fields.
- 1. 2. 3. (ordered list)
    - A number followed by `.` and a space starts an ordered list.
    - Set `ordered: true` in the List struct.
    - The starting number is stored in `marker` field.
    - Continue scanning for subsequent numbered items.
- Two trailing spaces or \\ at end of line (line break)
    - Create a `line_break` node to represent `<br>` in HTML.
    - This is a hard line break within a paragraph.
- HTML escaping
    - When rendering to HTML, escape special characters:
        - `<` becomes `&lt;`
        - `>` becomes `&gt;`
        - `&` becomes `&amp;`
        - `"` becomes `&quot;` (in attributes)

### Frontend

The frontend (`fe-html.zig`) converts the AST to HTML. The implementation uses a modular design with separate render functions for each node type.

#### Main Entry Point

```zig
pub fn renderHtml(node: *const Node, writer: anytype) RenderError!void
```

Dispatches to specialized render functions based on node type.

#### Render Functions

Each node type has its own render function:

- `renderDocument(doc, writer)` - Renders document children sequentially
- `renderHeading(h, writer)` - Outputs `<h1>`-`<h6>` based on level
- `renderParagraph(p, writer)` - Wraps content in `<p>` tags
- `renderText(t, writer)` - Outputs escaped text content
- `renderBlockquote(bq, writer)` - Wraps in `<blockquote>` tags
- `renderList(l, writer)` - Outputs `<ul>` or `<ol>` based on `ordered` field
- `renderListItem(li, writer)` - Wraps content in `<li>` tags
- `renderCode(c, writer)` - Wraps escaped code in `<code>` tags
- `renderCodeBlock(cb, writer)` - Outputs `<pre><code>` with optional language class
- `renderInlineBold(b, writer)` - Wraps content in `<strong>` tags
- `renderInlineItalics(i, writer)` - Wraps content in `<em>` tags
- `renderImage(img, writer)` - Outputs `<img>` with escaped src, alt, and optional title
- `renderLink(lnk, writer)` - Outputs `<a>` with escaped href and optional title
- `renderHorizontalRule(writer)` - Outputs `<hr>`
- `renderLineBreak(writer)` - Outputs `<br>`

#### Helper Functions

```zig
/// Escapes HTML special characters in text content: < > &
pub fn writeEscaped(writer: anytype, text: []const u8) RenderError!void

/// Escapes HTML special characters in attributes: < > & "
pub fn writeEscapedAttribute(writer: anytype, text: []const u8) RenderError!void

/// Convenience function to render a node to an allocated string
pub fn renderToString(node: *const Node, allocator: std.mem.Allocator) RenderError![]u8
```

#### Security Notes

- Text content escapes `<`, `>`, `&` to prevent XSS
- Attribute values additionally escape `"` (quotes)
- All user-provided content (text, alt, src, href, title) is escaped

---

## Worker Mode Implementation

The project supports three operating modes. Worker mode is designed for long-running processes (e.g., web server integration).

### Current Modes

| Mode | Command | Description |
|------|---------|-------------|
| File | `./md2html input.md output.html` | Convert file to file |
| Stdio | `./md2html --stdio` or `./md2html -` | Read stdin, write stdout, exit |
| Worker | `./md2html --worker` | Long-running framed protocol |

### Core Transformation Function

The `markdownToHtml()` function in `main.zig` is the reusable core used by all modes:

```zig
fn markdownToHtml(markdown: []const u8, arena: *std.heap.ArenaAllocator) ![]u8 {
    const allocator = arena.allocator();
    const ast = try parser.parseDocument(markdown, allocator);
    return try html.renderToString(ast, allocator);
}
```

### Framing Protocol (Worker Mode)

Worker mode uses a length-prefixed framing protocol for reliable message boundaries.

#### Request Frame (Client → Worker)
```
<LEN>\n
<LEN bytes of markdown>
```

#### Response Frame (Worker → Client)
```
<LEN>\n
<LEN bytes of html>
```

#### Protocol Rules
- `LEN` is ASCII decimal (e.g., `12345`)
- Newline delimiter is `\n` (byte 10)
- Payload is raw bytes (can contain newlines, tabs, anything)
- Single worker processes one request at a time, sequentially
- **stdout must contain only framed responses** (no logs)
- **stderr is for logs/errors**

### Worker Implementation (`runWorker`)

```zig
fn runWorker(allocator: std.mem.Allocator) !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    var buf_reader = std.io.bufferedReader(stdin);
    var buf_writer = std.io.bufferedWriter(stdout);

    while (true) {
        // 1. Read length line: "LEN\n"
        const len_line = buf_reader.reader().readUntilDelimiterAlloc(
            allocator, '\n', MAX_HEADER_LEN
        ) catch |err| switch (err) {
            error.EndOfStream => return,  // Clean exit on EOF
            else => return err,
        };
        defer allocator.free(len_line);

        const len = try std.fmt.parseInt(usize, len_line, 10);
        if (len > MAX_INPUT_SIZE) return error.InputTooLarge;

        // 2. Read exactly LEN bytes of markdown
        const md = try allocator.alloc(u8, len);
        defer allocator.free(md);
        try buf_reader.reader().readNoEof(md);

        // 3. Convert markdown to HTML (per-request arena)
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const html = try markdownToHtml(md, &arena);

        // 4. Write response frame: "LEN\n" + html
        try buf_writer.writer().print("{d}\n", .{html.len});
        try buf_writer.writer().writeAll(html);
        try buf_writer.flush();
    }
}
```

### Guardrails

| Limit | Value | Purpose |
|-------|-------|---------|
| `MAX_INPUT_SIZE` | 10 MB | Prevent memory exhaustion |
| `MAX_HEADER_LEN` | 32 bytes | Prevent header line attacks |

### Error Policy

**Policy B: Crash-and-respawn** (recommended for simplicity)
- On parse/render error: print to stderr, exit non-zero
- Caller (e.g., web server) detects failure and respawns the worker
- Can upgrade to Policy A (keep-alive with error responses) later if needed

### CLI Argument Handling

```zig
pub fn main() !void {
    // ... allocator setup ...

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        // Print usage
        return;
    }

    if (std.mem.eql(u8, args[1], "--worker")) {
        return runWorker(allocator);
    } else if (std.mem.eql(u8, args[1], "--stdio") or std.mem.eql(u8, args[1], "-")) {
        return convertStdio(allocator);
    } else if (args.len >= 3) {
        return convertFile(args[1], args[2], allocator);
    }
}
```

### Building for Production

#### Quick Build (only for documentation, prefer build.zig)
```bash
zig build-exe -O ReleaseFast -fstrip main.zig -o md2html
```

#### With build.zig (Recommended)

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "md2html",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the markdown parser");
    run_step.dependOn(&run_cmd.step);

    const test_step = b.step("test", "Run unit tests");
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_step.dependOn(&b.addRunArtifact(unit_tests).step);
}
```

Build commands:
```bash
zig build                        # Debug build
zig build -Doptimize=ReleaseFast # Production build
zig build run -- --worker        # Run worker mode
zig build test                   # Run tests
```

### Manual Testing

Before integrating with a web server, test the worker manually:

```bash
# Start worker
./md2html --worker

# In another terminal, send test requests (Node.js example):
node -e "
const { spawn } = require('child_process');
const worker = spawn('./md2html', ['--worker']);

function send(md) {
    worker.stdin.write(md.length + '\n' + md);
}

let buffer = '';
worker.stdout.on('data', (data) => {
    buffer += data.toString();
    // Parse framed response...
    console.log('Response:', buffer);
});

send('# Hello World');
send('**Bold** and *italic*');
"
```

### Memory Management

Each request uses a fresh arena allocator:
- Arena created at start of request
- All AST nodes and strings allocated via arena
- Single `arena.deinit()` cleans up everything
- Prevents heap fragmentation over many requests

### Implementation Checklist

- [x] `markdownToHtml()` extracted and reusable (already done)
- [x] Add `--worker` CLI flag detection
- [x] Implement `runWorker()` with framing loop
- [x] Ensure stdout contains only framed responses
- [x] Use stderr for all logs/errors
- [x] Create `build.zig` for production builds
- [x] Manual testing: verify 10+ sequential requests work
