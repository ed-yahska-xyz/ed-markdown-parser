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

pub const ParseError = error{
    NotImplemented,
    InvalidSyntax,
    UnexpectedEndOfInput,
    OutOfMemory,
};

/// Entry point: parses markdown content into a Document AST
pub fn parseDocument(input: []const u8, allocator: std.mem.Allocator) ParseError!*Node {
    var children = std.ArrayList(*Node).init(allocator);
    errdefer children.deinit();

    var pos: usize = 0;

    while (pos < input.len) {
        // Skip empty lines
        while (pos < input.len and input[pos] == '\n') {
            pos += 1;
        }
        if (pos >= input.len) break;

        // Determine block type
        const c = input[pos];

        // Check for heading
        if (c == '#') {
            const heading = try parseHeading(input, &pos, allocator);
            children.append(heading) catch return ParseError.OutOfMemory;
            continue;
        }

        // Check for blockquote
        if (c == '>') {
            const blockquote = try parseBlockquote(input, &pos, allocator);
            children.append(blockquote) catch return ParseError.OutOfMemory;
            continue;
        }

        // Check for fenced code block
        if (c == '`' or c == '~') {
            if (pos + 2 < input.len and input[pos + 1] == c and input[pos + 2] == c) {
                const code_block = try parseCodeBlock(input, &pos, allocator);
                children.append(code_block) catch return ParseError.OutOfMemory;
                continue;
            }
        }

        // Check for horizontal rule (---, ***, ___)
        if (c == '-' or c == '*' or c == '_') {
            // Look ahead to see if it's a horizontal rule
            var hr_count: usize = 0;
            var check_pos = pos;
            while (check_pos < input.len and input[check_pos] != '\n') {
                if (input[check_pos] == c) {
                    hr_count += 1;
                } else if (input[check_pos] != ' ') {
                    break;
                }
                check_pos += 1;
            }
            if (hr_count >= 3 and (check_pos >= input.len or input[check_pos] == '\n')) {
                const hr = try parseHorizontalRule(input, &pos, allocator);
                children.append(hr) catch return ParseError.OutOfMemory;
                continue;
            }
        }

        // Check for unordered list
        if ((c == '-' or c == '*' or c == '+') and pos + 1 < input.len and input[pos + 1] == ' ') {
            const list = try parseList(input, &pos, allocator);
            children.append(list) catch return ParseError.OutOfMemory;
            continue;
        }

        // Check for ordered list
        if (c >= '0' and c <= '9') {
            var check_pos = pos;
            while (check_pos < input.len and input[check_pos] >= '0' and input[check_pos] <= '9') {
                check_pos += 1;
            }
            if (check_pos < input.len and input[check_pos] == '.' and check_pos + 1 < input.len and input[check_pos + 1] == ' ') {
                const list = try parseList(input, &pos, allocator);
                children.append(list) catch return ParseError.OutOfMemory;
                continue;
            }
        }

        // Default: parse as paragraph
        const para = try parseParagraph(input, &pos, allocator);
        children.append(para) catch return ParseError.OutOfMemory;
    }

    const node = allocator.create(Node) catch return ParseError.OutOfMemory;
    node.* = .{ .document = .{
        .children = children.toOwnedSlice() catch return ParseError.OutOfMemory,
    } };
    return node;
}

/// Parses a heading block starting with #
pub fn parseHeading(input: []const u8, pos: *usize, allocator: std.mem.Allocator) ParseError!*Node {
    if (pos.* >= input.len or input[pos.*] != '#') {
        return ParseError.InvalidSyntax;
    }

    // Count # symbols
    var level: u8 = 0;
    while (pos.* < input.len and input[pos.*] == '#') {
        level += 1;
        pos.* += 1;
    }

    // Level must be 1-6
    if (level > 6) {
        return ParseError.InvalidSyntax;
    }

    // Must be followed by space
    if (pos.* >= input.len or input[pos.*] != ' ') {
        return ParseError.InvalidSyntax;
    }
    pos.* += 1; // skip space

    // Parse heading content until end of line
    var children = std.ArrayList(*Node).init(allocator);
    errdefer children.deinit();

    // Find end of line
    const line_start = pos.*;
    while (pos.* < input.len and input[pos.*] != '\n') {
        pos.* += 1;
    }
    const line_content = input[line_start..pos.*];

    // Skip newline if present
    if (pos.* < input.len and input[pos.*] == '\n') {
        pos.* += 1;
    }

    // Parse inline content from heading text
    if (line_content.len > 0) {
        var text_pos: usize = 0;
        while (text_pos < line_content.len) {
            // Check for bold
            if (text_pos + 1 < line_content.len and line_content[text_pos] == '*' and line_content[text_pos + 1] == '*') {
                const bold_node = try parseInlineBold(line_content, &text_pos, allocator);
                children.append(bold_node) catch return ParseError.OutOfMemory;
                continue;
            }
            // Check for italic
            if (line_content[text_pos] == '*') {
                const italic_node = try parseInlineItalics(line_content, &text_pos, allocator);
                children.append(italic_node) catch return ParseError.OutOfMemory;
                continue;
            }
            // Check for code
            if (line_content[text_pos] == '`') {
                const code_node = try parseCode(line_content, &text_pos, allocator);
                children.append(code_node) catch return ParseError.OutOfMemory;
                continue;
            }
            // Check for link
            if (line_content[text_pos] == '[') {
                const link_node = try parseLink(line_content, &text_pos, allocator);
                children.append(link_node) catch return ParseError.OutOfMemory;
                continue;
            }
            // Check for image
            if (text_pos + 1 < line_content.len and line_content[text_pos] == '!' and line_content[text_pos + 1] == '[') {
                const image_node = try parseImage(line_content, &text_pos, allocator);
                children.append(image_node) catch return ParseError.OutOfMemory;
                continue;
            }
            // Parse as text
            const text_node = try parseText(line_content, &text_pos, allocator);
            children.append(text_node) catch return ParseError.OutOfMemory;
        }
    }

    const node = allocator.create(Node) catch return ParseError.OutOfMemory;
    node.* = .{ .heading = .{
        .level = level,
        .children = children.toOwnedSlice() catch return ParseError.OutOfMemory,
    } };
    return node;
}

