const std = @import("std");
const parser = @import("src/parser.zig");
const html = @import("src/fe-html.zig");
const helper = @import("src/helper.zig");

// =============================================================================
// Worker Mode Constants
// =============================================================================

/// Maximum input size for a single request (10 MB)
pub const MAX_INPUT_SIZE: usize = 10 * 1024 * 1024;

/// Maximum length of the header line (length prefix)
pub const MAX_HEADER_LEN: usize = 32;

// =============================================================================
// Worker Mode Errors
// =============================================================================

pub const WorkerError = error{
    InputTooLarge,
    InvalidLengthHeader,
    EndOfStream,
    OutOfMemory,
    WriteFailed,
    ReadFailed,
};

/// Helper function to convert markdown to HTML using an arena allocator
/// The arena handles cleanup of all AST nodes automatically
pub fn markdownToHtml(markdown: []const u8, arena: *std.heap.ArenaAllocator) ![]u8 {
    const allocator = arena.allocator();
    const ast = try parser.parseDocument(markdown, allocator);
    return try html.renderToString(ast, allocator);
}

// =============================================================================
// Integration Tests: Markdown to HTML
// =============================================================================

// -----------------------------------------------------------------------------
// Heading Tests
// -----------------------------------------------------------------------------

test "markdown to html - h1 heading" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("# Hello World", &arena);
    try std.testing.expectEqualStrings("<h1>Hello World</h1>", result);
}

test "markdown to html - h2 heading" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("## Second Level", &arena);
    try std.testing.expectEqualStrings("<h2>Second Level</h2>", result);
}

test "markdown to html - h3 heading" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("### Third Level", &arena);
    try std.testing.expectEqualStrings("<h3>Third Level</h3>", result);
}

test "markdown to html - h6 heading" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("###### Smallest Heading", &arena);
    try std.testing.expectEqualStrings("<h6>Smallest Heading</h6>", result);
}

// -----------------------------------------------------------------------------
// Paragraph Tests
// -----------------------------------------------------------------------------

test "markdown to html - simple paragraph" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("This is a simple paragraph.", &arena);
    try std.testing.expectEqualStrings("<p>This is a simple paragraph.</p>", result);
}

test "markdown to html - paragraph with special chars escaped" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("Use <div> and &amp; carefully.", &arena);
    try std.testing.expectEqualStrings("<p>Use &lt;div&gt; and &amp;amp; carefully.</p>", result);
}

// -----------------------------------------------------------------------------
// Bold and Italic Tests
// -----------------------------------------------------------------------------

test "markdown to html - bold text" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("This is **bold** text.", &arena);
    try std.testing.expectEqualStrings("<p>This is <strong>bold</strong> text.</p>", result);
}

test "markdown to html - italic text" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("This is *italic* text.", &arena);
    try std.testing.expectEqualStrings("<p>This is <em>italic</em> text.</p>", result);
}

test "markdown to html - bold and italic combined" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("**bold** and *italic* together", &arena);
    try std.testing.expectEqualStrings("<p><strong>bold</strong> and <em>italic</em> together</p>", result);
}

test "markdown to html - nested bold and italic" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("**bold with *italic* inside**", &arena);
    try std.testing.expectEqualStrings("<p><strong>bold with <em>italic</em> inside</strong></p>", result);
}

// -----------------------------------------------------------------------------
// Inline Code Tests
// -----------------------------------------------------------------------------

test "markdown to html - inline code" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("Use the `print()` function.", &arena);
    try std.testing.expectEqualStrings("<p>Use the <code>print()</code> function.</p>", result);
}

test "markdown to html - inline code with special chars" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("Use `<div>` element.", &arena);
    try std.testing.expectEqualStrings("<p>Use <code>&lt;div&gt;</code> element.</p>", result);
}

test "markdown to html - double backtick code" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("Use ``code with ` backtick``.", &arena);
    try std.testing.expectEqualStrings("<p>Use <code>code with ` backtick</code>.</p>", result);
}

