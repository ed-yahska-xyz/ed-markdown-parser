const std = @import("std");
const models = @import("models.zig");

const Node = models.Node;
const Document = models.Document;
const Heading = models.Heading;
const Paragraph = models.Paragraph;
const Text = models.Text;
const Blockquote = models.Blockquote;
const List = models.List;
const ListItem = models.ListItem;
const Code = models.Code;
const CodeBlock = models.CodeBlock;
const InlineBold = models.InlineBold;
const InlineItalics = models.InlineItalics;
const Image = models.Image;
const Link = models.Link;
const HorizontalRule = models.HorizontalRule;

pub const RenderError = error{
    WriteFailed,
    OutOfMemory,
};

/// Main entry point: renders a Node to HTML
pub fn renderHtml(node: *const Node, writer: anytype) RenderError!void {
    switch (node.*) {
        .document => |doc| try renderDocument(doc, writer),
        .heading => |h| try renderHeading(h, writer),
        .paragraph => |p| try renderParagraph(p, writer),
        .text => |t| try renderText(t, writer),
        .blockquote => |bq| try renderBlockquote(bq, writer),
        .list => |l| try renderList(l, writer),
        .list_item => |li| try renderListItem(li, writer),
        .code => |c| try renderCode(c, writer),
        .code_block => |cb| try renderCodeBlock(cb, writer),
        .inline_bold => |b| try renderInlineBold(b, writer),
        .inline_italics => |i| try renderInlineItalics(i, writer),
        .image => |img| try renderImage(img, writer),
        .link => |lnk| try renderLink(lnk, writer),
        .horizontal_rule => try renderHorizontalRule(writer),
        .line_break => try renderLineBreak(writer),
    }
}

/// Renders a Document node
fn renderDocument(doc: Document, writer: anytype) RenderError!void {
    for (doc.children) |child| {
        try renderHtml(child, writer);
    }
}

/// Renders a Heading node (h1-h6)
fn renderHeading(h: Heading, writer: anytype) RenderError!void {
    writer.print("<h{d}>", .{h.level}) catch return RenderError.WriteFailed;
    for (h.children) |child| {
        try renderHtml(child, writer);
    }
    writer.print("</h{d}>", .{h.level}) catch return RenderError.WriteFailed;
}

/// Renders a Paragraph node
fn renderParagraph(p: Paragraph, writer: anytype) RenderError!void {
    writer.writeAll("<p>") catch return RenderError.WriteFailed;
    for (p.children) |child| {
        try renderHtml(child, writer);
    }
    writer.writeAll("</p>") catch return RenderError.WriteFailed;
}

/// Renders a Text node with HTML escaping
fn renderText(t: Text, writer: anytype) RenderError!void {
    try writeEscaped(writer, t.value);
}

/// Renders a Blockquote node
fn renderBlockquote(bq: Blockquote, writer: anytype) RenderError!void {
    writer.writeAll("<blockquote>") catch return RenderError.WriteFailed;
    for (bq.children) |child| {
        try renderHtml(child, writer);
    }
    writer.writeAll("</blockquote>") catch return RenderError.WriteFailed;
}

/// Renders a List node (ordered or unordered)
fn renderList(l: List, writer: anytype) RenderError!void {
    const tag = if (l.ordered) "ol" else "ul";
    writer.print("<{s}>", .{tag}) catch return RenderError.WriteFailed;
    for (l.children) |child| {
        try renderHtml(child, writer);
    }
    writer.print("</{s}>", .{tag}) catch return RenderError.WriteFailed;
}

/// Renders a ListItem node
fn renderListItem(li: ListItem, writer: anytype) RenderError!void {
    writer.writeAll("<li>") catch return RenderError.WriteFailed;
    for (li.children) |child| {
        try renderHtml(child, writer);
    }
    writer.writeAll("</li>") catch return RenderError.WriteFailed;
}

/// Renders inline Code node
fn renderCode(c: Code, writer: anytype) RenderError!void {
    writer.writeAll("<code>") catch return RenderError.WriteFailed;
    try writeEscaped(writer, c.value);
    writer.writeAll("</code>") catch return RenderError.WriteFailed;
}