/// Parses a paragraph block
pub fn parseParagraph(input: []const u8, pos: *usize, allocator: std.mem.Allocator) ParseError!*Node {
    var children = std.ArrayList(*Node).init(allocator);
    errdefer children.deinit();

    // Collect paragraph content until empty line (double newline)
    const para_start = pos.*;
    var para_end = pos.*;

    while (pos.* < input.len) {
        // Check for empty line (paragraph separator)
        if (input[pos.*] == '\n') {
            if (pos.* + 1 < input.len and input[pos.* + 1] == '\n') {
                // Found empty line - end of paragraph
                para_end = pos.*;
                break;
            }
        }
        para_end = pos.* + 1;
        pos.* += 1;
    }

    // If we hit end of input, para_end is at pos
    if (pos.* >= input.len) {
        para_end = pos.*;
    }

    const para_content = input[para_start..para_end];

    // Parse inline content
    if (para_content.len > 0) {
        var text_pos: usize = 0;
        while (text_pos < para_content.len) {
            // Skip newlines within paragraph (soft breaks)
            if (para_content[text_pos] == '\n') {
                text_pos += 1;
                continue;
            }
            // Check for bold
            if (text_pos + 1 < para_content.len and para_content[text_pos] == '*' and para_content[text_pos + 1] == '*') {
                const bold_node = try parseInlineBold(para_content, &text_pos, allocator);
                children.append(bold_node) catch return ParseError.OutOfMemory;
                continue;
            }
            // Check for italic
            if (para_content[text_pos] == '*') {
                const italic_node = try parseInlineItalics(para_content, &text_pos, allocator);
                children.append(italic_node) catch return ParseError.OutOfMemory;
                continue;
            }
            // Check for code
            if (para_content[text_pos] == '`') {
                const code_node = try parseCode(para_content, &text_pos, allocator);
                children.append(code_node) catch return ParseError.OutOfMemory;
                continue;
            }
            // Check for link
            if (para_content[text_pos] == '[') {
                const link_node = try parseLink(para_content, &text_pos, allocator);
                children.append(link_node) catch return ParseError.OutOfMemory;
                continue;
            }
            // Check for image
            if (text_pos + 1 < para_content.len and para_content[text_pos] == '!' and para_content[text_pos + 1] == '[') {
                const image_node = try parseImage(para_content, &text_pos, allocator);
                children.append(image_node) catch return ParseError.OutOfMemory;
                continue;
            }
            // Parse as text
            const text_node = try parseText(para_content, &text_pos, allocator);
            children.append(text_node) catch return ParseError.OutOfMemory;
        }
    }

    const node = allocator.create(Node) catch return ParseError.OutOfMemory;
    node.* = .{ .paragraph = .{
        .children = children.toOwnedSlice() catch return ParseError.OutOfMemory,
    } };
    return node;
}

/// Parses plain text until inline syntax is encountered
pub fn parseText(input: []const u8, pos: *usize, allocator: std.mem.Allocator) ParseError!*Node {
    const start = pos.*;
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    while (pos.* < input.len) {
        const c = input[pos.*];

        // Check for escape character
        if (c == '\\' and pos.* + 1 < input.len) {
            // Skip the backslash and add the next character literally
            pos.* += 1;
            result.append(input[pos.*]) catch return ParseError.OutOfMemory;
            pos.* += 1;
            continue;
        }

        // Check for inline syntax markers that should stop text parsing
        // Stop at: *, `, [, or ! followed by [
        if (c == '*' or c == '`' or c == '[') {
            break;
        }

        // Check for image syntax: ! followed by [
        if (c == '!' and pos.* + 1 < input.len and input[pos.* + 1] == '[') {
            break;
        }

        result.append(c) catch return ParseError.OutOfMemory;
        pos.* += 1;
    }

    // If no text was consumed, this is unexpected
    if (pos.* == start and result.items.len == 0) {
        return ParseError.InvalidSyntax;
    }

    const node = allocator.create(Node) catch return ParseError.OutOfMemory;
    node.* = .{ .text = .{ .value = result.toOwnedSlice() catch return ParseError.OutOfMemory } };
    return node;
}

/// Parses a blockquote starting with >
pub fn parseBlockquote(input: []const u8, pos: *usize, allocator: std.mem.Allocator) ParseError!*Node {
    if (pos.* >= input.len or input[pos.*] != '>') {
        return ParseError.InvalidSyntax;
    }

    var children = std.ArrayList(*Node).init(allocator);
    errdefer children.deinit();

    // Collect blockquote content
    var content = std.ArrayList(u8).init(allocator);
    defer content.deinit();

    while (pos.* < input.len) {
        // Check for blockquote marker
        if (input[pos.*] == '>') {
            pos.* += 1;
            // Skip optional space after >
            if (pos.* < input.len and input[pos.*] == ' ') {
                pos.* += 1;
            }
            // Check for nested blockquote
            if (pos.* < input.len and input[pos.*] == '>') {
                const nested = try parseBlockquote(input, pos, allocator);
                children.append(nested) catch return ParseError.OutOfMemory;
                continue;
            }
            // Collect line content
            while (pos.* < input.len and input[pos.*] != '\n') {
                content.append(input[pos.*]) catch return ParseError.OutOfMemory;
                pos.* += 1;
            }
            content.append('\n') catch return ParseError.OutOfMemory;
            if (pos.* < input.len) {
                pos.* += 1; // skip newline
            }
        } else if (input[pos.*] == '\n') {
            // Empty line ends blockquote
            break;
        } else {
            // Non-blockquote line ends blockquote
            break;
        }
    }

    // Parse content as paragraph if we have any
    if (content.items.len > 0) {
        var content_pos: usize = 0;
        const para_node = try parseParagraph(content.items, &content_pos, allocator);
        children.append(para_node) catch return ParseError.OutOfMemory;
    }

    const node = allocator.create(Node) catch return ParseError.OutOfMemory;
    node.* = .{ .blockquote = .{
        .children = children.toOwnedSlice() catch return ParseError.OutOfMemory,
    } };
    return node;
}