// -----------------------------------------------------------------------------
// Link Tests
// -----------------------------------------------------------------------------

test "markdown to html - simple link" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("[Click here](https://example.com)", &arena);
    try std.testing.expectEqualStrings("<p><a href=\"https://example.com\">Click here</a></p>", result);
}

test "markdown to html - link with title" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("[Link](https://example.com \"Example Site\")", &arena);
    try std.testing.expectEqualStrings("<p><a href=\"https://example.com\" title=\"Example Site\">Link</a></p>", result);
}

test "markdown to html - link with bold text" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("[**Bold Link**](https://example.com)", &arena);
    try std.testing.expectEqualStrings("<p><a href=\"https://example.com\"><strong>Bold Link</strong></a></p>", result);
}

// -----------------------------------------------------------------------------
// Image Tests
// -----------------------------------------------------------------------------

test "markdown to html - simple image" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("![Alt text](image.png)", &arena);
    try std.testing.expectEqualStrings("<p><img src=\"image.png\" alt=\"Alt text\"></p>", result);
}

test "markdown to html - image with title" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("![Alt](image.jpg \"Image Title\")", &arena);
    try std.testing.expectEqualStrings("<p><img src=\"image.jpg\" alt=\"Alt\" title=\"Image Title\"></p>", result);
}

test "markdown to html - image with empty alt" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("![](decorative.png)", &arena);
    try std.testing.expectEqualStrings("<p><img src=\"decorative.png\" alt=\"\"></p>", result);
}

// -----------------------------------------------------------------------------
// Blockquote Tests
// -----------------------------------------------------------------------------

test "markdown to html - simple blockquote" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("> This is a quote", &arena);
    try std.testing.expectEqualStrings("<blockquote><p>This is a quote\n</p></blockquote>", result);
}

test "markdown to html - multi-line blockquote" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("> Line one\n> Line two", &arena);
    try std.testing.expectEqualStrings("<blockquote><p>Line one\nLine two\n</p></blockquote>", result);
}

// -----------------------------------------------------------------------------
// List Tests
// -----------------------------------------------------------------------------

test "markdown to html - unordered list with dash" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("- Item one\n- Item two", &arena);
    try std.testing.expectEqualStrings("<ul><li><p>Item one</p></li><li><p>Item two</p></li></ul>", result);
}

test "markdown to html - unordered list with asterisk" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("* First\n* Second", &arena);
    try std.testing.expectEqualStrings("<ul><li><p>First</p></li><li><p>Second</p></li></ul>", result);
}

test "markdown to html - ordered list" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("1. First item\n2. Second item", &arena);
    try std.testing.expectEqualStrings("<ol><li><p>First item</p></li><li><p>Second item</p></li></ol>", result);
}

test "markdown to html - single list item" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("- Only one", &arena);
    try std.testing.expectEqualStrings("<ul><li><p>Only one</p></li></ul>", result);
}

// -----------------------------------------------------------------------------
// Code Block Tests
// -----------------------------------------------------------------------------

test "markdown to html - code block with language" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("```zig\nconst x = 1;\n```", &arena);
    try std.testing.expectEqualStrings("<pre><code class=\"language-zig\">const x = 1;\n</code></pre>", result);
}

test "markdown to html - code block without language" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("```\nsome code\n```", &arena);
    try std.testing.expectEqualStrings("<pre><code>some code\n</code></pre>", result);
}

test "markdown to html - code block with html escaping" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("```html\n<div>Hello</div>\n```", &arena);
    try std.testing.expectEqualStrings("<pre><code class=\"language-html\">&lt;div&gt;Hello&lt;/div&gt;\n</code></pre>", result);
}

test "markdown to html - tilde code block" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("~~~python\nprint('hello')\n~~~", &arena);
    try std.testing.expectEqualStrings("<pre><code class=\"language-python\">print('hello')\n</code></pre>", result);
}

// -----------------------------------------------------------------------------
// Horizontal Rule Tests
// -----------------------------------------------------------------------------

