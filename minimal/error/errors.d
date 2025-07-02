module minimal.error.errors;

import std.container.array : Array;
import std.path : isValidPath, asRelativePath, asAbsolutePath;

enum ErrorLevel {
    OK,
    Info,
    Warning,
    Error,
    Critical,
}

interface IError
{
    IError previous();
    bool   catchable();

    void raise();
    bool trycatch();
    bool trycatch(bool delegate(IError) dg);
    void nocatch();
    bool ok();

    uint   code();
    string message();
    string messagef(string fmt);

    T opCast(T: bool)    () const;
    T opCast(T: Context) () const;
    T opCast(T: uint)    () const;
}

alias ErrorList   = Array!BaseError;
alias ContextList = Array!Context;

ErrorList list = ErrorList();

struct Context
{
    ulong     line     = 0;
    ulong     column   = 0;
    ulong     position = 0;
    string    file     = "{NONE}";
    BaseError error;
}

final class NoError : IError
{
    static import std.stdio;

    this() {};

    immutable(IError) previous()            => this;
    bool catchable()                        => true;
    bool ok()                               => true;
    bool trycatch()                         => true;
    bool trycatch(bool delegate(IError) dg) => true;

    void raise()   { debug writeln("{ NoError.raise   }"); }
    void nocatch() { debug writeln("{ NoError.nocatch }"); }

    T opCast(T: bool)      () const => this.catchable;
    T opCast(T: Context)   () const => this._context_;
    T opCast(T: uint)      () const => this._code_;
    T opCast(T: BaseError) () const => new BaseError(ErrorLevel.OK, "No error", 0, 0, 0, 0);
}

final class BaseError : IError
{
    public import std.logger : FileLogger;

    private:
    FileLogger _logger_   = new FileLogger("Errors.log");
    IError     _previous_ = new NoError();
    Context    _context_;

    ErrorLevel _level_     = ErrorLevel.OK;
    string     _message_   = "OK";
    uint       _code_      = 0;
    bool       _catchable_ = false;
    bool       _resolved_  = false;

    public:
    this(ErrorLevel lv, string message, uint code, ulong line, ulong column, ulong position = 0, string file = "{NONE}", IError prev = new NoError()) {
        this.setup(lv, message, code, line, column, position, file);
        this._previous_ = prev;
        .list.insertBack(this);
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
