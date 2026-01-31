## Markdown to HTML

### Backend

I am planning to create a Markdown to Html program in Zig.
The project is conceptualized in 2 stages, Frontend and Backend, as most code translation/compilation like projects are.
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
    inline_bold: InlineBold,
    inline_italics: InlineItalics,
    image: Image,
    link: Link,
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
    marker: u8, // '-', '*', or '+'
    children: []const *Node, // list items
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
    - Determine how many pound sign follow and record in level of the heading struct. There a 6 possible levels of indentation. Consider all following text as the text for bold text.
    - Once a `space` character is found, record the remaining text in a `[]const u8` slice in the children of the Heading struct. (resuling in a slice of a slice)
- \> (right angle bracket used for blockquote)
    - Once a blockquote starts, scan all the lines followed by this line until an empty line is discovered. An empty line is a newline followed by another new line. Ignore whitespace between the 2 newlines
    - If an indent (tab or 4 spaces) is encountered, create a `Node`, push this node in the children of blockquote and recursively start the parser operation.
- \-, \*, \+ (list item)
    - Once any of the list item characters are encountered, record it as the current list item character and scan all the remaining lines until a space is found or a different list element is found.
    - if an indent is found close the current Node by putting it in the children of the parent node, create a new node and recursively start a new parser operation
- \` (tick / code)
    - This is an inline markdown syntax, which means close the current text node by entering it into parent children array and starta new `Tick` node.
    - Check if a tick is followed by another tick.
        - if yes, ignore all following single instances of tick as markdown syntax and treat them as escaped. continue to parse until double tick is encountered.
        - if no, create a text node from the following string until anoter tick is encountered.
- \*\* bold, two consecutive asterix
    - This is an inline markdown syntax, which means close the current text node by entering it into parent children array and starta new `InlineBold` node.
    - Start a recursive parser operation to parse the text until the end of `InlineBold`.
    - Once another 2 consecutive asterix are found close the current `InlineBold` node by putting it in the children of the parent.
- \* single asterix
    - This is an inline markdown syntax, which means close the current text node by entering it into parent children array and starta new `InlineItalics` node.
    - Start a recursive parser operation to parse the text until the end of `InlineBold`.
    - Once another 2 consecutive asterix are found close the current `InlineItalics` node by putting it in the children of the parent.
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

### Frontend

Once we have an AST convert it to html with a render function like:
```
fn renderHtml(node: *const Node, writer: anytype) !void {
    switch (node.*) {
        .document => |doc| {
            for (doc.children) |child| {
                try renderHtml(child, writer);
            }
        },
        .heading => |h| {
            try writer.print("<h{}>", .{h.level});
            for (h.children) |child| {
                try renderHtml(child, writer);
            }
            try writer.print("</h{}>", .{h.level});
        },
        .paragraph => |p| {
            try writer.writeAll("<p>");
            for (p.children) |child| {
                try renderHtml(child, writer);
            }
            try writer.writeAll("</p>");
        },
        .text => |t| {
            try writer.writeAll(t.value);
        },
    }
}
```