test "markdown to html - horizontal rule dashes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("---", &arena);
    try std.testing.expectEqualStrings("<hr>", result);
}

test "markdown to html - horizontal rule asterisks" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("***", &arena);
    try std.testing.expectEqualStrings("<hr>", result);
}

test "markdown to html - horizontal rule underscores" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("___", &arena);
    try std.testing.expectEqualStrings("<hr>", result);
}

test "markdown to html - horizontal rule with spaces" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("- - -", &arena);
    try std.testing.expectEqualStrings("<hr>", result);
}

// -----------------------------------------------------------------------------
// Escape Tests
// -----------------------------------------------------------------------------

test "markdown to html - escaped asterisk" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("This is \\*not italic\\*", &arena);
    try std.testing.expectEqualStrings("<p>This is *not italic*</p>", result);
}

test "markdown to html - escaped bracket" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("\\[not a link\\]", &arena);
    try std.testing.expectEqualStrings("<p>[not a link]</p>", result);
}

// -----------------------------------------------------------------------------
// Multiple Block Tests
// -----------------------------------------------------------------------------

test "markdown to html - heading and paragraph" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("# Title\n\nSome paragraph text.", &arena);
    try std.testing.expectEqualStrings("<h1>Title</h1><p>Some paragraph text.</p>", result);
}

test "markdown to html - multiple paragraphs" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("First paragraph.\n\nSecond paragraph.", &arena);
    try std.testing.expectEqualStrings("<p>First paragraph.</p><p>Second paragraph.</p>", result);
}

test "markdown to html - heading, paragraph, list" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("# Title\n\nIntro text.\n\n- Item 1\n- Item 2", &arena);
    try std.testing.expectEqualStrings("<h1>Title</h1><p>Intro text.</p><ul><li><p>Item 1</p></li><li><p>Item 2</p></li></ul>", result);
}

// -----------------------------------------------------------------------------
// Security Tests (XSS Prevention)
// -----------------------------------------------------------------------------

test "markdown to html - XSS in paragraph" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("<script>alert('XSS')</script>", &arena);
    try std.testing.expectEqualStrings("<p>&lt;script&gt;alert('XSS')&lt;/script&gt;</p>", result);
}

test "markdown to html - XSS in heading" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("# <script>evil()</script>", &arena);
    try std.testing.expectEqualStrings("<h1>&lt;script&gt;evil()&lt;/script&gt;</h1>", result);
}

test "markdown to html - XSS in code block" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("```\n<script>alert(1)</script>\n```", &arena);
    try std.testing.expectEqualStrings("<pre><code>&lt;script&gt;alert(1)&lt;/script&gt;\n</code></pre>", result);
}

// -----------------------------------------------------------------------------
// Edge Cases
// -----------------------------------------------------------------------------

test "markdown to html - empty input" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("", &arena);
    try std.testing.expectEqualStrings("", result);
}

test "markdown to html - only whitespace" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("\n\n\n", &arena);
    try std.testing.expectEqualStrings("", result);
}

test "markdown to html - heading with inline formatting" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try markdownToHtml("# Hello **World**", &arena);
    try std.testing.expectEqualStrings("<h1>Hello <strong>World</strong></h1>", result);
}

test "markdown to html - complex document" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const markdown =
        \\# Welcome
        \\
        \\This is a **bold** statement with *emphasis*.
        \\
        \\## Features
        \\
        \\- Fast parsing
        \\- Safe output
        \\
        \\Check out [our site](https://example.com)!
    ;
    const result = try markdownToHtml(markdown, &arena);

    // The result should contain proper HTML structure
    try std.testing.expect(std.mem.indexOf(u8, result, "<h1>Welcome</h1>") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "<strong>bold</strong>") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "<em>emphasis</em>") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "<h2>Features</h2>") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "<ul>") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "<a href=\"https://example.com\">") != null);
}