/// Parses a list starting with -, *, or +
pub fn parseList(input: []const u8, pos: *usize, allocator: std.mem.Allocator) ParseError!*Node {
    if (pos.* >= input.len) {
        return ParseError.InvalidSyntax;
    }

    var children = std.ArrayList(*Node).init(allocator);
    errdefer children.deinit();

    var ordered = false;
    var marker: u8 = 0;

    // Check for ordered list (number followed by .)
    if (input[pos.*] >= '0' and input[pos.*] <= '9') {
        ordered = true;
        marker = input[pos.*];
    } else if (input[pos.*] == '-' or input[pos.*] == '*' or input[pos.*] == '+') {
        marker = input[pos.*];
    } else {
        return ParseError.InvalidSyntax;
    }

    while (pos.* < input.len) {
        // Skip leading whitespace for nested items
        var indent: usize = 0;
        while (pos.* < input.len and (input[pos.*] == ' ' or input[pos.*] == '\t')) {
            if (input[pos.*] == '\t') {
                indent += 4;
            } else {
                indent += 1;
            }
            pos.* += 1;
        }

        if (pos.* >= input.len) break;

        // Check for nested list (4+ spaces of indent)
        if (indent >= 4) {
            // Parse nested list
            const nested = try parseList(input, pos, allocator);
            // Add to last list item's children if possible
            if (children.items.len > 0) {
                const last_item = children.items[children.items.len - 1];
                if (last_item.* == .list_item) {
                    var item_children = std.ArrayList(*Node).init(allocator);
                    for (last_item.list_item.children) |child| {
                        item_children.append(child) catch return ParseError.OutOfMemory;
                    }
                    item_children.append(nested) catch return ParseError.OutOfMemory;
                    last_item.* = .{ .list_item = .{
                        .children = item_children.toOwnedSlice() catch return ParseError.OutOfMemory,
                    } };
                }
            }
            continue;
        }

        // Check for list marker
        if (ordered) {
            // Ordered: expect digit(s) followed by . and space
            if (input[pos.*] >= '0' and input[pos.*] <= '9') {
                while (pos.* < input.len and input[pos.*] >= '0' and input[pos.*] <= '9') {
                    pos.* += 1;
                }
                if (pos.* >= input.len or input[pos.*] != '.') {
                    break;
                }
                pos.* += 1; // skip .
                if (pos.* >= input.len or input[pos.*] != ' ') {
                    break;
                }
                pos.* += 1; // skip space
            } else {
                break;
            }
        } else {
            // Unordered: expect marker and space
            if (input[pos.*] != marker) {
                break;
            }
            pos.* += 1;
            if (pos.* >= input.len or input[pos.*] != ' ') {
                break;
            }
            pos.* += 1; // skip space
        }

        // Collect item content until end of line
        const item_start = pos.*;
        while (pos.* < input.len and input[pos.*] != '\n') {
            pos.* += 1;
        }
        const item_content = input[item_start..pos.*];

        // Skip newline
        if (pos.* < input.len and input[pos.*] == '\n') {
            pos.* += 1;
        }

        // Parse item content
        var item_pos: usize = 0;
        const list_item = try parseListItem(item_content, &item_pos, allocator);
        children.append(list_item) catch return ParseError.OutOfMemory;

        // Check for end of list (empty line or different marker)
        if (pos.* >= input.len) break;
        if (input[pos.*] == '\n') break;
    }

    const node = allocator.create(Node) catch return ParseError.OutOfMemory;
    node.* = .{ .list = .{
        .ordered = ordered,
        .marker = marker,
        .children = children.toOwnedSlice() catch return ParseError.OutOfMemory,
    } };
    return node;
}

/// Parses an individual list item
pub fn parseListItem(input: []const u8, pos: *usize, allocator: std.mem.Allocator) ParseError!*Node {
    var children = std.ArrayList(*Node).init(allocator);
    errdefer children.deinit();

    // Parse content as paragraph
    var content_pos: usize = 0;
    const para_node = try parseParagraph(input, &content_pos, allocator);
    children.append(para_node) catch return ParseError.OutOfMemory;
    pos.* += content_pos;

    const node = allocator.create(Node) catch return ParseError.OutOfMemory;
    node.* = .{ .list_item = .{
        .children = children.toOwnedSlice() catch return ParseError.OutOfMemory,
    } };
    return node;
}

/// Parses inline code wrapped in backticks
pub fn parseCode(input: []const u8, pos: *usize, allocator: std.mem.Allocator) ParseError!*Node {
    if (pos.* >= input.len or input[pos.*] != '`') {
        return ParseError.InvalidSyntax;
    }

    // Count opening backticks (but only use half if that's all we have)
    var total_backticks: usize = 0;
    while (pos.* + total_backticks < input.len and input[pos.* + total_backticks] == '`') {
        total_backticks += 1;
    }

    // If we have even number of backticks and nothing else, split as open/close with empty content
    if (pos.* + total_backticks >= input.len and total_backticks >= 2 and total_backticks % 2 == 0) {
        pos.* += total_backticks;
        const node = allocator.create(Node) catch return ParseError.OutOfMemory;
        node.* = .{ .code = .{ .value = "" } };
        return node;
    }

    // Determine backtick count (for double-backtick style, use 2; otherwise use 1)
    const backtick_count: usize = if (total_backticks >= 2) 2 else 1;
    pos.* += backtick_count;

    // Find closing backticks (same count)
    const start = pos.*;
    while (pos.* < input.len) {
        if (input[pos.*] == '`') {
            // Count consecutive backticks
            var close_count: usize = 0;
            while (pos.* + close_count < input.len and input[pos.* + close_count] == '`') {
                close_count += 1;
            }
            if (close_count >= backtick_count) {
                const code_value = input[start..pos.*];
                pos.* += backtick_count;

                const node = allocator.create(Node) catch return ParseError.OutOfMemory;
                node.* = .{ .code = .{ .value = code_value } };
                return node;
            }
            pos.* += close_count;
        } else {
            pos.* += 1;
        }
    }

    return ParseError.UnexpectedEndOfInput;
}

