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
