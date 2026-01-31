pub const Node = union(enum) {
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

pub const Document = struct {
    children: []const *Node,
};

pub const Heading = struct {
    level: u8,
    children: []const *Node,
};

pub const Paragraph = struct {
    children: []const *Node,
};

pub const Text = struct {
    value: []const u8,
};

pub const Blockquote = struct {
    children: []const *Node,
};

pub const List = struct {
    marker: u8,
    children: []const *Node,
};

pub const ListItem = struct {
    children: []const *Node,
};

pub const Code = struct {
    value: []const u8,
};

pub const InlineBold = struct {
    children: []const *Node,
};

pub const InlineItalics = struct {
    children: []const *Node,
};

pub const Image = struct {
    alt: []const u8,
    src: []const u8,
    title: ?[]const u8,
};

pub const Link = struct {
    children: []const *Node,
    href: []const u8,
    title: ?[]const u8,
};