/// Parses bold text wrapped in **
pub fn parseInlineBold(input: []const u8, pos: *usize, allocator: std.mem.Allocator) ParseError!*Node {
    // Expect opening **
    if (pos.* + 1 >= input.len or input[pos.*] != '*' or input[pos.* + 1] != '*') {
        return ParseError.InvalidSyntax;
    }
    pos.* += 2;

    var children = std.ArrayList(*Node).init(allocator);
    errdefer children.deinit();

    // Parse content until closing **
    while (pos.* < input.len) {
        // Check for closing **
        if (pos.* + 1 < input.len and input[pos.*] == '*' and input[pos.* + 1] == '*') {
            pos.* += 2;
            const node = allocator.create(Node) catch return ParseError.OutOfMemory;
            node.* = .{ .inline_bold = .{ .children = children.toOwnedSlice() catch return ParseError.OutOfMemory } };
            return node;
        }

        // Check for nested italic (single *)
        if (input[pos.*] == '*' and (pos.* + 1 >= input.len or input[pos.* + 1] != '*')) {
            const italic_node = try parseInlineItalics(input, pos, allocator);
            children.append(italic_node) catch return ParseError.OutOfMemory;
            continue;
        }

        // Check for inline code
        if (input[pos.*] == '`') {
            const code_node = try parseCode(input, pos, allocator);
            children.append(code_node) catch return ParseError.OutOfMemory;
            continue;
        }

        // Parse as text
        const text_node = try parseText(input, pos, allocator);
        children.append(text_node) catch return ParseError.OutOfMemory;
    }

    return ParseError.UnexpectedEndOfInput;
}

/// Parses italic text wrapped in *
pub fn parseInlineItalics(input: []const u8, pos: *usize, allocator: std.mem.Allocator) ParseError!*Node {
    // Expect opening * (but not **)
    if (pos.* >= input.len or input[pos.*] != '*') {
        return ParseError.InvalidSyntax;
    }
    // Check it's not bold (**)
    if (pos.* + 1 < input.len and input[pos.* + 1] == '*') {
        return ParseError.InvalidSyntax;
    }
    pos.* += 1;

    var children = std.ArrayList(*Node).init(allocator);
    errdefer children.deinit();

    // Parse content until closing *
    while (pos.* < input.len) {
        // Check for closing * (but not **)
        if (input[pos.*] == '*' and (pos.* + 1 >= input.len or input[pos.* + 1] != '*')) {
            pos.* += 1;
            const node = allocator.create(Node) catch return ParseError.OutOfMemory;
            node.* = .{ .inline_italics = .{ .children = children.toOwnedSlice() catch return ParseError.OutOfMemory } };
            return node;
        }

        // Check for inline code
        if (input[pos.*] == '`') {
            const code_node = try parseCode(input, pos, allocator);
            children.append(code_node) catch return ParseError.OutOfMemory;
            continue;
        }

        // Parse as text (stop at * too)
        const text_node = try parseText(input, pos, allocator);
        children.append(text_node) catch return ParseError.OutOfMemory;
    }

    return ParseError.UnexpectedEndOfInput;
}

/// Parses an image ![alt](src "title")
pub fn parseImage(input: []const u8, pos: *usize, allocator: std.mem.Allocator) ParseError!*Node {
    // Expect ![
    if (pos.* + 1 >= input.len or input[pos.*] != '!' or input[pos.* + 1] != '[') {
        return ParseError.InvalidSyntax;
    }
    pos.* += 2;

    // Parse alt text until ]
    const alt_start = pos.*;
    while (pos.* < input.len and input[pos.*] != ']') {
        pos.* += 1;
    }
    if (pos.* >= input.len) {
        return ParseError.UnexpectedEndOfInput;
    }
    const alt = input[alt_start..pos.*];
    pos.* += 1; // skip ]

    // Expect (
    if (pos.* >= input.len or input[pos.*] != '(') {
        return ParseError.InvalidSyntax;
    }
    pos.* += 1;

    // Parse src until ) or space (for title)
    const src_start = pos.*;
    while (pos.* < input.len and input[pos.*] != ')' and input[pos.*] != ' ' and input[pos.*] != '"') {
        pos.* += 1;
    }
    if (pos.* >= input.len) {
        return ParseError.UnexpectedEndOfInput;
    }
    const src = input[src_start..pos.*];

    // Check for optional title
    var title: ?[]const u8 = null;
    if (pos.* < input.len and (input[pos.*] == ' ' or input[pos.*] == '"')) {
        // Skip space before title
        while (pos.* < input.len and input[pos.*] == ' ') {
            pos.* += 1;
        }
        if (pos.* < input.len and input[pos.*] == '"') {
            pos.* += 1; // skip opening "
            const title_start = pos.*;
            while (pos.* < input.len and input[pos.*] != '"') {
                pos.* += 1;
            }
            if (pos.* >= input.len) {
                return ParseError.UnexpectedEndOfInput;
            }
            title = input[title_start..pos.*];
            pos.* += 1; // skip closing "
        }
    }

    // Expect closing )
    while (pos.* < input.len and input[pos.*] == ' ') {
        pos.* += 1;
    }
    if (pos.* >= input.len or input[pos.*] != ')') {
        return ParseError.InvalidSyntax;
    }
    pos.* += 1;

    const node = allocator.create(Node) catch return ParseError.OutOfMemory;
    node.* = .{ .image = .{ .alt = alt, .src = src, .title = title } };
    return node;
}