/// Renders a CodeBlock node with optional language class
fn renderCodeBlock(cb: CodeBlock, writer: anytype) RenderError!void {
    if (cb.language) |lang| {
        writer.print("<pre><code class=\"language-{s}\">", .{lang}) catch return RenderError.WriteFailed;
    } else {
        writer.writeAll("<pre><code>") catch return RenderError.WriteFailed;
    }
    try writeEscaped(writer, cb.value);
    writer.writeAll("</code></pre>") catch return RenderError.WriteFailed;
}

/// Renders InlineBold node
fn renderInlineBold(b: InlineBold, writer: anytype) RenderError!void {
    writer.writeAll("<strong>") catch return RenderError.WriteFailed;
    for (b.children) |child| {
        try renderHtml(child, writer);
    }
    writer.writeAll("</strong>") catch return RenderError.WriteFailed;
}

/// Renders InlineItalics node
fn renderInlineItalics(i: InlineItalics, writer: anytype) RenderError!void {
    writer.writeAll("<em>") catch return RenderError.WriteFailed;
    for (i.children) |child| {
        try renderHtml(child, writer);
    }
    writer.writeAll("</em>") catch return RenderError.WriteFailed;
}

/// Renders an Image node
fn renderImage(img: Image, writer: anytype) RenderError!void {
    writer.writeAll("<img src=\"") catch return RenderError.WriteFailed;
    try writeEscapedAttribute(writer, img.src);
    writer.writeAll("\" alt=\"") catch return RenderError.WriteFailed;
    try writeEscapedAttribute(writer, img.alt);
    writer.writeAll("\"") catch return RenderError.WriteFailed;
    if (img.title) |title| {
        writer.writeAll(" title=\"") catch return RenderError.WriteFailed;
        try writeEscapedAttribute(writer, title);
        writer.writeAll("\"") catch return RenderError.WriteFailed;
    }
    writer.writeAll(">") catch return RenderError.WriteFailed;
}

/// Renders a Link node
fn renderLink(lnk: Link, writer: anytype) RenderError!void {
    writer.writeAll("<a href=\"") catch return RenderError.WriteFailed;
    try writeEscapedAttribute(writer, lnk.href);
    writer.writeAll("\"") catch return RenderError.WriteFailed;
    if (lnk.title) |title| {
        writer.writeAll(" title=\"") catch return RenderError.WriteFailed;
        try writeEscapedAttribute(writer, title);
        writer.writeAll("\"") catch return RenderError.WriteFailed;
    }
    writer.writeAll(">") catch return RenderError.WriteFailed;
    for (lnk.children) |child| {
        try renderHtml(child, writer);
    }
    writer.writeAll("</a>") catch return RenderError.WriteFailed;
}

/// Renders a HorizontalRule node
fn renderHorizontalRule(writer: anytype) RenderError!void {
    writer.writeAll("<hr>") catch return RenderError.WriteFailed;
}

/// Renders a LineBreak node
fn renderLineBreak(writer: anytype) RenderError!void {
    writer.writeAll("<br>") catch return RenderError.WriteFailed;
}

/// Escapes HTML special characters in text content
pub fn writeEscaped(writer: anytype, text: []const u8) RenderError!void {
    for (text) |c| {
        switch (c) {
            '<' => writer.writeAll("&lt;") catch return RenderError.WriteFailed,
            '>' => writer.writeAll("&gt;") catch return RenderError.WriteFailed,
            '&' => writer.writeAll("&amp;") catch return RenderError.WriteFailed,
            else => writer.writeByte(c) catch return RenderError.WriteFailed,
        }
    }
}

/// Escapes HTML special characters in attribute values (includes quotes)
pub fn writeEscapedAttribute(writer: anytype, text: []const u8) RenderError!void {
    for (text) |c| {
        switch (c) {
            '<' => writer.writeAll("&lt;") catch return RenderError.WriteFailed,
            '>' => writer.writeAll("&gt;") catch return RenderError.WriteFailed,
            '&' => writer.writeAll("&amp;") catch return RenderError.WriteFailed,
            '"' => writer.writeAll("&quot;") catch return RenderError.WriteFailed,
            else => writer.writeByte(c) catch return RenderError.WriteFailed,
        }
    }
}

/// Convenience function to render a node to a string
pub fn renderToString(node: *const Node, allocator: std.mem.Allocator) RenderError![]u8 {
    var list = std.ArrayList(u8).init(allocator);
    errdefer list.deinit();
    try renderHtml(node, list.writer());
    return list.toOwnedSlice() catch return RenderError.OutOfMemory;
}

