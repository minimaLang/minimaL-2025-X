module minimal.error.errors;

import std.array  : array;
import std.path   : isValidPath, asRelativePath, asAbsolutePath;
import std.format : format;

enum ErrorLevel {
    OK,
    Info,
    Warning,
    Error,
    Critical,
}

interface IError
{
    immutable(IError) previous();
    bool              catchable();

    void raise    ();
    bool trycatch (bool delegate(IError) dg);
    bool noraise  (bool delegate(IError) nothrow dg) nothrow;
    bool ok       ();

    uint       code    ();
    string     message ();
    ErrorLevel level   ();

    string messagef(string fmt);

    T opCast (T: bool)    () const;
    T opCast (T: Context) () const;
    T opCast (T: uint)    () const;
}

alias ContextList = Context[];
alias ErrorList   = IError[];

ErrorList __list = ErrorList.init;

void __addToList(IError error) {
    .__list ~= error;
}

struct Context
{
    protected:
    string  _name     = "";
    ulong   _line     = 0;
    ulong   _column   = 0;
    ulong   _position = 0;
    string  _file     = "{NONE}";
    string  _string   = "";

    bool   _catchable;
    IError _previous;

    public:
    this(string name, string file = "{NONE}") {
        this._name   = name;
        this._file   = file;
        this._string = this._name ~ ":" ~ this._file;
    }

    this(string name, string file, IError previous) {
        this(name, file);
        this._previous = previous;
    }

    this(string name, IError previous, ulong line, ulong column, ulong position = 0)
    in {
        assert(name.length > 0);
    } do {
        line   = line   ? (line   > 0) : 1;
        column = column ? (column > 0) : 1;

        this(name, "{NONE}", previous);
        this._line     = line   ? (line   > 0) : 1;
        this._column   = column ? (column > 0) : 1;
        this._position = position;
    }

    void set(ulong line, ulong column, ulong position) {
        this._line     = line;
        this._column   = column;
        this._position = position;
    }

    IError previous()  => this._previous;
    bool   catchable() => this._catchable;

    ulong  line()     => this._line;
    ulong  column()   => this._column;
    ulong  position() => this._position;
    string name()     => this._name;
    string file()     => this._file;

    string toString() const => this._string;
    long   toHash()   const => hashOf(this._string);
}

class BaseError : IError
{
    static import std.stdio;

    protected:
    string     _message;
    uint       _code;
    ErrorLevel _level;
    Context    _context;

    void _addToList() {
        .__list ~= this;
    }

    public:
    this(string message, uint code, ErrorLevel level, out Context context) {
        this(message, code, level);
        this._context = Context("{Error}");
        context = this._context;
        this._addToList();
    }

    this(string message, uint code, ErrorLevel level) {
        this._message = message;
        this._code    = code;
        this._level   = level;
        this._addToList();
    }

    immutable(IError) previous()  => cast(immutable) this._context.previous;
    bool              catchable() => this._context.catchable;

    void raise() {
        throw new Exception("[%s] %s".format(this._code, this._message));
    }

    bool trycatch() {
        bool ok = (this.level == ErrorLevel.OK);
        if (!ok) {
            this.raise();
            return ok;
        }
        return ok;
    }

    bool trycatch(bool delegate(IError) dg) {
        bool ok = (this.level == ErrorLevel.OK);
        if (!ok) return dg(this);
        return ok;
    }

    bool noraise(bool delegate(IError) nothrow dg) nothrow {
        return dg(this);
    }

    bool ok() {
        return (this.level == ErrorLevel.OK);
    }

    uint       code()    => this._code;
    string     message() => this._message;
    ErrorLevel level()   => this._level;

    string messagef(string fmt) => fmt.format(this._code, this._message);

    T opCast (T: bool)    () const => this._catchable;
    T opCast (T: Context) () const => this._context;
    T opCast (T: uint)    () const => this._code;
}

ErrorLevel levelByCode (uint code) {
    ErrorLevel lv;

    switch (code) {
        case 0:
            lv = ErrorLevel.OK;
            break;
        case 1, 2:
            lv = ErrorLevel.Info;
            break;
        case 3, 4, 5:
            lv = ErrorLevel.Warning;
            break;
        case 6, 7, 8, 9, 10:
            lv = ErrorLevel.Error;
            break;
        default:
            lv = ErrorLevel.Critical;
    }
    return lv;
}

final class NoError : IError
{
    private:
    string  _message_;
    Context _context_;

    public:
    this(string message, Context context) {
        this._message_ = message;
        this._context_ = context;
        this.__addToList();
    }

    this() {
        this.__addToList();
    }

    immutable(IError) previous()            => cast(immutable) this;
    bool catchable()                        => true;
    bool ok()                               => true;
    bool trycatch()                         => true;
    bool trycatch(bool delegate(IError) dg) => true;

    void raise() {
        debug {
            import std.stdio;
            writeln("{NoError.raise}");
        }
    }

    bool noraise(bool delegate(IError) nothrow dg) {
        debug {
            import std.stdio;
            writeln("{NoError.noraise}");
        }
        return true;
    }

    string     message () => this._message_;
    uint       code    () => 0;
    ErrorLevel level   () => ErrorLevel.OK;

    string messagef(string fmt) {
        return fmt.format(0, this.message);
    }

    T opCast(T: bool)      () const => this.catchable;
    T opCast(T: Context)   () const => this._context_;
    T opCast(T: uint)      () const => this._code_;
    T opCast(T: BaseError) () const => new BaseError(this.level, this.message, this.code);
}