/// Converts a markdown file to an HTML file
fn convertFile(input_path: []const u8, output_path: []const u8, allocator: std.mem.Allocator) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    // Read the markdown file
    const markdown_content = try helper.readMarkdownFile(input_path, arena_allocator);

    // Convert markdown to HTML
    const html_output = try markdownToHtml(markdown_content, &arena);

    // Write HTML to output file
    try helper.writeHtmlFile(output_path, html_output);

    std.debug.print("Converted {s} -> {s}\n", .{ input_path, output_path });
}

/// Converts markdown from stdin to HTML on stdout
fn convertStdio(allocator: std.mem.Allocator) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    // Read all input from stdin
    const stdin = std.io.getStdIn();
    const markdown_content = try stdin.readToEndAlloc(arena_allocator, std.math.maxInt(usize));

    // Convert markdown to HTML
    const html_output = try markdownToHtml(markdown_content, &arena);

    // Write HTML to stdout
    const stdout = std.io.getStdOut();
    try stdout.writeAll(html_output);
}

// =============================================================================
// Worker Mode Implementation
// =============================================================================

/// Runs the worker in long-running mode with framed protocol.
/// Protocol:
///   Request:  <LEN>\n<LEN bytes of markdown>
///   Response: <LEN>\n<LEN bytes of html>
///
/// Worker exits cleanly on EOF (stdin closed).
/// On parse/render errors, worker crashes (Policy B: crash-and-respawn).
pub fn runWorker(allocator: std.mem.Allocator) !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var buf_reader = std.io.bufferedReader(stdin);
    var buf_writer = std.io.bufferedWriter(stdout);

    while (true) {
        // Process one request
        processWorkerRequest(allocator, &buf_reader, &buf_writer) catch |err| {
            switch (err) {
                error.EndOfStream => return, // Clean exit on EOF
                else => return err,
            }
        };
    }
}

/// Process a single worker request (read frame, convert, write frame)
fn processWorkerRequest(
    allocator: std.mem.Allocator,
    buf_reader: anytype,
    buf_writer: anytype,
) !void {
    // 1. Read length line: "LEN\n"
    const len_line = buf_reader.reader().readUntilDelimiterAlloc(
        allocator,
        '\n',
        MAX_HEADER_LEN,
    ) catch |err| switch (err) {
        error.EndOfStream => return error.EndOfStream,
        error.StreamTooLong => {
            std.log.err("Header line too long (max {} bytes)", .{MAX_HEADER_LEN});
            return error.InvalidLengthHeader;
        },
        else => return error.ReadFailed,
    };
    defer allocator.free(len_line);

    // Parse the length value
    const len = std.fmt.parseInt(usize, len_line, 10) catch {
        std.log.err("Invalid length header: '{s}'", .{len_line});
        return error.InvalidLengthHeader;
    };

    // Validate input size
    if (len > MAX_INPUT_SIZE) {
        std.log.err("Input too large: {} bytes (max {} bytes)", .{ len, MAX_INPUT_SIZE });
        return error.InputTooLarge;
    }

    // 2. Read exactly LEN bytes of markdown
    const md = allocator.alloc(u8, len) catch return error.OutOfMemory;
    defer allocator.free(md);

    buf_reader.reader().readNoEof(md) catch |err| {
        std.log.err("Failed to read markdown content: {}", .{err});
        return error.ReadFailed;
    };

    // 3. Convert markdown to HTML (per-request arena)
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const html_output = markdownToHtml(md, &arena) catch |err| {
        std.log.err("Conversion failed: {}", .{err});
        return err;
    };

    // 4. Write response frame: "LEN\n" + html
    buf_writer.writer().print("{d}\n", .{html_output.len}) catch return error.WriteFailed;
    buf_writer.writer().writeAll(html_output) catch return error.WriteFailed;
    buf_writer.flush() catch return error.WriteFailed;
}

