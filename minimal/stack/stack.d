module minimal.stack.stack;

import minimal.token.token : Token;

debug import std.stdio;


alias Size  = ulong;
alias Index = ulong;

alias Entry = Token;
alias MutEntries(I: Index, E: Entry) = E[I];

struct Stack {
    alias ImmEntry = immutable(Token);
    alias Entries  = MutEntries!(Index, Entry);

    const DEFAULT_CAPACITY = 512UL;

    protected {
        Entries stack    = null;
        Index   curridx  = 0UL;
        Size    capacity = DEFAULT_CAPACITY;
    }

    @property bool empty() const nothrow
        => (stack.length == 0UL) || (stack.length == curridx);

    @property Size position()
        => cast(Size) curridx;

    this (Entries entries, Size capacity_ = DEFAULT_CAPACITY) {
        stack    = entries;
        capacity = capacity_;
    }

    this (Size capacity_) {
        stack    = null;
        capacity = capacity_;
    }

    ImmEntry pop() {
        if(!isValidIndex(curridx)) throw new Exception("Out of bounds");
        curridx += 1UL;
        return cast(ImmEntry) stack[curridx];
    }

    void push(in Entry entry) {
        if (!isValidIndex(curridx+1)) throw new Exception("Out of bounds");
        curridx += 1UL;
        stack[curridx] = cast(Token) entry;
    }

    void drop() nothrow
        => destroy(stack[curridx]);

    bool isValidIndex(uint test) const nothrow
        => (curridx + test) <= capacity;

    bool isValidIndex(Size test) const nothrow
        => (curridx + test) <= capacity;


    auto opUnary(string op)() nothrow
    {
        switch (op) {
            case "^": pop();  break;
            case "~": drop(); break;
            default:
                return this;
        }
        return this;
    }
}
