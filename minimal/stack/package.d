module minimal.stack;

package (minimal) {
    public import minimal.stack.stack : Stack, Size, Index, Entry, MutEntries;
    public import minimal.token.token : Token;
}

debug {
    import std.stdio : writeln;

    int main(string[] args) {
        writeln("[DEBUG]");
        writeln("Not an application.");
        return 0;
    }
}
