module minimal.error.type;

import std.logger : infof, warningf, errorf, criticalf;
import std.stdio : writef;

enum ErrorLevel {
    OK,
    Info,
    Warning,
    Error,
    Critical,
}

struct TContext {
    ulong  line   = 0;
    ulong  column = 0;
    string file   = "<none>";
}

struct TError {
    ErrorLevel level   = ErrorLevel.OK;
    string     message = "OK";
    ulong      code    = 0;
    TContext   context;
    bool       catchable;
    bool       resolved;
}

template BaseError (string name, uint code, ErrorLevel lv) {
    protected:
    string _message_;

    public:
    this(string message) {
        this._message_ = message;
    }

}

interface IError {
    bool catchable();

    void raise();
    bool trycatch(bool delegate(TError) dg);
    void nocatch();

    T opCast(T: bool)     () const;
    T opCast(T: TError)   () const;
    T opCast(T: TContext) () const;
}

alias TErrorList = TError[];
alias IErrorList = IError[];
