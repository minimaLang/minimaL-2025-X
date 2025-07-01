module minimal.error.manager;

import minimal.error.type : ErrorLevel, TErrorList, IErrorList, TError;
import minimal.error.type : IError;

template Manager (string name, ErrorLevel minlv, ErrorLevel maxlv)
{
    private:
    IErrorList _list_;

    public:
    this () {}
    this (IErrorList list) { this._list_ = list; }

    immutable(IErrorList) list() {
        return cast(immutable) this._list_;
    }

    void add(IError error)
    in (error.level >= minlv && error.level < maxlv)
    {
        this._list_ ~= error;
    }

    void resolve(bool delegate(TError) dg) {
        foreach (TError e; this._list_) {
            if(e.catchable && dg(e)) continue;
            //
        }
    }
}

final class InputErrorManager : Manager!("Input",   ErrorLevel.Warning, ErrorLevel.Error) {}
final class ParseErrorManager : Manager!("Parsing", ErrorLevel.Warning, ErrorLevel.Error) {}
