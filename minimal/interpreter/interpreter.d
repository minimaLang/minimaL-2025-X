module minimal.interpreter;

import minimal;
import minimal.token.common;

class InterpreterFile {
    import std.mmfile : MmFile;

    const HEADER = "@minimal[" ~ VERSION ~ "]@";

private {
    const MmFile _file;
    const string _name;
}

    this(){
        this("_intrpt_");
    }

    this(string name) {
        this._ensureFileExists(name);
        this._name = name;
        this._file = new MmFile(name);
    }

private {
    import std.file : write, read, exists, getSize, FileException;

    void _ensureFileExists(string name) {
        if (!exists(name)) {
            const void*[] buffer = cast(void*[]) [HEADER, "\n"];
            try {
                write(name, buffer);
            }
            catch (FileException exc) {
                throw new Error(exc.msg, exc);
            }
        }
    }

    bool _isHeader(string str) {
        import std.string;
        import std.stdio;

        str = strip(str);
        const ptrdiff_t first = indexOf(str, '@', 0);
        const ptrdiff_t last  = lastIndexOf(str, '@');

        writeln(str[first..last]);
        return str[first..last] == HEADER;
    }
}

    void read(string name) {
        void[] data_read;

        import std.file : fread = read;
        import std.stdio;

        try {
            data_read = fread(name, getSize(name));
            writeln(data_read);
        }
        catch (FileException exc) {
            throw new Error(exc.msg, exc);
        }

        while (data_read != null) {
            if (data_read != "@") {
                data_read = null;
                continue;
            }
        }
    }
}

struct InterpretationResult {
    Token[] consumed;
    Token[] unconsumed;
    bool    failed;
}

class Interpreter {
private {
    InterpretationResult _result;
    const Token[]        _to_be;
}

    int run() const {
        return 0;
    }

    bool done() {
        return this._result.consumed.length == this._result.unconsumed.length;
    }
}
