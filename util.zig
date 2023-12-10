export fn __aeabi_memset(s: [*]u8, c: u8, n: usize) [*]u8 {
    for (0..n) |i| {
        s[i] = c;
    }
    return s;
}
export fn __aeabi_memclr(s: [*]u8, n: usize) [*]u8 {
    for (0..n) |i| {
        s[i] = 0;
    }
    return s;
}

export fn __aeabi_memcpy(dest: [*]u8, src: [*]u8, n: usize) [*]u8 {
    for (0..n) |i| {
        dest[i] = src[i];
    }
    return dest;
}

export fn __aeabi_memcpy4(dest: [*]u8, src: [*]u8, n: usize) [*]u8 {
    for (0..n) |i| {
        dest[i] = src[i];
    }
    return dest;
}