/// Variant of runWorker that accepts custom readers/writers for testing
pub fn runWorkerWithIO(
    allocator: std.mem.Allocator,
    reader: anytype,
    writer: anytype,
) !void {
    var buf_reader = std.io.bufferedReader(reader);
    var buf_writer = std.io.bufferedWriter(writer);

    while (true) {
        processWorkerRequest(allocator, &buf_reader, &buf_writer) catch |err| {
            switch (err) {
                error.EndOfStream => return,
                else => return err,
            }
        };
    }
}

fn printUsage() void {
    std.debug.print("Usage: md2html <input.md> <output.html>\n", .{});
    std.debug.print("       md2html --stdio\n", .{});
    std.debug.print("       md2html --worker\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("Options:\n", .{});
    std.debug.print("  <input.md> <output.html>  Convert file to file\n", .{});
    std.debug.print("  --stdio, -                Read from stdin, write to stdout\n", .{});
    std.debug.print("  --worker                  Long-running worker mode with framed protocol\n", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse command line arguments
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.skip(); // skip program name

    const first_arg = args.next() orelse {
        printUsage();
        return;
    };

    // Check for worker mode
    if (std.mem.eql(u8, first_arg, "--worker")) {
        try runWorker(allocator);
        return;
    }

    // Check for stdio mode
    if (std.mem.eql(u8, first_arg, "--stdio") or std.mem.eql(u8, first_arg, "-")) {
        try convertStdio(allocator);
        return;
    }

    // File mode: first_arg is input path, need output path
    const input_path = first_arg;
    const output_path = args.next() orelse {
        printUsage();
        return;
    };

    try convertFile(input_path, output_path, allocator);
}

// =============================================================================
// Worker Mode Tests
// =============================================================================

/// Helper to create a framed request: "LEN\nCONTENT"
fn createFramedRequest(allocator: std.mem.Allocator, content: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, "{d}\n{s}", .{ content.len, content });
}

/// Helper to parse a framed response and extract content
fn parseFramedResponse(response: []const u8) !struct { len: usize, content: []const u8 } {
    // Find the newline delimiter
    const newline_pos = std.mem.indexOf(u8, response, "\n") orelse return error.InvalidResponse;
    const len_str = response[0..newline_pos];
    const len = try std.fmt.parseInt(usize, len_str, 10);
    const content_start = newline_pos + 1;
    if (content_start + len > response.len) return error.IncompleteResponse;
    return .{ .len = len, .content = response[content_start .. content_start + len] };
}

// -----------------------------------------------------------------------------
// Worker Protocol Tests - Basic Functionality
// -----------------------------------------------------------------------------

test "worker - single request converts heading" {
    const allocator = std.testing.allocator;

    // Create input: "13\n# Hello World"
    const input = try createFramedRequest(allocator, "# Hello World");
    defer allocator.free(input);

    var input_stream = std.io.fixedBufferStream(input);
    var output_buf: [1024]u8 = undefined;
    var output_stream = std.io.fixedBufferStream(&output_buf);

    try runWorkerWithIO(allocator, input_stream.reader(), output_stream.writer());

    const response = output_stream.getWritten();
    const parsed = try parseFramedResponse(response);
    try std.testing.expectEqualStrings("<h1>Hello World</h1>", parsed.content);
}

test "worker - single request converts paragraph" {
    const allocator = std.testing.allocator;

    const input = try createFramedRequest(allocator, "Hello world");
    defer allocator.free(input);

    var input_stream = std.io.fixedBufferStream(input);
    var output_buf: [1024]u8 = undefined;
    var output_stream = std.io.fixedBufferStream(&output_buf);

    try runWorkerWithIO(allocator, input_stream.reader(), output_stream.writer());

    const response = output_stream.getWritten();
    const parsed = try parseFramedResponse(response);
    try std.testing.expectEqualStrings("<p>Hello world</p>", parsed.content);
}

test "worker - multiple sequential requests" {
    const allocator = std.testing.allocator;

    // Create two sequential requests
    const req1 = try createFramedRequest(allocator, "# First");
    defer allocator.free(req1);
    const req2 = try createFramedRequest(allocator, "# Second");
    defer allocator.free(req2);

    // Concatenate requests
    const combined = try std.fmt.allocPrint(allocator, "{s}{s}", .{ req1, req2 });
    defer allocator.free(combined);

    var input_stream = std.io.fixedBufferStream(combined);
    var output_buf: [2048]u8 = undefined;
    var output_stream = std.io.fixedBufferStream(&output_buf);

    try runWorkerWithIO(allocator, input_stream.reader(), output_stream.writer());

    const response = output_stream.getWritten();

    // Parse first response
    const parsed1 = try parseFramedResponse(response);
    try std.testing.expectEqualStrings("<h1>First</h1>", parsed1.content);

    // Parse second response (starts after first response)
    const remaining = response[parsed1.len + std.fmt.count("{d}\n", .{parsed1.len}) ..];
    const parsed2 = try parseFramedResponse(remaining);
    try std.testing.expectEqualStrings("<h1>Second</h1>", parsed2.content);
}

test "worker - five sequential requests" {
    const allocator = std.testing.allocator;

    var combined = std.ArrayList(u8).init(allocator);
    defer combined.deinit();

    // Create 5 requests
    const inputs = [_][]const u8{
        "# One",
        "## Two",
        "### Three",
        "**Bold**",
        "*Italic*",
    };

    for (inputs) |content| {
        const req = try createFramedRequest(allocator, content);
        defer allocator.free(req);
        try combined.appendSlice(req);
    }

    var input_stream = std.io.fixedBufferStream(combined.items);
    var output_buf: [4096]u8 = undefined;
    var output_stream = std.io.fixedBufferStream(&output_buf);

    try runWorkerWithIO(allocator, input_stream.reader(), output_stream.writer());

    // Verify output is non-empty (detailed parsing could be added)
    const response = output_stream.getWritten();
    try std.testing.expect(response.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, response, "<h1>One</h1>") != null);
}

