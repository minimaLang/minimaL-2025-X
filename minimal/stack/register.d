module minimal.stack.register;

import std.container.slist : SList;
import std.format : format;
import minimal.token.token : TokenBase;


alias StringList = SList!string;
alias TokenList  = SList!TokenBase;

class Register (T)
{
    alias L = SList!T;
    protected L _list = L();

    T pop() {
        T t = this.get();
        this._list.removeFront();
        return t;
    }

    T get() {
        return this._list.front;
    }

    void set(T item) {
        this._list.insertFront(item);
    }

    void clear() {
        this._list.clear();
    }

    immutable(Register) immutableCopy() {
        return cast(immutable) this;
    }
}

class Accumulator (T : long) : Register!T
{
    void accumulate(op = string)(T other) {
        if (op !in [])
        mixin("this._list %s= other".format(op));
    }
}

const auto __PREDEFINED_REGISTERS = [
    "A": new Register!TokenBase,
    "B": new Register!TokenBase,
    "C": new Register!TokenBase,

    "X": new Accumulator!TokenBase,
    "Y": new Accumulator!TokenBase,
    "Z": new Accumulator!TokenBase,
];
