module minimal.io.io;

struct Directory {
    const string      path;
    const File[]      files;
    const Directory[] directories;
}

struct File {
private {
    void[] buffer;
    bool exists = false;
    bool open   = false;
}
    const string directory;
    const string name;
    const size_t size;
    Exception exc;

    const(string) getFullPath() const {
        import std.path : buildPath, asAbsolutePath;
        return asAbsolutePath(buildPath([directory, name]));
    }

    auto readText() @cache {
        import std.file : readText;
        return readText(this.getFullPath());
    }

    auto write() {
        if (this.buffer.length == 0) return 0;
        import std.file : write;
        write(this.getFullPath(), buffer);
        return buffer.length;
    }

    bool exists() {
        import std.file : exists;
        return exists(this.getFullPath());
    }

    const close() {
        this.open = false;
        this.exc  = null;
    }
}

class IO {
private {
    import std.mmfile : MmFile;
    import std.file;

    const MmFile mmf;
          File   current_file;
}

    void open(File file) {
        if (current_file is File || current_file.open) {
            current_file.close();
        }

        current_file = file;
        current_file.open = current_file.exists();

    }

}
