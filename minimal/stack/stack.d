module minimal.stack.stack;

import std.container.slist : SList;
import std.outbuffer : OutBuffer;
import std.logger : errorf;
import std.format : format;
import minimal.token.token : IToken, Base;


final class Output (TValue)
{
    private OutBuffer _buffer_;

    this(ref OutBuffer buffer) {
        this._buffer_ = buffer;
    }

    immutable(OutBuffer) buffer() { return cast(immutable) this._buffer_; }

    void add(string to_be_added) {
        this._stack_.insertFront(to_be_added);
    }

    void addThenWrite(TValue value, string fmt = "") {
        this._stack_.insertFront(value);

        if (fmt.length > 0) {
            this._buffer_.writef(fmt, value);
        }
        else {
            this._buffer_.write(value);
        }
    }

    void write() {
        this._buffer_.write(this._stack_);
    }

    void writef(string fmt) {
        this._buffer_.writef(fmt, this._stack_);
    }

    void writefln(string fmt) {
        this._buffer_.writefln(fmt, this._stack_);
    }
}


enum StackType {
    String,
    Token,
}

alias StringStack = Stack!string;
alias TokenStack  = Stack!Base;

alias StringOutput = Output!string;
alias TokenOutput  = Output!Base;

alias StringStacks = SList!StringStack;
alias TokenStacks  = SList!TokenStack;

StringStack __string_stack = StringStack();
TokenStack  __token_stack  = TokenStack();


Module __module = new Module;

private final class Module {

    this() {
        const auto _DefaulRegisters = [
            "A": new Register!"A"(),
            "B": new Register!"B"(),
            "C": new Register!"C"(),
        ];

        const auto _DefaultAccumulators = [
            "X": new Accumulator!"X"(),
            "Y": new Accumulator!"Y"(),
            "Z": new Accumulator!"Z"(),
        ];

        foreach(Register reg; ._DefaulRegisters) {
            .__registers.insertFront(reg);
        }
    }
}


void add(Base what)
in
{
    assert(what.length > 0, "Empty string is not allowed.");
    import std.string : replace;
    what = what.replace(" ", "-");
    what = what.replace("_", "-");
}
do
{
    .__token_stack.insertFront(what);
}

void add(string to, string what)
in
{
    assert(what.length > 0, "Empty string is not allowed.");
    import std.string : replace;
    what = what.replace(" ", "-");
    what = what.replace("_", "-");
}
do
{
    foreach(Stack stack; .__token_stack) {
        if (to == stack.name) {
            stack.push(what);
        }
    }
}

void add(string to, string what)
in
{
    assert(to.length > 0, "Empty string is not allowed.");
    import std.string : replace;
    to = to.replace(" ", "-");
    to = to.replace("_", "-");
}
do
{
    if (is(._DefaulRegisters[to])) {
        ._DefaulRegisters[to].add(what);
        return;
    }

    if (.__registers.empty) {
        .__registers.insertFront(Register!to);
    }

    bool found = false;

    foreach (reg; .__registers) {
        if (to == reg.name) {
            found = true;
        }
    }

    if (!found) {
        .__registers.insertFront(Register!to);
        register(to, what);
    }
}

template Accumulator (T : long) {
    alias Acc = long;
    protected Acc acc;

    void accumulate(in T* item) {
        this.acc += cast(long) item;
    }

    void accumulate(op : string)(in T* item) {
        static if (op !in ["+", "-", "*", "/", "^^", "^", "|", "&"])
            throw new Exception("Unsupported operator [%s].".format(op));
        mixin("this.acc %s= cast(long) item".format(op));
    }
}

template Register (Name = string, T)
{
    protected T _value;

    this(T value) {
        this._value = value;
    }

    T get() {
        return this._value;
    }

    string isNull() {
        return (this._value is null);
    }

    immutable(Register!(Name, T)) copy() {
        if(this.isNull) throw new Exception("Value is null; cannot create a copy.");
        return cast(immutable) this;
    }
}

interface StackBase (TStackItem, TOutput = StringOutput) {
    immutable(TOutput*) output();

    void none();
    void drop();
    void push(TStackItem value);
    TStackItem pop();

    void swapFront();
    void swap(TStackItem a, TStackItem b);
    void swap(ulong from, ulong to);
    long indexOf(TStackItem item);
}

final class Stack (TStackItem, TOutput = StringOutput) : StackBase!(TStackItem, TOutput)
{
    alias TStack = SList!TStackItem;

    private TStack*  _stack_;
    private TOutput* _output_;

    this(inout TOutput* output, inout TStack* _stack) {
        this._output_ = output;
        this._stack_  = _stack;
    }

    immutable(TOutput*) output() {
        return cast(immutable) this._output_;
    }

    void none() {}

    void drop() {
        this._stack_.removeFront();
    }

    void push(TStackItem value) {
        this._stack_.insertFront(value);
    }

    TStackItem pop() {
        TStackItem t = this._stack_.front;
        this.drop();
        return t;
    }

    void swapFront() {
        TStackItem a = this.pop();
        TStackItem b = this.pop();

        this.push(a);
        this.push(b);
    }

    void swap(TStackItem a, TStackItem b) {
        long aindex = this.indexOf(a);
        assert(aindex >= 0, "Invalid: Stack does not contain `a`.");

        long bindex = this.indexOf(b);
        assert(bindex >= 0, "Invalid: Stack does not contain `b`.");

        if(aindex >= 0 && bindex >= 0)
            swap(aindex, bindex);
    }

    void swap(ulong from, ulong to) {
        TStackItem c = this._stack_[from];
        this._stack_[from] = this._stack_[to];
        this._stack_[to]   = c;
    }

    long indexOf(TStackItem item) {
        import std.range : enumerate;

        foreach (ulong idx, TStackItem itm; enumerate(this._stack_)) {
            if (item.name == itm.name) {
                return idx;
            }
        }

        return -1;
    }
}
