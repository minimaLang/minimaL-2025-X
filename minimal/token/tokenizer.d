module minimal.token.tokenizer;


import minimal.token.token :
    Raw,             RawSeq,
    TokenSeq,
    TopCategory,     SubCategory,
    Token,           KnownToken,
    Source
;

import std.exception : enforce;
import std.format : format;
import std.conv : to;

import std.string : strip, split;
import std.range : empty;

import std.array : split, array;
import std.container.array : Array;

debug import std.stdio;


const string DIGITS
    = "0123456789";
const string LETTERS_LOWER
    = "abcdefghijklmnopqrstuvwxyz";
const string LETTERS_UPPER
    = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
const string LETTERS = LETTERS_LOWER ~ LETTERS_UPPER;

const string STACKOPS  = "^.~#";
const string MATHOPS   = "+-*/%";
const string BITOPS    = "&|\\";
const string LOGICOPS  = "?!";
const string EVALOPS   = "=:";
const string OPERATORS = MATHOPS ~ STACKOPS ~ LOGICOPS ~ EVALOPS;

const string LINESEPS   = "\r\n";
const string COLSEPS    = "\t\v ";
const string SEPARATORS = LINESEPS ~ COLSEPS;

// TODO op-combos ... ?^ ?:

enum State {
    JustInitiated,
    Running,
    Done,
}

class Context {

    TokenizeState state;
    TokenizeData  data;

    ulong length() => this.data.length;

    this(ref RawSeq rawseq) {
        this.data  = TokenizeData(rawseq);
        this.state = TokenizeState(rawseq.length);
    }

    TokenSeq tokseq() => this.data.tokseq;
    RawSeq   rawseq() => this.data.rawseq;

    Token token() {
        writeln("this.data.tokseq");
        return this.data.token = this.state.position;
    }
    Raw raw() {
        return this.data.raw = this.state.position;
    }

    void token(Token token) {
        this.data.add(token);
    }
    void raw(Raw raw) {
        this.data.add(raw);
    }

    void advance(ulong position = 1) {
        if (position < 1) position = 1;
        this.state.advance(position);
        this.state.current = this.data[this.state.position];
    }

    bool next() {
        this.state.next;
        this.state.current = this.data.get(this.state.position);
        return this.state.more;
    }

    bool more() => (this.data.length > 0 && !this.state.done);

    void markAsFail() {
        this.state.markAsFail;
    }
    void markAsDone() {
        this.state.markAsDone;
    }

    bool hasValidPosition() const
        => (this.state.position <= this.data.rawseq.length);
    bool hasNoValidPosition() const => !hasValidPosition();

    Context opOpAssign(string op: "~", T: Raw)(T value) {
        this.data.add(value);
        return this;
    }
    Context opOpAssign(string op: "~", T: Token)(T value) {
        this.data.add(value);
        return this;
    }

    Context opAssign(T: Token)(T value) {
        this.data.add(value);
        return this;
    }
    Context opAssign(T: Raw)(T value) {
        this.data.add(value);
        return this;
    }
}


struct TokenizeState {

    protected {
        State  _state_  = State.JustInitiated;
        bool   _done_   = false;
        bool   _failed_ = false;

        ulong _line_     = 0;
        ulong _column_   = 0;
        ulong _position_ = 0;
        ulong _length_   = 0;

        string _stateName_;
        Raw    _current_;
    }

    ulong line()     const => this._line_;
    ulong column()   const => this._column_;
    ulong position() const => this._position_;

    ulong line(    ulong add) => this._line_     += add ? add > 0 : 1;
    ulong column(  ulong add) => this._column_   += add ? add > 0 : 1;
    ulong position(ulong add) => this._position_ += add ? add > 0 : 1;

    bool  done()   const => this._done_;
    bool  failed() const => this._failed_;

    State state()   const => this._state_;
    bool  running() const => (this._state_ == State.Running);

    Raw current() const  => this._current_;
    Raw current(Raw raw) => this._current_ = raw;

    this (ulong length) {
        assert(length > 0, "No 0-length allowed.");
        this._length_    = length;
        this._stateName_ = this._state_.to!string;
    }

    ulong length() => this._length_;

