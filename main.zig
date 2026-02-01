const std = @import("std");
const parser = @import("src/parser.zig");
const html = @import("src/fe-html.zig");
const helper = @import("src/helper.zig");

/// Helper function to convert markdown to HTML using an arena allocator
/// The arena handles cleanup of all AST nodes automatically
fn markdownToHtml(markdown: []const u8, arena: *std.heap.ArenaAllocator) ![]u8 {
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

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const input_path = "examples/input/zig-arrays-and-slices.md";
    const output_dir = "examples/output";

    // Read the markdown file
    const markdown_content = try helper.readMarkdownFile(input_path, arena_allocator);

    // Convert markdown to HTML
    const html_output = try markdownToHtml(markdown_content, &arena);

    // Generate output path
    const output_path = try helper.mdPathToHtmlPath(input_path, output_dir, arena_allocator);

    // Write HTML to output file
    try helper.writeHtmlFile(output_path, html_output);

    std.debug.print("Converted {s} -> {s}\n", .{ input_path, output_path });
}