// -----------------------------------------------------------------------------
// Worker Protocol Tests - Edge Cases
// -----------------------------------------------------------------------------

test "worker - empty markdown input" {
    const allocator = std.testing.allocator;

    const input = try createFramedRequest(allocator, "");
    defer allocator.free(input);

    var input_stream = std.io.fixedBufferStream(input);
    var output_buf: [1024]u8 = undefined;
    var output_stream = std.io.fixedBufferStream(&output_buf);

    try runWorkerWithIO(allocator, input_stream.reader(), output_stream.writer());

    const response = output_stream.getWritten();
    const parsed = try parseFramedResponse(response);
    try std.testing.expectEqualStrings("", parsed.content);
}

test "worker - whitespace only input" {
    const allocator = std.testing.allocator;

    const input = try createFramedRequest(allocator, "   \n\n   ");
    defer allocator.free(input);

    var input_stream = std.io.fixedBufferStream(input);
    var output_buf: [1024]u8 = undefined;
    var output_stream = std.io.fixedBufferStream(&output_buf);

    try runWorkerWithIO(allocator, input_stream.reader(), output_stream.writer());

    const response = output_stream.getWritten();
    const parsed = try parseFramedResponse(response);
    // Whitespace-only input creates paragraph elements with the whitespace
    try std.testing.expect(parsed.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, parsed.content, "<p>") != null);
}

test "worker - markdown with newlines in content" {
    const allocator = std.testing.allocator;

    const md = "# Title\n\nParagraph one.\n\nParagraph two.";
    const input = try createFramedRequest(allocator, md);
    defer allocator.free(input);

    var input_stream = std.io.fixedBufferStream(input);
    var output_buf: [2048]u8 = undefined;
    var output_stream = std.io.fixedBufferStream(&output_buf);

    try runWorkerWithIO(allocator, input_stream.reader(), output_stream.writer());

    const response = output_stream.getWritten();
    const parsed = try parseFramedResponse(response);
    try std.testing.expect(std.mem.indexOf(u8, parsed.content, "<h1>Title</h1>") != null);
    try std.testing.expect(std.mem.indexOf(u8, parsed.content, "<p>Paragraph one.</p>") != null);
}

