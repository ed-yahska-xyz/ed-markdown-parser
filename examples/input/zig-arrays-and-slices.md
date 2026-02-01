# Zig Arrays and Slices Guide

This guide summarizes key concepts, syntax, and examples related to handling arrays in Zig, including slices, passing arrays between functions, pointers, 2D arrays, and common use cases.

---

## 1. Fixed-Size Arrays

```zig
const a: [4]i32 = .{1, 2, 3, 4};
```

- `[4]i32` is a value-type array with 4 elements.
- Assigning it copies the entire array.

---

## 2. Slices

```zig
const slice: []const i32 = a[0..];
```

- A slice is a view into an array.
- Slices carry a pointer and length.
- Can be passed efficiently to functions.

Subslices:

```zig
a[1..3]; // elements 1 and 2
```

---

## 3. Passing Arrays and Slices to Functions

Fixed-Size Arrays:

```zig
fn printArray(arr: [4]i32) void { ... } // Copies all elements
```

Slices (Preferred):

```zig
fn printSlice(slice: []const i32) void { ... }
```

---

## 4. Pointers to Arrays

```zig
const ptr: *[4]i32 = &a;
```

Used to avoid copying arrays:

```zig
fn mutate(ptr: *[4]i32) void {
    ptr.*[0] = 42;
}
```

---

## 5. Raw C-style Pointers

```zig
const p: [*]const u8 = "hello";
```

- No length info, no bounds checking.
- Useful for C interop.

---

## 6. Convert Between Array Types

```zig
const a: [4]i32 = .{1, 2, 3, 4};
const slice = a[0..];         // []const i32
const ptr = &a;               // *[4]i32
const raw_ptr = &a[0];        // [*]i32
```

---

## 7. Arena-Allocated Arrays

Fixed-Size 2D Array in Arena:

```zig
const matrix = try allocator.create([4][3]f32);
matrix.* = .{ ... }; // set values
```

Dynamic Outer, Fixed Inner:

```zig
var rows = std.ArrayList([3]f32).init(arena);
try rows.append(.{1.0, 2.0, 3.0});
```

---

## 8. Special Syntax

Convert string literals to slices:

```zig
const s: []u8 = "hello"[0..];
```

Create and reference array with inferred length:

```zig
const parts = &[_][]const u8{ "hello", " ", "zig" };
```

---

## 9. Common Use Cases

Printing a 2D Matrix

```zig
for (matrix.*) |row| {
    for (row) |val| {
        std.debug.print("{} ", .{val});
    }
    std.debug.print("\n", .{});
}
```

Initializing a String Table

```zig
const messages = &[_][]const u8{ "start", "stop", "pause" };
```

Passing Read-Only Data

```zig
fn printAll(msgs: []const []const u8) void {
    for (msgs) |m| std.debug.print("{s}\n", .{m});
}
```

---

## Key Takeaways

- Use `[N]T` when the array size is known and fixed.
- Use `[]T` for flexible, bounds-checked views.
- Use `[*]T` only for raw access or C interop.
- Prefer slices in function arguments.
- Use ArrayList for dynamic-length containers.
- Arena allocators are ideal for temporary or structured allocations.