/// Parses a link [text](href "title")
pub fn parseLink(input: []const u8, pos: *usize, allocator: std.mem.Allocator) ParseError!*Node {
    // Expect [
    if (pos.* >= input.len or input[pos.*] != '[') {
        return ParseError.InvalidSyntax;
    }
    pos.* += 1;

    // Parse link text (can contain inline formatting)
    var children = std.ArrayList(*Node).init(allocator);
    errdefer children.deinit();

    const text_start = pos.*;
    var bracket_depth: usize = 1;

    // Find the closing ] while tracking nested brackets
    while (pos.* < input.len and bracket_depth > 0) {
        if (input[pos.*] == '[') {
            bracket_depth += 1;
        } else if (input[pos.*] == ']') {
            bracket_depth -= 1;
            if (bracket_depth == 0) break;
        }
        pos.* += 1;
    }

    if (pos.* >= input.len) {
        return ParseError.UnexpectedEndOfInput;
    }

    // Parse inline content from the link text
    const link_text = input[text_start..pos.*];
    if (link_text.len > 0) {
        var text_pos: usize = 0;
        while (text_pos < link_text.len) {
            // Check for bold
            if (text_pos + 1 < link_text.len and link_text[text_pos] == '*' and link_text[text_pos + 1] == '*') {
                const bold_node = try parseInlineBold(link_text, &text_pos, allocator);
                children.append(bold_node) catch return ParseError.OutOfMemory;
                continue;
            }
            // Check for italic
            if (link_text[text_pos] == '*') {
                const italic_node = try parseInlineItalics(link_text, &text_pos, allocator);
                children.append(italic_node) catch return ParseError.OutOfMemory;
                continue;
            }
            // Check for code
            if (link_text[text_pos] == '`') {
                const code_node = try parseCode(link_text, &text_pos, allocator);
                children.append(code_node) catch return ParseError.OutOfMemory;
                continue;
            }
            // Parse as text
            const text_node = try parseText(link_text, &text_pos, allocator);
            children.append(text_node) catch return ParseError.OutOfMemory;
        }
    }

    pos.* += 1; // skip ]

    // Expect (
    if (pos.* >= input.len or input[pos.*] != '(') {
        return ParseError.InvalidSyntax;
    }
    pos.* += 1;

    // Parse href until ) or space (for title)
    const href_start = pos.*;
    while (pos.* < input.len and input[pos.*] != ')' and input[pos.*] != ' ' and input[pos.*] != '"') {
        pos.* += 1;
    }
    if (pos.* >= input.len) {
        return ParseError.UnexpectedEndOfInput;
    }
    const href = input[href_start..pos.*];

    // Check for optional title
    var title: ?[]const u8 = null;
    if (pos.* < input.len and (input[pos.*] == ' ' or input[pos.*] == '"')) {
        // Skip space before title
        while (pos.* < input.len and input[pos.*] == ' ') {
            pos.* += 1;
        }
        if (pos.* < input.len and input[pos.*] == '"') {
            pos.* += 1; // skip opening "
            const title_start = pos.*;
            while (pos.* < input.len and input[pos.*] != '"') {
                pos.* += 1;
            }
            if (pos.* >= input.len) {
                return ParseError.UnexpectedEndOfInput;
            }
            title = input[title_start..pos.*];
            pos.* += 1; // skip closing "
        }
    }

    // Expect closing )
    while (pos.* < input.len and input[pos.*] == ' ') {
        pos.* += 1;
    }
    if (pos.* >= input.len or input[pos.*] != ')') {
        return ParseError.InvalidSyntax;
    }
    pos.* += 1;

    const node = allocator.create(Node) catch return ParseError.OutOfMemory;
    node.* = .{ .link = .{
        .children = children.toOwnedSlice() catch return ParseError.OutOfMemory,
        .href = href,
        .title = title,
    } };
    return node;
}

/// Parses a fenced code block starting with ``` or ~~~
pub fn parseCodeBlock(input: []const u8, pos: *usize, allocator: std.mem.Allocator) ParseError!*Node {
    // Expect ``` or ~~~
    if (pos.* + 2 >= input.len) {
        return ParseError.InvalidSyntax;
    }

    const fence_char = input[pos.*];
    if (fence_char != '`' and fence_char != '~') {
        return ParseError.InvalidSyntax;
    }

    // Count fence characters
    var fence_count: usize = 0;
    while (pos.* + fence_count < input.len and input[pos.* + fence_count] == fence_char) {
        fence_count += 1;
    }
    if (fence_count < 3) {
        return ParseError.InvalidSyntax;
    }
    pos.* += fence_count;

    // Parse optional language identifier (until newline)
    var language: ?[]const u8 = null;
    const lang_start = pos.*;
    while (pos.* < input.len and input[pos.*] != '\n') {
        pos.* += 1;
    }
    const lang_str = input[lang_start..pos.*];
    if (lang_str.len > 0) {
        language = lang_str;
    }

    // Skip newline after language
    if (pos.* < input.len and input[pos.*] == '\n') {
        pos.* += 1;
    }

    // Find closing fence
    const content_start = pos.*;
    var content_end = pos.*;

    while (pos.* < input.len) {
        // Check for closing fence at start of line
        if (pos.* == content_start or (pos.* > 0 and input[pos.* - 1] == '\n')) {
            var close_count: usize = 0;
            while (pos.* + close_count < input.len and input[pos.* + close_count] == fence_char) {
                close_count += 1;
            }
            if (close_count >= fence_count) {
                content_end = pos.*;
                pos.* += close_count;
                // Skip to end of line
                while (pos.* < input.len and input[pos.*] != '\n') {
                    pos.* += 1;
                }
                if (pos.* < input.len) {
                    pos.* += 1;
                }

                const node = allocator.create(Node) catch return ParseError.OutOfMemory;
                node.* = .{ .code_block = .{
                    .language = language,
                    .value = input[content_start..content_end],
                } };
                return node;
            }
        }
        pos.* += 1;
    }

    return ParseError.UnexpectedEndOfInput;
}