// =============================================================================
// Tests
// =============================================================================

// -----------------------------------------------------------------------------
// renderDocument tests
// -----------------------------------------------------------------------------

test "renderDocument - empty document" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var node = Node{ .document = .{ .children = &[_]*Node{} } };
    try renderHtml(&node, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("", result);
}

test "renderDocument - single paragraph child" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var text_node = Node{ .text = .{ .value = "Hello" } };
    const text_ptr: *Node = &text_node;
    var para_node = Node{ .paragraph = .{ .children = @as([]const *Node, &[_]*Node{text_ptr}) } };
    const para_ptr: *Node = &para_node;
    var doc_node = Node{ .document = .{ .children = @as([]const *Node, &[_]*Node{para_ptr}) } };

    try renderHtml(&doc_node, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<p>Hello</p>", result);
}

test "renderDocument - multiple children" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var text1 = Node{ .text = .{ .value = "First" } };
    const text1_ptr: *Node = &text1;
    var para1 = Node{ .paragraph = .{ .children = @as([]const *Node, &[_]*Node{text1_ptr}) } };
    const para1_ptr: *Node = &para1;

    var text2 = Node{ .text = .{ .value = "Second" } };
    const text2_ptr: *Node = &text2;
    var para2 = Node{ .paragraph = .{ .children = @as([]const *Node, &[_]*Node{text2_ptr}) } };
    const para2_ptr: *Node = &para2;

    var doc_node = Node{ .document = .{ .children = @as([]const *Node, &[_]*Node{ para1_ptr, para2_ptr }) } };

    try renderHtml(&doc_node, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<p>First</p><p>Second</p>", result);
}

// -----------------------------------------------------------------------------
// renderHeading tests
// -----------------------------------------------------------------------------

test "renderHeading - level 1" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var text_node = Node{ .text = .{ .value = "Title" } };
    const text_ptr: *Node = &text_node;
    var heading = Node{ .heading = .{ .level = 1, .children = @as([]const *Node, &[_]*Node{text_ptr}) } };

    try renderHtml(&heading, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<h1>Title</h1>", result);
}

test "renderHeading - level 6" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var text_node = Node{ .text = .{ .value = "Small" } };
    const text_ptr: *Node = &text_node;
    var heading = Node{ .heading = .{ .level = 6, .children = @as([]const *Node, &[_]*Node{text_ptr}) } };

    try renderHtml(&heading, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<h6>Small</h6>", result);
}

test "renderHeading - empty heading" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var heading = Node{ .heading = .{ .level = 2, .children = &[_]*Node{} } };

    try renderHtml(&heading, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<h2></h2>", result);
}

test "renderHeading - with nested bold" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var text_inner = Node{ .text = .{ .value = "bold" } };
    const text_inner_ptr: *Node = &text_inner;
    var bold = Node{ .inline_bold = .{ .children = @as([]const *Node, &[_]*Node{text_inner_ptr}) } };
    const bold_ptr: *Node = &bold;
    var heading = Node{ .heading = .{ .level = 1, .children = @as([]const *Node, &[_]*Node{bold_ptr}) } };

    try renderHtml(&heading, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<h1><strong>bold</strong></h1>", result);
}

// -----------------------------------------------------------------------------
// renderParagraph tests
// -----------------------------------------------------------------------------

test "renderParagraph - simple text" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var text_node = Node{ .text = .{ .value = "Hello world" } };
    const text_ptr: *Node = &text_node;
    var para = Node{ .paragraph = .{ .children = @as([]const *Node, &[_]*Node{text_ptr}) } };

    try renderHtml(&para, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<p>Hello world</p>", result);
}

test "renderParagraph - empty paragraph" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var para = Node{ .paragraph = .{ .children = &[_]*Node{} } };

    try renderHtml(&para, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<p></p>", result);
}

