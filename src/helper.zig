const std = @import("std");

/// Reads a markdown file from the given path and returns its contents.
/// The returned slice is allocated using the provided allocator.
pub fn readMarkdownFile(path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const stat = try file.stat();
    const content = try allocator.alloc(u8, stat.size);
    const bytes_read = try file.readAll(content);

    return content[0..bytes_read];
}

/// Writes HTML content to the specified output path.
pub fn writeHtmlFile(path: []const u8, content: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    try file.writeAll(content);
}

/// Converts a markdown file path to an HTML output path.
/// Changes the extension from .md to .html and optionally changes the directory.
pub fn mdPathToHtmlPath(
    md_path: []const u8,
    output_dir: []const u8,
    allocator: std.mem.Allocator,
) ![]u8 {
    // Extract the filename from the path
    const basename = std.fs.path.basename(md_path);

    // Remove .md extension if present
    const name_without_ext = if (std.mem.endsWith(u8, basename, ".md"))
        basename[0 .. basename.len - 3]
    else
        basename;

    // Build the output path: output_dir/filename.html
    return std.fmt.allocPrint(allocator, "{s}/{s}.html", .{ output_dir, name_without_ext });
}