/// Parses a horizontal rule (---, ***, ___)
pub fn parseHorizontalRule(input: []const u8, pos: *usize, allocator: std.mem.Allocator) ParseError!*Node {
    if (pos.* >= input.len) {
        return ParseError.InvalidSyntax;
    }

    const start = pos.*;
    const rule_char = input[pos.*];

    // Must be -, *, or _
    if (rule_char != '-' and rule_char != '*' and rule_char != '_') {
        return ParseError.InvalidSyntax;
    }

    // Count rule characters (allowing spaces between them)
    var char_count: usize = 0;
    while (pos.* < input.len and input[pos.*] != '\n') {
        if (input[pos.*] == rule_char) {
            char_count += 1;
        } else if (input[pos.*] != ' ') {
            // Invalid character
            pos.* = start;
            return ParseError.InvalidSyntax;
        }
        pos.* += 1;
    }

    // Need at least 3 rule characters
    if (char_count < 3) {
        pos.* = start;
        return ParseError.InvalidSyntax;
    }

    // Skip trailing newline if present
    if (pos.* < input.len and input[pos.*] == '\n') {
        pos.* += 1;
    }

    const node = allocator.create(Node) catch return ParseError.OutOfMemory;
    node.* = .{ .horizontal_rule = .{} };
    return node;
}