test "renderParagraph - with inline formatting" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var text1 = Node{ .text = .{ .value = "Normal " } };
    const text1_ptr: *Node = &text1;
    var bold_text = Node{ .text = .{ .value = "bold" } };
    const bold_text_ptr: *Node = &bold_text;
    var bold = Node{ .inline_bold = .{ .children = @as([]const *Node, &[_]*Node{bold_text_ptr}) } };
    const bold_ptr: *Node = &bold;
    var text2 = Node{ .text = .{ .value = " text" } };
    const text2_ptr: *Node = &text2;
    var para = Node{ .paragraph = .{ .children = @as([]const *Node, &[_]*Node{ text1_ptr, bold_ptr, text2_ptr }) } };

    try renderHtml(&para, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<p>Normal <strong>bold</strong> text</p>", result);
}

// -----------------------------------------------------------------------------
// renderText tests
// -----------------------------------------------------------------------------

test "renderText - plain text" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var text = Node{ .text = .{ .value = "Hello world" } };

    try renderHtml(&text, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("Hello world", result);
}

test "renderText - empty text" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var text = Node{ .text = .{ .value = "" } };

    try renderHtml(&text, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("", result);
}

test "renderText - escapes less than" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var text = Node{ .text = .{ .value = "a < b" } };

    try renderHtml(&text, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("a &lt; b", result);
}

test "renderText - escapes greater than" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var text = Node{ .text = .{ .value = "a > b" } };

    try renderHtml(&text, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("a &gt; b", result);
}

test "renderText - escapes ampersand" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var text = Node{ .text = .{ .value = "a & b" } };

    try renderHtml(&text, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("a &amp; b", result);
}

test "renderText - escapes multiple special chars" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var text = Node{ .text = .{ .value = "<script>alert('xss')</script>" } };

    try renderHtml(&text, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("&lt;script&gt;alert('xss')&lt;/script&gt;", result);
}

test "renderText - preserves quotes in text content" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var text = Node{ .text = .{ .value = "He said \"hello\"" } };

    try renderHtml(&text, writer);

    const result = stream.getWritten();
    // Quotes are NOT escaped in text content, only in attributes
    try std.testing.expectEqualStrings("He said \"hello\"", result);
}

// -----------------------------------------------------------------------------
// renderBlockquote tests
// -----------------------------------------------------------------------------

test "renderBlockquote - simple blockquote" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var text = Node{ .text = .{ .value = "Quote" } };
    const text_ptr: *Node = &text;
    var para = Node{ .paragraph = .{ .children = @as([]const *Node, &[_]*Node{text_ptr}) } };
    const para_ptr: *Node = &para;
    var bq = Node{ .blockquote = .{ .children = @as([]const *Node, &[_]*Node{para_ptr}) } };

    try renderHtml(&bq, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<blockquote><p>Quote</p></blockquote>", result);
}

test "renderBlockquote - empty blockquote" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var bq = Node{ .blockquote = .{ .children = &[_]*Node{} } };

    try renderHtml(&bq, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<blockquote></blockquote>", result);
}

test "renderBlockquote - nested blockquote" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var text = Node{ .text = .{ .value = "Nested" } };
    const text_ptr: *Node = &text;
    var para = Node{ .paragraph = .{ .children = @as([]const *Node, &[_]*Node{text_ptr}) } };
    const para_ptr: *Node = &para;
    var inner_bq = Node{ .blockquote = .{ .children = @as([]const *Node, &[_]*Node{para_ptr}) } };
    const inner_bq_ptr: *Node = &inner_bq;
    var outer_bq = Node{ .blockquote = .{ .children = @as([]const *Node, &[_]*Node{inner_bq_ptr}) } };

    try renderHtml(&outer_bq, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<blockquote><blockquote><p>Nested</p></blockquote></blockquote>", result);
}

// -----------------------------------------------------------------------------
// renderList tests
// -----------------------------------------------------------------------------

test "renderList - unordered list" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var text = Node{ .text = .{ .value = "Item" } };
    const text_ptr: *Node = &text;
    var para = Node{ .paragraph = .{ .children = @as([]const *Node, &[_]*Node{text_ptr}) } };
    const para_ptr: *Node = &para;
    var li = Node{ .list_item = .{ .children = @as([]const *Node, &[_]*Node{para_ptr}) } };
    const li_ptr: *Node = &li;
    var list = Node{ .list = .{ .ordered = false, .marker = '-', .children = @as([]const *Node, &[_]*Node{li_ptr}) } };

    try renderHtml(&list, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<ul><li><p>Item</p></li></ul>", result);
}

