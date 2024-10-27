pub fn reverse(comptime T: type, slice: []T) void {
    var left: usize = 0;
    var right: usize = slice.len - 1;
    while (left < right) {
        const temp = slice[left];
        slice[left] = slice[right];
        slice[right] = temp;
        left += 1;
        right -= 1;
    }
}
