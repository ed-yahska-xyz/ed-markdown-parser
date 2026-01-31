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
const InlineBold = models.InlineBold;
const InlineItalics = models.InlineItalics;
const Image = models.Image;
const Link = models.Link;

pub const ParseError = error{
    NotImplemented,
    InvalidSyntax,
    UnexpectedEndOfInput,
    OutOfMemory,
};

/// Entry point: parses markdown content into a Document AST
pub fn parseDocument(input: []const u8, allocator: std.mem.Allocator) ParseError!*Node {
    _ = input;
    _ = allocator;
    return ParseError.NotImplemented;
}

/// Parses a heading block starting with #
pub fn parseHeading(input: []const u8, pos: *usize, allocator: std.mem.Allocator) ParseError!*Node {
    _ = input;
    _ = pos;
    _ = allocator;
    return ParseError.NotImplemented;
}

/// Parses a paragraph block
pub fn parseParagraph(input: []const u8, pos: *usize, allocator: std.mem.Allocator) ParseError!*Node {
    _ = input;
    _ = pos;
    _ = allocator;
    return ParseError.NotImplemented;
}

/// Parses plain text until inline syntax is encountered
pub fn parseText(input: []const u8, pos: *usize, allocator: std.mem.Allocator) ParseError!*Node {
    _ = input;
    _ = pos;
    _ = allocator;
    return ParseError.NotImplemented;
}

/// Parses a blockquote starting with >
pub fn parseBlockquote(input: []const u8, pos: *usize, allocator: std.mem.Allocator) ParseError!*Node {
    _ = input;
    _ = pos;
    _ = allocator;
    return ParseError.NotImplemented;
}

/// Parses a list starting with -, *, or +
pub fn parseList(input: []const u8, pos: *usize, allocator: std.mem.Allocator) ParseError!*Node {
    _ = input;
    _ = pos;
    _ = allocator;
    return ParseError.NotImplemented;
}

/// Parses an individual list item
pub fn parseListItem(input: []const u8, pos: *usize, allocator: std.mem.Allocator) ParseError!*Node {
    _ = input;
    _ = pos;
    _ = allocator;
    return ParseError.NotImplemented;
}

/// Parses inline code wrapped in backticks
pub fn parseCode(input: []const u8, pos: *usize, allocator: std.mem.Allocator) ParseError!*Node {
    _ = input;
    _ = pos;
    _ = allocator;
    return ParseError.NotImplemented;
}

/// Parses bold text wrapped in **
pub fn parseInlineBold(input: []const u8, pos: *usize, allocator: std.mem.Allocator) ParseError!*Node {
    _ = input;
    _ = pos;
    _ = allocator;
    return ParseError.NotImplemented;
}

/// Parses italic text wrapped in *
pub fn parseInlineItalics(input: []const u8, pos: *usize, allocator: std.mem.Allocator) ParseError!*Node {
    _ = input;
    _ = pos;
    _ = allocator;
    return ParseError.NotImplemented;
}

/// Parses an image ![alt](src "title")
pub fn parseImage(input: []const u8, pos: *usize, allocator: std.mem.Allocator) ParseError!*Node {
    _ = input;
    _ = pos;
    _ = allocator;
    return ParseError.NotImplemented;
}

/// Parses a link [text](href "title")
pub fn parseLink(input: []const u8, pos: *usize, allocator: std.mem.Allocator) ParseError!*Node {
    _ = input;
    _ = pos;
    _ = allocator;
    return ParseError.NotImplemented;
}

// =============================================================================
// Tests
// =============================================================================

test "parseDocument - simple paragraph" {
    const allocator = std.testing.allocator;
    const input = "Hello, world!";
    const doc = try parseDocument(input, allocator);
    try std.testing.expect(doc.* == .document);
}

test "parseHeading - level 1" {
    const allocator = std.testing.allocator;
    const input = "# Hello";
    var pos: usize = 0;
    const node = try parseHeading(input, &pos, allocator);
    try std.testing.expect(node.* == .heading);
    try std.testing.expectEqual(@as(u8, 1), node.heading.level);
}

test "parseHeading - level 3" {
    const allocator = std.testing.allocator;
    const input = "### Third level heading";
    var pos: usize = 0;
    const node = try parseHeading(input, &pos, allocator);
    try std.testing.expect(node.* == .heading);
    try std.testing.expectEqual(@as(u8, 3), node.heading.level);
}