test "renderList - ordered list" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var text = Node{ .text = .{ .value = "First" } };
    const text_ptr: *Node = &text;
    var para = Node{ .paragraph = .{ .children = @as([]const *Node, &[_]*Node{text_ptr}) } };
    const para_ptr: *Node = &para;
    var li = Node{ .list_item = .{ .children = @as([]const *Node, &[_]*Node{para_ptr}) } };
    const li_ptr: *Node = &li;
    var list = Node{ .list = .{ .ordered = true, .marker = '1', .children = @as([]const *Node, &[_]*Node{li_ptr}) } };

    try renderHtml(&list, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<ol><li><p>First</p></li></ol>", result);
}

test "renderList - empty list" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var list = Node{ .list = .{ .ordered = false, .marker = '-', .children = &[_]*Node{} } };

    try renderHtml(&list, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<ul></ul>", result);
}

test "renderList - multiple items" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var text1 = Node{ .text = .{ .value = "One" } };
    const text1_ptr: *Node = &text1;
    var para1 = Node{ .paragraph = .{ .children = @as([]const *Node, &[_]*Node{text1_ptr}) } };
    const para1_ptr: *Node = &para1;
    var li1 = Node{ .list_item = .{ .children = @as([]const *Node, &[_]*Node{para1_ptr}) } };
    const li1_ptr: *Node = &li1;

    var text2 = Node{ .text = .{ .value = "Two" } };
    const text2_ptr: *Node = &text2;
    var para2 = Node{ .paragraph = .{ .children = @as([]const *Node, &[_]*Node{text2_ptr}) } };
    const para2_ptr: *Node = &para2;
    var li2 = Node{ .list_item = .{ .children = @as([]const *Node, &[_]*Node{para2_ptr}) } };
    const li2_ptr: *Node = &li2;

    var list = Node{ .list = .{ .ordered = false, .marker = '-', .children = @as([]const *Node, &[_]*Node{ li1_ptr, li2_ptr }) } };

    try renderHtml(&list, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<ul><li><p>One</p></li><li><p>Two</p></li></ul>", result);
}

// -----------------------------------------------------------------------------
// renderListItem tests
// -----------------------------------------------------------------------------

test "renderListItem - simple item" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var text = Node{ .text = .{ .value = "Item content" } };
    const text_ptr: *Node = &text;
    var para = Node{ .paragraph = .{ .children = @as([]const *Node, &[_]*Node{text_ptr}) } };
    const para_ptr: *Node = &para;
    var li = Node{ .list_item = .{ .children = @as([]const *Node, &[_]*Node{para_ptr}) } };

    try renderHtml(&li, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<li><p>Item content</p></li>", result);
}

test "renderListItem - empty item" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var li = Node{ .list_item = .{ .children = &[_]*Node{} } };

    try renderHtml(&li, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<li></li>", result);
}

// -----------------------------------------------------------------------------
// renderCode tests
// -----------------------------------------------------------------------------

test "renderCode - simple code" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var code = Node{ .code = .{ .value = "const x = 1" } };

    try renderHtml(&code, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<code>const x = 1</code>", result);
}

test "renderCode - empty code" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var code = Node{ .code = .{ .value = "" } };

    try renderHtml(&code, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<code></code>", result);
}

test "renderCode - escapes HTML in code" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var code = Node{ .code = .{ .value = "<div>test</div>" } };

    try renderHtml(&code, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<code>&lt;div&gt;test&lt;/div&gt;</code>", result);
}

// -----------------------------------------------------------------------------
// renderCodeBlock tests
// -----------------------------------------------------------------------------

test "renderCodeBlock - with language" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var cb = Node{ .code_block = .{ .language = "zig", .value = "const x = 1;" } };

    try renderHtml(&cb, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<pre><code class=\"language-zig\">const x = 1;</code></pre>", result);
}

test "renderCodeBlock - without language" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var cb = Node{ .code_block = .{ .language = null, .value = "some code" } };

    try renderHtml(&cb, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<pre><code>some code</code></pre>", result);
}

test "renderCodeBlock - empty code block" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var cb = Node{ .code_block = .{ .language = null, .value = "" } };

    try renderHtml(&cb, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<pre><code></code></pre>", result);
}