    bool next() {
        this._position_ += 1;
        return (this._position_ != this.length);
    }

    bool more() => !(this.failed || this.done);

    void markAsDone() { this._done_ = true; }
    void markAsFail() { this.markAsDone(); this._failed_ = true; }

    ulong advance(ulong position = 1, ulong column = 1) {
        if (this.done) {
            throw new Exception("Already done; can not advance.");
        }
        this._position_ += position ? position < 1 : 1;
        this._column_   += column   ? column   < 1 : 1;
        this._state_     = State.Running;

        return this.position ? !this._done_ : 0;
    }

    T opCast(T: State)() const {
        return this._state_;
    }

    auto opAssign(T: State)(T value) {
        this._state_ = value;
        return this;
    }

    bool opEquals(State other) const {
        return (this._state_ == other);
    }

    ulong toHash() const @safe pure nothrow {
        import std.conv : to;
        return hashOf(this._stateName_);
    }
}

struct TokenizeData {
    import std.string : assumeUTF;

    RawSeq   rawseq = RawSeq();
    TokenSeq tokseq = TokenSeq();

    uint required_pops = 1;
    uint optional_pops = 0;

    TopCategory topcat = TopCategory.Unknown;
    SubCategory subcat = SubCategory.Unknown;
    Source      source = Source.Unknown;

    bool  more()         const => (this.rawseq.length > 0);
    ulong rawseqLength() const => this.rawseq.length;
    ulong tokseqLength() const => this.tokseq.length;

    Raw get(ulong atpos) const => this.rawseq[atpos];

    bool has(ulong atpos) const =>
        (this.rawseqLength < atpos) && (this.tokseqLength < atpos);

    void add(TokenSeq tokenseq) { foreach(token; tokenseq) this.add(token); }
    void add(RawSeq   rawseq)   { foreach(token; rawseq)   this.add(token); }

    void add(Raw   token) { this.rawseq.insertBack(token); }
    void add(Token token) { this.tokseq.insertBack(token); add(token.raw); }

    ulong length() => this.rawseq.length;

    Raw remove() {
        ulong _count = this.rawseq.length;
        Raw   _back  = this.rawseq.back;
        this.rawseq.removeBack();

        if (_count == this.rawseq.length) {
            debug
                writeln("Nothing removed.");
            else
                throw new Exception("Nothing removed.");
        }

        return _back;
    }

    Raw   raw   (size_t index) => this.rawseq[index];
    Token token (size_t index) => this.tokseq[index];

    Raw   raw   (Raw   token, size_t index) => this.rawseq[index] = token;
    Token token (Token token, size_t index) => this.tokseq[index] = token;

    auto opAssign(T: Token)(T value) {
        this.add(value);
        return this;
    }

    auto opAssign(T: Raw)(T value) {
        this.add(value);
        return this;
    }

    auto opAssign(T: Source)(T value) {
        this.source = source;
        return this;
    }

    auto opAssign(T: TopCategory)(T value) {
        this.topcat = value;
        return this;
    }

    auto opAssign(T: SubCategory)(T value) {
        this.subcat = value;
        return this;
    }


    ref Raw opIndex(size_t index) {
        return this.rawseq[index];
    }

    T opIndexAssign(T: Raw)(T value, size_t index) {
        return this.rawseq[index] = value;
    }
    T opIndexAssign(T: Token)(T value, size_t index) {
        return this.tokseq[index] = value;
    }

    T opCast(T: TokenSeq)() const {
        return this.tokseq;
    }

    T opCast(T: RawSeq)() const {
        return this.rawseq;
    }

    bool opCast(T: bool)() const {
        return this.rawseq.length > 0;
    }
}

class Tokenizer {
    private bool token_identified = false;
    Context context;

    Raw    raw()      => this.context.raw;
    Token  token()    => this.context.token;
    RawSeq sequence() => this.context.rawseq;

    bool done()    const => this.context.state.done;
    bool failed()  const => this.context.state.failed;
    bool running() const => this.context.state.running;

    this (RawSeq rawseq, ref Context ctx) {
        if (ctx is null) ctx = new Context(rawseq);
        this.context = ctx;
    }

