module minimal.error.errors;

import minimal.error.type : IError, ErrorLevel, TError, TContext;

const string LOGMESSAGE_FMT              = "%s; at %s:%s in `%s`";
const string ERRMESSAGE_FMT_NONCATCHABLE = "%s  ([%s] %s)";
const string ERRMESSAGE_FMT_CATCHABLE    = "%s  ([%s] %s)";


abstract class ErrorClass (string Name, ErrorLevel Level) : IError
{
    protected:
    TError _error;

    public:
    @disable this();

    this(string message)
    in (message.length > 0) {
        this._error = TError(Level, message, 1, TContext(0, 0, "<none>", true));
    }

    this(string message, uint code)
    in (code > 0, message.length > 0) {
        this._error = TError(Level, message, code, TContext(0, 0, "<none>", true));
    }

    this(string message, uint code, ulong line, ulong column, string file = "<none>", bool catchable = true) {
        this._error = TError(this.Level, message, code, TContext(line, column, file, catchable));
    }

    string     name()  => this.Name;
    ErrorLevel level() => this.Level;

    bool catchable() {
        return this._error.context.catchable;
    }

    string messagef(string fmt) {
        import std.format : format;
        return fmt.format(this._code, this._message);
    }

    string message() {
        return this.messagef("[%s] %s");
    }

    uint code() {
        return this._error._code;
    }

    bool resolved() {
        return this._error.resolved;
    }

    bool trycatch(bool delegate(TError) dg) {
        if (this.catchable && dg(this._error)) {
            import std.logger : warningf;
            warningf(ERRMESSAGE_FMT_CATCHABLE, "Catched", this.code, this.message);
            return true;
        }
        else {
            import std.logger : criticalf;
            criticalf(ERRMESSAGE_FMT_NONCATCHABLE, "Non-Catchable", this.code, this.message);
            return false;
        }
    }

    void nocatch() {
        import std.logger : criticalf;
        criticalf(ERRMESSAGE_FMT_NONCATCHABLE, "Non-Catchable", this.code, this.message);
    }

    T opCast(T: bool)     () const { return this.catchable;      }
    T opCast(T: TError)   () const { return this._error;         }
    T opCast(T: TContext) () const { return this._error.context; }
}