test "renderCodeBlock - escapes HTML in code block" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var cb = Node{ .code_block = .{ .language = "html", .value = "<p>Hello</p>" } };

    try renderHtml(&cb, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<pre><code class=\"language-html\">&lt;p&gt;Hello&lt;/p&gt;</code></pre>", result);
}

test "renderCodeBlock - multiline code" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var cb = Node{ .code_block = .{ .language = "python", .value = "def hello():\n    print('hi')" } };

    try renderHtml(&cb, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<pre><code class=\"language-python\">def hello():\n    print('hi')</code></pre>", result);
}

// -----------------------------------------------------------------------------
// renderInlineBold tests
// -----------------------------------------------------------------------------

test "renderInlineBold - simple bold" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var text = Node{ .text = .{ .value = "bold" } };
    const text_ptr: *Node = &text;
    var bold = Node{ .inline_bold = .{ .children = @as([]const *Node, &[_]*Node{text_ptr}) } };

    try renderHtml(&bold, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<strong>bold</strong>", result);
}

test "renderInlineBold - empty bold" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var bold = Node{ .inline_bold = .{ .children = &[_]*Node{} } };

    try renderHtml(&bold, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<strong></strong>", result);
}

test "renderInlineBold - nested italic inside bold" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var text_inner = Node{ .text = .{ .value = "both" } };
    const text_inner_ptr: *Node = &text_inner;
    var italic = Node{ .inline_italics = .{ .children = @as([]const *Node, &[_]*Node{text_inner_ptr}) } };
    const italic_ptr: *Node = &italic;
    var bold = Node{ .inline_bold = .{ .children = @as([]const *Node, &[_]*Node{italic_ptr}) } };

    try renderHtml(&bold, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<strong><em>both</em></strong>", result);
}

// -----------------------------------------------------------------------------
// renderInlineItalics tests
// -----------------------------------------------------------------------------

test "renderInlineItalics - simple italic" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var text = Node{ .text = .{ .value = "italic" } };
    const text_ptr: *Node = &text;
    var italic = Node{ .inline_italics = .{ .children = @as([]const *Node, &[_]*Node{text_ptr}) } };

    try renderHtml(&italic, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<em>italic</em>", result);
}

test "renderInlineItalics - empty italic" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var italic = Node{ .inline_italics = .{ .children = &[_]*Node{} } };

    try renderHtml(&italic, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<em></em>", result);
}

// -----------------------------------------------------------------------------
// renderImage tests
// -----------------------------------------------------------------------------

test "renderImage - with alt and src" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var img = Node{ .image = .{ .alt = "Alt text", .src = "image.png", .title = null } };

    try renderHtml(&img, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<img src=\"image.png\" alt=\"Alt text\">", result);
}

test "renderImage - with title" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var img = Node{ .image = .{ .alt = "Alt", .src = "img.jpg", .title = "Title" } };

    try renderHtml(&img, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<img src=\"img.jpg\" alt=\"Alt\" title=\"Title\">", result);
}

test "renderImage - empty alt" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var img = Node{ .image = .{ .alt = "", .src = "img.png", .title = null } };

    try renderHtml(&img, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<img src=\"img.png\" alt=\"\">", result);
}

test "renderImage - escapes quotes in alt" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var img = Node{ .image = .{ .alt = "He said \"hi\"", .src = "img.png", .title = null } };

    try renderHtml(&img, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<img src=\"img.png\" alt=\"He said &quot;hi&quot;\">", result);
}

test "renderImage - escapes special chars in src" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var img = Node{ .image = .{ .alt = "img", .src = "img.png?a=1&b=2", .title = null } };

    try renderHtml(&img, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<img src=\"img.png?a=1&amp;b=2\" alt=\"img\">", result);
}

// -----------------------------------------------------------------------------
// renderLink tests
// -----------------------------------------------------------------------------

test "renderLink - simple link" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var text = Node{ .text = .{ .value = "Click here" } };
    const text_ptr: *Node = &text;
    var link = Node{ .link = .{ .children = @as([]const *Node, &[_]*Node{text_ptr}), .href = "https://example.com", .title = null } };

    try renderHtml(&link, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<a href=\"https://example.com\">Click here</a>", result);
}