/// Parses a line break (two trailing spaces or backslash)
pub fn parseLineBreak(input: []const u8, pos: *usize, allocator: std.mem.Allocator) ParseError!*Node {
    if (pos.* >= input.len) {
        return ParseError.InvalidSyntax;
    }

    // Check for backslash followed by newline
    if (input[pos.*] == '\\') {
        if (pos.* + 1 < input.len and input[pos.* + 1] == '\n') {
            pos.* += 2;
            const node = allocator.create(Node) catch return ParseError.OutOfMemory;
            node.* = .{ .line_break = {} };
            return node;
        }
        return ParseError.InvalidSyntax;
    }

    // Check for two or more trailing spaces followed by newline
    if (input[pos.*] == ' ') {
        var space_count: usize = 0;
        while (pos.* + space_count < input.len and input[pos.* + space_count] == ' ') {
            space_count += 1;
        }

        // Need at least 2 spaces
        if (space_count < 2) {
            return ParseError.InvalidSyntax;
        }

        // Must be followed by newline
        if (pos.* + space_count < input.len and input[pos.* + space_count] == '\n') {
            pos.* += space_count + 1;
            const node = allocator.create(Node) catch return ParseError.OutOfMemory;
            node.* = .{ .line_break = {} };
            return node;
        }

        return ParseError.InvalidSyntax;
    }

    return ParseError.InvalidSyntax;
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

test "parseDocument - empty input" {
    const allocator = std.testing.allocator;
    const input = "";
    const doc = try parseDocument(input, allocator);
    try std.testing.expect(doc.* == .document);
    try std.testing.expectEqual(@as(usize, 0), doc.document.children.len);
}

test "parseDocument - multiple blocks" {
    const allocator = std.testing.allocator;
    const input = "# Heading\n\nParagraph text.\n\n- list item";
    const doc = try parseDocument(input, allocator);
    try std.testing.expect(doc.* == .document);
    try std.testing.expectEqual(@as(usize, 3), doc.document.children.len);
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

test "parseHeading - level 6 max" {
    const allocator = std.testing.allocator;
    const input = "###### Smallest heading";
    var pos: usize = 0;
    const node = try parseHeading(input, &pos, allocator);
    try std.testing.expect(node.* == .heading);
    try std.testing.expectEqual(@as(u8, 6), node.heading.level);
}

test "parseHeading - level 7 invalid" {
    const allocator = std.testing.allocator;
    const input = "####### Too many";
    var pos: usize = 0;
    const result = parseHeading(input, &pos, allocator);
    try std.testing.expectError(ParseError.InvalidSyntax, result);
}

test "parseHeading - no space after hash" {
    const allocator = std.testing.allocator;
    const input = "#NoSpace";
    var pos: usize = 0;
    const result = parseHeading(input, &pos, allocator);
    try std.testing.expectError(ParseError.InvalidSyntax, result);
}

test "parseHeading - with inline bold" {
    const allocator = std.testing.allocator;
    const input = "# Hello **world**";
    var pos: usize = 0;
    const node = try parseHeading(input, &pos, allocator);
    try std.testing.expect(node.* == .heading);
    try std.testing.expect(node.heading.children.len > 0);
}

test "parseParagraph - simple text" {
    const allocator = std.testing.allocator;
    const input = "This is a paragraph.";
    var pos: usize = 0;
    const node = try parseParagraph(input, &pos, allocator);
    try std.testing.expect(node.* == .paragraph);
}

test "parseParagraph - multi-line" {
    const allocator = std.testing.allocator;
    const input = "First line\nSecond line\n\nNext paragraph";
    var pos: usize = 0;
    const node = try parseParagraph(input, &pos, allocator);
    try std.testing.expect(node.* == .paragraph);
    // Should stop at empty line
    try std.testing.expect(pos < input.len);
}

test "parseParagraph - with inline formatting" {
    const allocator = std.testing.allocator;
    const input = "Text with **bold** and *italic*.";
    var pos: usize = 0;
    const node = try parseParagraph(input, &pos, allocator);
    try std.testing.expect(node.* == .paragraph);
    try std.testing.expect(node.paragraph.children.len > 1);
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

test "parseText - escaped asterisk" {
    const allocator = std.testing.allocator;
    const input = "not \\*italic\\*";
    var pos: usize = 0;
    const node = try parseText(input, &pos, allocator);
    try std.testing.expect(node.* == .text);
    try std.testing.expectEqualStrings("not *italic*", node.text.value);
}

test "parseText - stops at link bracket" {
    const allocator = std.testing.allocator;
    const input = "click [here](url)";
    var pos: usize = 0;
    const node = try parseText(input, &pos, allocator);
    try std.testing.expect(node.* == .text);
    try std.testing.expectEqualStrings("click ", node.text.value);
}

test "parseText - stops at image exclamation" {
    const allocator = std.testing.allocator;
    const input = "see ![alt](img)";
    var pos: usize = 0;
    const node = try parseText(input, &pos, allocator);
    try std.testing.expect(node.* == .text);
    try std.testing.expectEqualStrings("see ", node.text.value);
}

test "parseText - stops at backtick" {
    const allocator = std.testing.allocator;
    const input = "run `code`";
    var pos: usize = 0;
    const node = try parseText(input, &pos, allocator);
    try std.testing.expect(node.* == .text);
    try std.testing.expectEqualStrings("run ", node.text.value);
}

test "parseBlockquote - simple" {
    const allocator = std.testing.allocator;
    const input = "> This is a quote";
    var pos: usize = 0;
    const node = try parseBlockquote(input, &pos, allocator);
    try std.testing.expect(node.* == .blockquote);
}

test "parseBlockquote - multi-line" {
    const allocator = std.testing.allocator;
    const input = "> Line one\n> Line two\n> Line three";
    var pos: usize = 0;
    const node = try parseBlockquote(input, &pos, allocator);
    try std.testing.expect(node.* == .blockquote);
}

test "parseBlockquote - nested" {
    const allocator = std.testing.allocator;
    const input = "> Outer\n>> Nested";
    var pos: usize = 0;
    const node = try parseBlockquote(input, &pos, allocator);
    try std.testing.expect(node.* == .blockquote);
    // Should contain another blockquote as child
}

test "parseList - unordered with dash" {
    const allocator = std.testing.allocator;
    const input = "- item 1\n- item 2";
    var pos: usize = 0;
    const node = try parseList(input, &pos, allocator);
    try std.testing.expect(node.* == .list);
    try std.testing.expectEqual(false, node.list.ordered);
    try std.testing.expectEqual(@as(u8, '-'), node.list.marker);
}

test "parseList - ordered" {
    const allocator = std.testing.allocator;
    const input = "1. first\n2. second";
    var pos: usize = 0;
    const node = try parseList(input, &pos, allocator);
    try std.testing.expect(node.* == .list);
    try std.testing.expectEqual(true, node.list.ordered);
}

test "parseList - unordered with asterisk" {
    const allocator = std.testing.allocator;
    const input = "* item one\n* item two";
    var pos: usize = 0;
    const node = try parseList(input, &pos, allocator);
    try std.testing.expect(node.* == .list);
    try std.testing.expectEqual(false, node.list.ordered);
    try std.testing.expectEqual(@as(u8, '*'), node.list.marker);
}

test "parseList - unordered with plus" {
    const allocator = std.testing.allocator;
    const input = "+ item one\n+ item two";
    var pos: usize = 0;
    const node = try parseList(input, &pos, allocator);
    try std.testing.expect(node.* == .list);
    try std.testing.expectEqual(false, node.list.ordered);
    try std.testing.expectEqual(@as(u8, '+'), node.list.marker);
}

test "parseList - nested" {
    const allocator = std.testing.allocator;
    const input = "- item 1\n    - nested item\n- item 2";
    var pos: usize = 0;
    const node = try parseList(input, &pos, allocator);
    try std.testing.expect(node.* == .list);
}

test "parseList - single item" {
    const allocator = std.testing.allocator;
    const input = "- only one";
    var pos: usize = 0;
    const node = try parseList(input, &pos, allocator);
    try std.testing.expect(node.* == .list);
    try std.testing.expectEqual(@as(usize, 1), node.list.children.len);
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

test "parseCode - empty" {
    const allocator = std.testing.allocator;
    const input = "``";
    var pos: usize = 0;
    const node = try parseCode(input, &pos, allocator);
    try std.testing.expect(node.* == .code);
    try std.testing.expectEqualStrings("", node.code.value);
}

test "parseCode - unclosed backtick" {
    const allocator = std.testing.allocator;
    const input = "`unclosed";
    var pos: usize = 0;
    const result = parseCode(input, &pos, allocator);
    try std.testing.expectError(ParseError.UnexpectedEndOfInput, result);
}

test "parseInlineBold - simple" {
    const allocator = std.testing.allocator;
    const input = "**bold text**";
    var pos: usize = 0;
    const node = try parseInlineBold(input, &pos, allocator);
    try std.testing.expect(node.* == .inline_bold);
}

test "parseInlineBold - nested italic" {
    const allocator = std.testing.allocator;
    const input = "**bold and *italic* text**";
    var pos: usize = 0;
    const node = try parseInlineBold(input, &pos, allocator);
    try std.testing.expect(node.* == .inline_bold);
    try std.testing.expect(node.inline_bold.children.len > 1);
}

test "parseInlineBold - unclosed" {
    const allocator = std.testing.allocator;
    const input = "**unclosed bold";
    var pos: usize = 0;
    const result = parseInlineBold(input, &pos, allocator);
    try std.testing.expectError(ParseError.UnexpectedEndOfInput, result);
}

test "parseInlineBold - empty" {
    const allocator = std.testing.allocator;
    const input = "****";
    var pos: usize = 0;
    const node = try parseInlineBold(input, &pos, allocator);
    try std.testing.expect(node.* == .inline_bold);
    try std.testing.expectEqual(@as(usize, 0), node.inline_bold.children.len);
}

test "parseInlineItalics - simple" {
    const allocator = std.testing.allocator;
    const input = "*italic text*";
    var pos: usize = 0;
    const node = try parseInlineItalics(input, &pos, allocator);
    try std.testing.expect(node.* == .inline_italics);
}

test "parseInlineItalics - unclosed" {
    const allocator = std.testing.allocator;
    const input = "*unclosed italic";
    var pos: usize = 0;
    const result = parseInlineItalics(input, &pos, allocator);
    try std.testing.expectError(ParseError.UnexpectedEndOfInput, result);
}

test "parseInlineItalics - not bold" {
    const allocator = std.testing.allocator;
    const input = "*single asterisk*";
    var pos: usize = 0;
    const node = try parseInlineItalics(input, &pos, allocator);
    try std.testing.expect(node.* == .inline_italics);
    // Ensure it's italic, not bold
    try std.testing.expect(node.* != .inline_bold);
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

test "parseImage - no title is null" {
    const allocator = std.testing.allocator;
    const input = "![alt](image.png)";
    var pos: usize = 0;
    const node = try parseImage(input, &pos, allocator);
    try std.testing.expect(node.* == .image);
    try std.testing.expect(node.image.title == null);
}

test "parseImage - empty alt" {
    const allocator = std.testing.allocator;
    const input = "![](image.png)";
    var pos: usize = 0;
    const node = try parseImage(input, &pos, allocator);
    try std.testing.expect(node.* == .image);
    try std.testing.expectEqualStrings("", node.image.alt);
}

test "parseImage - malformed missing paren" {
    const allocator = std.testing.allocator;
    const input = "![alt]no paren";
    var pos: usize = 0;
    const result = parseImage(input, &pos, allocator);
    try std.testing.expectError(ParseError.InvalidSyntax, result);
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

test "parseLink - no title is null" {
    const allocator = std.testing.allocator;
    const input = "[text](url.com)";
    var pos: usize = 0;
    const node = try parseLink(input, &pos, allocator);
    try std.testing.expect(node.* == .link);
    try std.testing.expect(node.link.title == null);
}

test "parseLink - malformed no paren after bracket" {
    const allocator = std.testing.allocator;
    const input = "[text] not a link";
    var pos: usize = 0;
    const result = parseLink(input, &pos, allocator);
    // Should return error or treat as plain text
    try std.testing.expectError(ParseError.InvalidSyntax, result);
}

test "parseLink - with inline formatting in text" {
    const allocator = std.testing.allocator;
    const input = "[**bold** link](url.com)";
    var pos: usize = 0;
    const node = try parseLink(input, &pos, allocator);
    try std.testing.expect(node.* == .link);
    try std.testing.expect(node.link.children.len > 0);
}

test "parseLink - empty text" {
    const allocator = std.testing.allocator;
    const input = "[](url.com)";
    var pos: usize = 0;
    const node = try parseLink(input, &pos, allocator);
    try std.testing.expect(node.* == .link);
    try std.testing.expectEqual(@as(usize, 0), node.link.children.len);
}

test "parseCodeBlock - with language" {
    const allocator = std.testing.allocator;
    const input = "```zig\nconst x = 1;\n```";
    var pos: usize = 0;
    const node = try parseCodeBlock(input, &pos, allocator);
    try std.testing.expect(node.* == .code_block);
    try std.testing.expectEqualStrings("zig", node.code_block.language.?);
    try std.testing.expectEqualStrings("const x = 1;\n", node.code_block.value);
}

test "parseCodeBlock - without language" {
    const allocator = std.testing.allocator;
    const input = "```\nsome code\n```";
    var pos: usize = 0;
    const node = try parseCodeBlock(input, &pos, allocator);
    try std.testing.expect(node.* == .code_block);
    try std.testing.expect(node.code_block.language == null);
}

test "parseCodeBlock - tilde fence" {
    const allocator = std.testing.allocator;
    const input = "~~~python\nprint('hello')\n~~~";
    var pos: usize = 0;
    const node = try parseCodeBlock(input, &pos, allocator);
    try std.testing.expect(node.* == .code_block);
    try std.testing.expectEqualStrings("python", node.code_block.language.?);
}

test "parseCodeBlock - unclosed" {
    const allocator = std.testing.allocator;
    const input = "```\nunclosed code block";
    var pos: usize = 0;
    const result = parseCodeBlock(input, &pos, allocator);
    try std.testing.expectError(ParseError.UnexpectedEndOfInput, result);
}

test "parseCodeBlock - empty" {
    const allocator = std.testing.allocator;
    const input = "```\n```";
    var pos: usize = 0;
    const node = try parseCodeBlock(input, &pos, allocator);
    try std.testing.expect(node.* == .code_block);
    try std.testing.expectEqualStrings("", node.code_block.value);
}

test "parseHorizontalRule - dashes" {
    const allocator = std.testing.allocator;
    const input = "---";
    var pos: usize = 0;
    const node = try parseHorizontalRule(input, &pos, allocator);
    try std.testing.expect(node.* == .horizontal_rule);
}

test "parseHorizontalRule - asterisks" {
    const allocator = std.testing.allocator;
    const input = "***";
    var pos: usize = 0;
    const node = try parseHorizontalRule(input, &pos, allocator);
    try std.testing.expect(node.* == .horizontal_rule);
}

test "parseHorizontalRule - underscores" {
    const allocator = std.testing.allocator;
    const input = "___";
    var pos: usize = 0;
    const node = try parseHorizontalRule(input, &pos, allocator);
    try std.testing.expect(node.* == .horizontal_rule);
}

test "parseHorizontalRule - with spaces" {
    const allocator = std.testing.allocator;
    const input = "- - -";
    var pos: usize = 0;
    const node = try parseHorizontalRule(input, &pos, allocator);
    try std.testing.expect(node.* == .horizontal_rule);
}

test "parseHorizontalRule - more than three" {
    const allocator = std.testing.allocator;
    const input = "----------";
    var pos: usize = 0;
    const node = try parseHorizontalRule(input, &pos, allocator);
    try std.testing.expect(node.* == .horizontal_rule);
}

test "parseHorizontalRule - too few" {
    const allocator = std.testing.allocator;
    const input = "--";
    var pos: usize = 0;
    const result = parseHorizontalRule(input, &pos, allocator);
    try std.testing.expectError(ParseError.InvalidSyntax, result);
}

test "parseLineBreak - trailing spaces" {
    const allocator = std.testing.allocator;
    const input = "text  \n";
    var pos: usize = 4; // position at the two spaces
    const node = try parseLineBreak(input, &pos, allocator);
    try std.testing.expect(node.* == .line_break);
}

test "parseLineBreak - backslash" {
    const allocator = std.testing.allocator;
    const input = "text\\\n";
    var pos: usize = 4; // position at backslash
    const node = try parseLineBreak(input, &pos, allocator);
    try std.testing.expect(node.* == .line_break);
}

test "parseLineBreak - single space not a break" {
    const allocator = std.testing.allocator;
    const input = "text \nnext";
    var pos: usize = 4; // position at single space
    const result = parseLineBreak(input, &pos, allocator);
    try std.testing.expectError(ParseError.InvalidSyntax, result);
}

test "parseLineBreak - three spaces" {
    const allocator = std.testing.allocator;
    const input = "text   \n";
    var pos: usize = 4; // position at spaces
    const node = try parseLineBreak(input, &pos, allocator);
    try std.testing.expect(node.* == .line_break);
}
