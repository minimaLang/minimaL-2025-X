module minimal.error.errors;

import std.array  : Array;
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

    void raise();
    bool trycatch();
    bool trycatch(bool delegate(IError) dg);
    bool noraise  (bool delegate(IError) dg);
    bool ok();

    uint       code();
    string     message();
    ErrorLevel level();

    string messagef(string fmt);

    T opCast (T: bool)    () const;
    T opCast (T: Context) () const;
    T opCast (T: uint)    () const;
}

alias ContextList = Context[];
alias ErrorList   = BaseError[];

ErrorList list = ErrorList.init;

struct Context
{
    protected:
    string  _name     = "";
    ulong   _line     = 0;
    ulong   _column   = 0;
    ulong   _position = 0;
    string  _file     = "{NONE}";
    IError  _previous;

    this(string name) {
        this._name  = name;
    }

    this(string name, IError previous) {
        this._name     = name;
        this._previous = previous;
    }

    this(string name, IError previous, ulong line, ulong column, ulong position = 0) {
        this(name, previous);
        this._line     = line;
        this._column   = column;
        this._position = position;
    }
}

class BaseError : IError
{
    static import std.stdio;

    protected:
    string     _message;
    uint       _code;
    ErrorLevel _level;
    Context    _context;

    public:
    this(string message, uint code, ErrorLevel level, out Context context) {
        this(message, code, level);
        this._context = Context("{Error}");
        context = this._context;
    }

    this(string message, uint code, ErrorLevel level) {
        this._message = message;
        this._code    = code;
        this._level   = level;
    }

    immutable(IError) previous()  => this._context.previous;
    bool              catchable() => this._context.catchable;

    void raise() {
        throw new Exception("[%s] %s".format(this._code, this._message);
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

    bool noraise(bool delegate(IError) dg) nothrow {
        return dg(this);
    }

    bool ok() {
        return (this.level == ErrorLevel.OK);
    }

    uint       code();
    string     message();
    ErrorLevel level();

    string messagef(string fmt);

    T opCast (T: bool)    () const;
    T opCast (T: Context) () const;
    T opCast (T: uint)    () const;
}

final class NoError : IError
{
    public:
    this(string message, Context context) {
        super(message, 0, ErrorLevel.OK, context);
    }

    this() {}

    immutable(IError) previous()            => cast(immutable) this;
    bool catchable()                        => true;
    bool ok()                               => true;
    bool trycatch()                         => true;
    bool trycatch(bool delegate(IError) dg) => true;

    void raise() {
        debug writeln("{ NoError.raise   }");
    }

    void noraise() nothrow {
        debug writeln("{ NoError.nocatch }");
    }

    string     message() => this._message_;
    uint       code()    => this._code_;
    ErrorLevel level()   => this._level_;

    string messagef(string fmt) {
        return fmt.format(this.code, this.message);
    }

    T opCast(T: bool)      () const => this.catchable;
    T opCast(T: Context)   () const => this._context_;
    T opCast(T: uint)      () const => this._code_;
    T opCast(T: BaseError) () const => new BaseError(this.level, this.message, this.code);
}

class BaseError : IError
{
    public import std.logger : FileLogger;

    private:
    FileLogger _logger_   = new FileLogger("Errors.log");
    Context    _context_;

    protected:
    ErrorLevel _level_     = ErrorLevel.OK;
    string     _message_   = "OK";
    uint       _code_      = 0;
    bool       _catchable_ = false;
    bool       _resolved_  = false;

    public:
    this(ErrorLevel lv, string message, uint code, ulong line, ulong column, ulong position = 0, string file = "{NONE}", IError prev = new NoError()) {
        this.setup(lv, message, code, line, column, position, file, prev);
        .list.insertFront(this);
    }

    this(string message, uint code, ulong line, ulong column, ulong position = 0, string file = "{NONE}", IError prev = new NoError()) {
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

        this.setup(lv, message, code, line, column, position, file);
        this._previous_ = prev;
        .list.insertBack(this);
    }

    void replaceLogfile(string file)
    in (isValidPath(asRelative(file))) {
        string path   = buildNormalizedPath(getcwd, asRelative(file));
        this._logger_ = new shared FileLogger(path);
    }

    void log() {
        switch (this._level_) {
            case ErrorLevel.OK:       break;
            case ErrorLevel.Info:     this._logger_.info(this.message);     break;
            case ErrorLevel.Warning:  this._logger_.warning(this.message);  break;
            case ErrorLevel.Error:    this._logger_.error(this.message);    break;
            case ErrorLevel.Critical: this._logger_.critical(this.message); break;
            default:                  this._logger_.log(this._message_);
        }
    }

    immutable(FileLogger) logger()   => cast(immutable) this._logger_;
    immutable(IError)     previous() => cast(immutable) this._previous_;

    bool catchable()
    in (this._level_ != ErrorLevel.OK) {
        return (this._level_ != ErrorLevel.Critical);
    }

    void raise()
    in (this._level_ != ErrorLevel.OK) {
        if(!catchable) this.nocatch();
    }

    bool trycatch()
    in (this._level_ != ErrorLevel.OK) {
        if(this.catchable) return true;
        this.raise();
        return false;
    }

    bool trycatch(bool delegate(IError) dg) {
        if(this.catchable) return true;
        return dg(this);
    }

    void nocatch()
    in (this._level_ != ErrorLevel.OK) {
        import std.format : format;
        string message = "[%s]: %s".format(this._code_, this._message_);
        throw new Exception(message);
    }

    bool ok() => (this._level_ == ErrorLevel.OK);

    string message() {
        return this.messagef("[%s] %s");
    }

    string messagef(string fmt) {
        return fmt.format(cast(string) this.code, this.message);
    }

    uint    code    () const => this._code_;
    Context context () const => this._context_;

    T opCast(T: bool)    () const => this.catchable;
    T opCast(T: Context) () const => this._context_;
    T opCast(T: uint)    () const => this._code_;

    private void setup(ErrorLevel lv, string message, uint code, ulong line, ulong column, ulong position = 0, string file = "{NONE}") pure {
        this._level_   = lv;
        this._message_ = message;
        this._code_    = code;
        this._context_ = Context(line, column, position, file, this);
    }
}