    bool next() {

        if (this.failed) {
            throw new Exception(
                "Tokenizer has failed. Can not continue.");
            return false;
        }
        else if (this.done) {
            throw new Exception(
                "Tokenizer is already done. Can not continue.");
        }
        else if (this.context.state.position == this.context.data.length) {
            debug writeln("Reached end of `rawseq`; marking as done.");
            this.context.markAsDone();
            return false;
        }

        if (!this.identify) {
            import std.format;
            throw new Exception(
                "Unidentifiable token [%s]".format(
                this.context.raw));
            return false;
        }

        this.context.next;

        if (this.context.state.running) {
            this.context.state.advance;
            this.context.state.current;
        }

        return this.context.more();
    }

    bool identifySingle() {
        import std.algorithm.searching : canFind;
        debug writeln("(identifySingle)");

        string token = this.raw;

        if (token.empty) return false;

        this.context.data = Source.Builtin;  // Builtin?

        TopCategory topcat = TopCategory.Unknown;
        SubCategory subcat = SubCategory.Unknown;
        Source      source = Source.Unknown;

        uint required_pops = 0; // Required stack pops.
        uint optional_pops = 0; // Optional stack pops.

        if (LINESEPS.canFind(token)) {
            topcat = TopCategory.Literal;
            subcat = SubCategory.Newline;
            this.context.advance(token.length);
        }
        else if (DIGITS.canFind(token)) {
            topcat = TopCategory.Literal;
            subcat = SubCategory.Digit;
            required_pops = 1;
        }
        else if (LETTERS.canFind(token)) {
            topcat = TopCategory.Literal;
            subcat = SubCategory.Letter;
            required_pops = 1;
        }
        else if (STACKOPS.canFind(token)) {
            topcat = TopCategory.Operator;
            subcat = SubCategory.Stack;
            if (token == "." || token == "#") {
                this.context.state = State.Done;
                return true;
            }
        }
        else if (MATHOPS.canFind(token)) {
            topcat = TopCategory.Operator;
            subcat = SubCategory.Math;
            required_pops = 2;
        }
        else if (BITOPS.canFind(token)) {
            topcat = TopCategory.Operator;
            subcat = SubCategory.Bitwise;
            required_pops = 1;
        }
        else if (LOGICOPS.canFind(token)) {
            topcat = TopCategory.Operator;
            subcat = SubCategory.Logic;
            required_pops = 2;
        }
        else if (EVALOPS.canFind(token)) {
            topcat = TopCategory.Operator;
            subcat = SubCategory.Evaluation;
            required_pops = 1;
            optional_pops = 9;
        }
        else {
            this.context.markAsFail();
            return false;
        }

        debug writeln(topcat.stringof);
        debug writeln(subcat.stringof);

        // If we reach here, we have a valid token.
        Token _token = new Token(
            token,
            topcat,
            subcat,
            source,
            required_pops,
            optional_pops,
        );
        this.context = _token;
        return true;
    }

    bool identifyCombo() {
        string      token   = this.context.state.current;
        TopCategory topcat  = TopCategory.Unknown;
        SubCategory subcat  = SubCategory.Unknown;
        bool        builtin = true; // Builtin?

        debug writeln("(identifyCombo)");

        return false;
    }

    bool identifyUser() {
        string      token   = this.context.state.current;
        TopCategory topcat  = TopCategory.Unknown;
        SubCategory subcat  = SubCategory.Unknown;
        bool        builtin = false; // Buildin?

        debug writeln("(identifyUser)");

        return false;
    }

    bool identify() {
        debug writefln("Token [%s]", this.context.raw);

        if (identifySingle()) {
            debug writeln("Identified as Single.");
        }
        else if (identifyCombo()) {
            debug writeln("Identified as Combo.");
        }
        else if (identifyUser()) {
            debug writeln("Identified as User.");
        }
        else {
            debug writeln("Could not been identified.");
        }

        debug writefln(
            "(Identify)\n%s : %s (%s)\n",
            this.context.data.topcat,
            this.context.data.subcat,
            this.context.data.source
        );

        bool success = false;
        scope(success) success = true;
        return success;
    }

    immutable(Tokenizer) tokenize() {
        while (this.identify() && this.next()){}
        return cast(immutable) this;
    }
}