test "renderLink - with title" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var text = Node{ .text = .{ .value = "Link" } };
    const text_ptr: *Node = &text;
    var link = Node{ .link = .{ .children = @as([]const *Node, &[_]*Node{text_ptr}), .href = "url.com", .title = "Title" } };

    try renderHtml(&link, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<a href=\"url.com\" title=\"Title\">Link</a>", result);
}

test "renderLink - empty text" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var link = Node{ .link = .{ .children = &[_]*Node{}, .href = "url.com", .title = null } };

    try renderHtml(&link, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<a href=\"url.com\"></a>", result);
}

test "renderLink - escapes quotes in href" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var text = Node{ .text = .{ .value = "Link" } };
    const text_ptr: *Node = &text;
    var link = Node{ .link = .{ .children = @as([]const *Node, &[_]*Node{text_ptr}), .href = "url.com?x=\"test\"", .title = null } };

    try renderHtml(&link, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<a href=\"url.com?x=&quot;test&quot;\">Link</a>", result);
}

test "renderLink - with bold text" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var text_inner = Node{ .text = .{ .value = "bold link" } };
    const text_inner_ptr: *Node = &text_inner;
    var bold = Node{ .inline_bold = .{ .children = @as([]const *Node, &[_]*Node{text_inner_ptr}) } };
    const bold_ptr: *Node = &bold;
    var link = Node{ .link = .{ .children = @as([]const *Node, &[_]*Node{bold_ptr}), .href = "url.com", .title = null } };

    try renderHtml(&link, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<a href=\"url.com\"><strong>bold link</strong></a>", result);
}

// -----------------------------------------------------------------------------
// renderHorizontalRule tests
// -----------------------------------------------------------------------------

test "renderHorizontalRule - basic" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var hr = Node{ .horizontal_rule = .{} };

    try renderHtml(&hr, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<hr>", result);
}

// -----------------------------------------------------------------------------
// renderLineBreak tests
// -----------------------------------------------------------------------------

test "renderLineBreak - basic" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var br: Node = .{ .line_break = {} };

    try renderHtml(&br, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<br>", result);
}

// -----------------------------------------------------------------------------
// writeEscaped tests
// -----------------------------------------------------------------------------

test "writeEscaped - no special chars" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    try writeEscaped(writer, "Hello World");

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("Hello World", result);
}

test "writeEscaped - all special chars" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    try writeEscaped(writer, "<>&");

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("&lt;&gt;&amp;", result);
}

test "writeEscaped - empty string" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    try writeEscaped(writer, "");

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("", result);
}

// -----------------------------------------------------------------------------
// writeEscapedAttribute tests
// -----------------------------------------------------------------------------

test "writeEscapedAttribute - escapes quotes" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    try writeEscapedAttribute(writer, "He said \"hello\"");

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("He said &quot;hello&quot;", result);
}

test "writeEscapedAttribute - escapes all special chars" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    try writeEscapedAttribute(writer, "<>&\"");

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("&lt;&gt;&amp;&quot;", result);
}

// -----------------------------------------------------------------------------
// renderToString tests
// -----------------------------------------------------------------------------

test "renderToString - simple paragraph" {
    const allocator = std.testing.allocator;

    var text = Node{ .text = .{ .value = "Hello" } };
    const text_ptr: *Node = &text;
    var para = Node{ .paragraph = .{ .children = @as([]const *Node, &[_]*Node{text_ptr}) } };

    const result = try renderToString(&para, allocator);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("<p>Hello</p>", result);
}

// -----------------------------------------------------------------------------
// Integration / Edge case tests
// -----------------------------------------------------------------------------