test "parseParagraph - simple text" {
    const allocator = std.testing.allocator;
    const input = "This is a paragraph.";
    var pos: usize = 0;
    const node = try parseParagraph(input, &pos, allocator);
    try std.testing.expect(node.* == .paragraph);
}

test "parseText - plain text" {
    const allocator = std.testing.allocator;
    const input = "plain text here";
    var pos: usize = 0;
    const node = try parseText(input, &pos, allocator);
    try std.testing.expect(node.* == .text);
    try std.testing.expectEqualStrings("plain text here", node.text.value);
}

test "parseText - stops at inline syntax" {
    const allocator = std.testing.allocator;
    const input = "text before *italic*";
    var pos: usize = 0;
    const node = try parseText(input, &pos, allocator);
    try std.testing.expect(node.* == .text);
    try std.testing.expectEqualStrings("text before ", node.text.value);
}

test "parseBlockquote - simple" {
    const allocator = std.testing.allocator;
    const input = "> This is a quote";
    var pos: usize = 0;
    const node = try parseBlockquote(input, &pos, allocator);
    try std.testing.expect(node.* == .blockquote);
}

test "parseList - unordered with dash" {
    const allocator = std.testing.allocator;
    const input = "- item 1\n- item 2";
    var pos: usize = 0;
    const node = try parseList(input, &pos, allocator);
    try std.testing.expect(node.* == .list);
    try std.testing.expectEqual(@as(u8, '-'), node.list.marker);
}

test "parseListItem - simple item" {
    const allocator = std.testing.allocator;
    const input = "item content";
    var pos: usize = 0;
    const node = try parseListItem(input, &pos, allocator);
    try std.testing.expect(node.* == .list_item);
}

test "parseCode - single backtick" {
    const allocator = std.testing.allocator;
    const input = "`code here`";
    var pos: usize = 0;
    const node = try parseCode(input, &pos, allocator);
    try std.testing.expect(node.* == .code);
    try std.testing.expectEqualStrings("code here", node.code.value);
}

test "parseCode - double backtick" {
    const allocator = std.testing.allocator;
    const input = "``code with ` inside``";
    var pos: usize = 0;
    const node = try parseCode(input, &pos, allocator);
    try std.testing.expect(node.* == .code);
    try std.testing.expectEqualStrings("code with ` inside", node.code.value);
}

test "parseInlineBold - simple" {
    const allocator = std.testing.allocator;
    const input = "**bold text**";
    var pos: usize = 0;
    const node = try parseInlineBold(input, &pos, allocator);
    try std.testing.expect(node.* == .inline_bold);
}

test "parseInlineItalics - simple" {
    const allocator = std.testing.allocator;
    const input = "*italic text*";
    var pos: usize = 0;
    const node = try parseInlineItalics(input, &pos, allocator);
    try std.testing.expect(node.* == .inline_italics);
}

test "parseImage - with alt and src" {
    const allocator = std.testing.allocator;
    const input = "![alt text](image.png)";
    var pos: usize = 0;
    const node = try parseImage(input, &pos, allocator);
    try std.testing.expect(node.* == .image);
    try std.testing.expectEqualStrings("alt text", node.image.alt);
    try std.testing.expectEqualStrings("image.png", node.image.src);
}

test "parseImage - with title" {
    const allocator = std.testing.allocator;
    const input = "![alt](img.jpg \"Image Title\")";
    var pos: usize = 0;
    const node = try parseImage(input, &pos, allocator);
    try std.testing.expect(node.* == .image);
    try std.testing.expectEqualStrings("Image Title", node.image.title.?);
}

test "parseLink - simple" {
    const allocator = std.testing.allocator;
    const input = "[click here](https://example.com)";
    var pos: usize = 0;
    const node = try parseLink(input, &pos, allocator);
    try std.testing.expect(node.* == .link);
    try std.testing.expectEqualStrings("https://example.com", node.link.href);
}

test "parseLink - with title" {
    const allocator = std.testing.allocator;
    const input = "[link](url.com \"Link Title\")";
    var pos: usize = 0;
    const node = try parseLink(input, &pos, allocator);
    try std.testing.expect(node.* == .link);
    try std.testing.expectEqualStrings("Link Title", node.link.title.?);
}