test "worker - unicode content" {
    const allocator = std.testing.allocator;

    const input = try createFramedRequest(allocator, "# Hello 世界 🌍");
    defer allocator.free(input);

    var input_stream = std.io.fixedBufferStream(input);
    var output_buf: [1024]u8 = undefined;
    var output_stream = std.io.fixedBufferStream(&output_buf);

    try runWorkerWithIO(allocator, input_stream.reader(), output_stream.writer());

    const response = output_stream.getWritten();
    const parsed = try parseFramedResponse(response);
    try std.testing.expect(std.mem.indexOf(u8, parsed.content, "Hello 世界 🌍") != null);
}

test "worker - XSS prevention in content" {
    const allocator = std.testing.allocator;

    const input = try createFramedRequest(allocator, "<script>alert('xss')</script>");
    defer allocator.free(input);

    var input_stream = std.io.fixedBufferStream(input);
    var output_buf: [1024]u8 = undefined;
    var output_stream = std.io.fixedBufferStream(&output_buf);

    try runWorkerWithIO(allocator, input_stream.reader(), output_stream.writer());

    const response = output_stream.getWritten();
    const parsed = try parseFramedResponse(response);
    // HTML should be escaped
    try std.testing.expect(std.mem.indexOf(u8, parsed.content, "&lt;script&gt;") != null);
    try std.testing.expect(std.mem.indexOf(u8, parsed.content, "<script>") == null);
}

// -----------------------------------------------------------------------------
// Worker Protocol Tests - Complex Markdown
// -----------------------------------------------------------------------------

test "worker - code block with language" {
    const allocator = std.testing.allocator;

    const md = "```zig\nconst x = 1;\n```";
    const input = try createFramedRequest(allocator, md);
    defer allocator.free(input);

    var input_stream = std.io.fixedBufferStream(input);
    var output_buf: [1024]u8 = undefined;
    var output_stream = std.io.fixedBufferStream(&output_buf);

    try runWorkerWithIO(allocator, input_stream.reader(), output_stream.writer());

    const response = output_stream.getWritten();
    const parsed = try parseFramedResponse(response);
    try std.testing.expect(std.mem.indexOf(u8, parsed.content, "language-zig") != null);
}

test "worker - list items" {
    const allocator = std.testing.allocator;

    const md = "- Item 1\n- Item 2\n- Item 3";
    const input = try createFramedRequest(allocator, md);
    defer allocator.free(input);

    var input_stream = std.io.fixedBufferStream(input);
    var output_buf: [2048]u8 = undefined;
    var output_stream = std.io.fixedBufferStream(&output_buf);

    try runWorkerWithIO(allocator, input_stream.reader(), output_stream.writer());

    const response = output_stream.getWritten();
    const parsed = try parseFramedResponse(response);
    try std.testing.expect(std.mem.indexOf(u8, parsed.content, "<ul>") != null);
    try std.testing.expect(std.mem.indexOf(u8, parsed.content, "<li>") != null);
}

test "worker - links with special characters" {
    const allocator = std.testing.allocator;

    const md = "[Link](https://example.com?a=1&b=2)";
    const input = try createFramedRequest(allocator, md);
    defer allocator.free(input);

    var input_stream = std.io.fixedBufferStream(input);
    var output_buf: [1024]u8 = undefined;
    var output_stream = std.io.fixedBufferStream(&output_buf);

    try runWorkerWithIO(allocator, input_stream.reader(), output_stream.writer());

    const response = output_stream.getWritten();
    const parsed = try parseFramedResponse(response);
    // Ampersand should be escaped in href
    try std.testing.expect(std.mem.indexOf(u8, parsed.content, "&amp;") != null);
}

// -----------------------------------------------------------------------------
// Worker Protocol Tests - Error Conditions (Expected to Fail)
// -----------------------------------------------------------------------------