test "integration - complex nested structure" {
    var buf: [2048]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    // Create: <p>Text with <strong>bold and <em>italic</em></strong> content</p>
    var text1 = Node{ .text = .{ .value = "Text with " } };
    const text1_ptr: *Node = &text1;

    var italic_text = Node{ .text = .{ .value = "italic" } };
    const italic_text_ptr: *Node = &italic_text;
    var italic = Node{ .inline_italics = .{ .children = @as([]const *Node, &[_]*Node{italic_text_ptr}) } };
    const italic_ptr: *Node = &italic;

    var bold_text = Node{ .text = .{ .value = "bold and " } };
    const bold_text_ptr: *Node = &bold_text;
    var bold = Node{ .inline_bold = .{ .children = @as([]const *Node, &[_]*Node{ bold_text_ptr, italic_ptr }) } };
    const bold_ptr: *Node = &bold;

    var text2 = Node{ .text = .{ .value = " content" } };
    const text2_ptr: *Node = &text2;

    var para = Node{ .paragraph = .{ .children = @as([]const *Node, &[_]*Node{ text1_ptr, bold_ptr, text2_ptr }) } };

    try renderHtml(&para, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<p>Text with <strong>bold and <em>italic</em></strong> content</p>", result);
}

test "integration - document with multiple block types" {
    var buf: [4096]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    // Heading
    var h_text = Node{ .text = .{ .value = "Title" } };
    const h_text_ptr: *Node = &h_text;
    var heading = Node{ .heading = .{ .level = 1, .children = @as([]const *Node, &[_]*Node{h_text_ptr}) } };
    const heading_ptr: *Node = &heading;

    // Paragraph
    var p_text = Node{ .text = .{ .value = "Paragraph text" } };
    const p_text_ptr: *Node = &p_text;
    var para = Node{ .paragraph = .{ .children = @as([]const *Node, &[_]*Node{p_text_ptr}) } };
    const para_ptr: *Node = &para;

    // Horizontal rule
    var hr = Node{ .horizontal_rule = .{} };
    const hr_ptr: *Node = &hr;

    // Document
    var doc = Node{ .document = .{ .children = @as([]const *Node, &[_]*Node{ heading_ptr, para_ptr, hr_ptr }) } };

    try renderHtml(&doc, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<h1>Title</h1><p>Paragraph text</p><hr>", result);
}

test "edge case - deeply nested lists" {
    var buf: [4096]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    // Inner list item
    var text3 = Node{ .text = .{ .value = "Deep" } };
    const text3_ptr: *Node = &text3;
    var para3 = Node{ .paragraph = .{ .children = @as([]const *Node, &[_]*Node{text3_ptr}) } };
    const para3_ptr: *Node = &para3;
    var li3 = Node{ .list_item = .{ .children = @as([]const *Node, &[_]*Node{para3_ptr}) } };
    const li3_ptr: *Node = &li3;
    var inner_list = Node{ .list = .{ .ordered = false, .marker = '-', .children = @as([]const *Node, &[_]*Node{li3_ptr}) } };
    const inner_list_ptr: *Node = &inner_list;

    // Outer list item containing nested list
    var text1 = Node{ .text = .{ .value = "Outer" } };
    const text1_ptr: *Node = &text1;
    var para1 = Node{ .paragraph = .{ .children = @as([]const *Node, &[_]*Node{text1_ptr}) } };
    const para1_ptr: *Node = &para1;
    var li1 = Node{ .list_item = .{ .children = @as([]const *Node, &[_]*Node{ para1_ptr, inner_list_ptr }) } };
    const li1_ptr: *Node = &li1;
    var outer_list = Node{ .list = .{ .ordered = false, .marker = '-', .children = @as([]const *Node, &[_]*Node{li1_ptr}) } };

    try renderHtml(&outer_list, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<ul><li><p>Outer</p><ul><li><p>Deep</p></li></ul></li></ul>", result);
}

test "edge case - unicode content" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var text = Node{ .text = .{ .value = "Hello 世界 🌍" } };

    try renderHtml(&text, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("Hello 世界 🌍", result);
}

test "edge case - XSS prevention" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var text = Node{ .text = .{ .value = "<script>alert('XSS')</script>" } };
    const text_ptr: *Node = &text;
    var para = Node{ .paragraph = .{ .children = @as([]const *Node, &[_]*Node{text_ptr}) } };

    try renderHtml(&para, writer);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("<p>&lt;script&gt;alert('XSS')&lt;/script&gt;</p>", result);
}

test "edge case - link with XSS in href" {
    var buf: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const writer = stream.writer();

    var text = Node{ .text = .{ .value = "click" } };
    const text_ptr: *Node = &text;
    var link = Node{ .link = .{ .children = @as([]const *Node, &[_]*Node{text_ptr}), .href = "javascript:alert(\"XSS\")", .title = null } };

    try renderHtml(&link, writer);

    const result = stream.getWritten();
    // Note: quotes in href should be escaped
    try std.testing.expectEqualStrings("<a href=\"javascript:alert(&quot;XSS&quot;)\">click</a>", result);
}