test "worker - graceful EOF handling" {
    const allocator = std.testing.allocator;

    // Empty input should cause clean EOF exit
    const input = "";
    var input_stream = std.io.fixedBufferStream(input);
    var output_buf: [1024]u8 = undefined;
    var output_stream = std.io.fixedBufferStream(&output_buf);

    // Should not error, just return cleanly
    try runWorkerWithIO(allocator, input_stream.reader(), output_stream.writer());

    // No output expected
    try std.testing.expectEqual(@as(usize, 0), output_stream.getWritten().len);
}

// -----------------------------------------------------------------------------
// Worker Constants Tests
// -----------------------------------------------------------------------------

test "MAX_INPUT_SIZE is 10MB" {
    try std.testing.expectEqual(@as(usize, 10 * 1024 * 1024), MAX_INPUT_SIZE);
}

test "MAX_HEADER_LEN is 32 bytes" {
    try std.testing.expectEqual(@as(usize, 32), MAX_HEADER_LEN);
}

// -----------------------------------------------------------------------------
// Worker Protocol Tests - Large Input
// -----------------------------------------------------------------------------

test "worker - moderately large input" {
    const allocator = std.testing.allocator;

    // Create a 10KB markdown document
    var content = std.ArrayList(u8).init(allocator);
    defer content.deinit();

    try content.appendSlice("# Large Document\n\n");
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        try content.writer().print("This is paragraph number {d}. It contains some text.\n\n", .{i});
    }

    const input = try createFramedRequest(allocator, content.items);
    defer allocator.free(input);

    var input_stream = std.io.fixedBufferStream(input);
    var output_buf: [64 * 1024]u8 = undefined; // 64KB buffer
    var output_stream = std.io.fixedBufferStream(&output_buf);

    try runWorkerWithIO(allocator, input_stream.reader(), output_stream.writer());

    const response = output_stream.getWritten();
    const parsed = try parseFramedResponse(response);
    try std.testing.expect(std.mem.indexOf(u8, parsed.content, "<h1>Large Document</h1>") != null);
    try std.testing.expect(parsed.len > 1000); // Should have substantial output
}

// -----------------------------------------------------------------------------
// Worker Protocol Tests - Response Frame Format
// -----------------------------------------------------------------------------

test "worker - response frame format is correct" {
    const allocator = std.testing.allocator;

    const input = try createFramedRequest(allocator, "Hi");
    defer allocator.free(input);

    var input_stream = std.io.fixedBufferStream(input);
    var output_buf: [1024]u8 = undefined;
    var output_stream = std.io.fixedBufferStream(&output_buf);

    try runWorkerWithIO(allocator, input_stream.reader(), output_stream.writer());

    const response = output_stream.getWritten();

    // Response should start with a number followed by newline
    const newline_pos = std.mem.indexOf(u8, response, "\n") orelse unreachable;
    const len_str = response[0..newline_pos];

    // Length should be parseable
    const len = try std.fmt.parseInt(usize, len_str, 10);

    // Content length should match declared length
    const content = response[newline_pos + 1 ..];
    try std.testing.expectEqual(len, content.len);
}

test "worker - response contains valid HTML" {
    const allocator = std.testing.allocator;

    const input = try createFramedRequest(allocator, "**Bold** and *italic*");
    defer allocator.free(input);

    var input_stream = std.io.fixedBufferStream(input);
    var output_buf: [1024]u8 = undefined;
    var output_stream = std.io.fixedBufferStream(&output_buf);

    try runWorkerWithIO(allocator, input_stream.reader(), output_stream.writer());

    const response = output_stream.getWritten();
    const parsed = try parseFramedResponse(response);

    // Should have proper HTML structure
    try std.testing.expect(std.mem.indexOf(u8, parsed.content, "<p>") != null);
    try std.testing.expect(std.mem.indexOf(u8, parsed.content, "</p>") != null);
    try std.testing.expect(std.mem.indexOf(u8, parsed.content, "<strong>") != null);
    try std.testing.expect(std.mem.indexOf(u8, parsed.content, "<em>") != null);
}
