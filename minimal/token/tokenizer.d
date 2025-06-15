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
    private {
        State     _state_ = State.JustInitiated;
        RawData   _raw_   = new RawData();
        TokenData _token_ = new TokenData();
    }
}

interface Data (T1, T2)
{
    immutable(T1) sequence();
    T2 get();
    void add(T2 item);
    ulong length();
    bool hasMore();
}

alias TRawData   = Data!(RawSeq, Raw);
alias TTokenData = Data!(TokenSeq, Token);

class RawData : TRawData {
    private {
        RawSeq _sequence_;
    }

    this(RawSeq seq) {
        this._sequence_ = seq;
    }

    immutable(RawSeq) sequence() {
        return cast(immutable) this._sequence_;
    }

    Raw get() {
        scope(exit) this._sequence_.removeBack();
        return this._sequence_.back;
    }

    void add(Raw item) {
        this._sequence_.insertBack(item);
    }

    ulong length() {
        return this._sequence_.length;
    }

    bool hasMore() {
        return (this._sequence_.length > 0);
    }

    immutable(RawData) copy() {
        return cast(immutable) this;
    }
}

class TokenData : TTokenData {
    private {
        TokenSeq _sequence_;
    }

    this(TokenSeq seq) {
        this._sequence_ = seq;
    }

    immutable(TokenSeq) sequence() {
        return cast(immutable) this._sequence_;
    }

    Token get() {
        scope(exit) this._sequence_.removeBack();
        return this._sequence_.back;
    }

    void add(Token item) {
        this._sequence_.insertBack(item);
    }

    ulong length() {
        return this._sequence_.length;
    }

    bool hasMore() {
        return (this._sequence_.length > 0);
    }

    immutable(TokenData) copy() {
        return cast(immutable) this;
    }

    TokenData createAndAdd(Raw raw, TopCategory topcat, SubCategory subcat, Source src, uint req_pops) {
        this._sequence_.insertBack(TokenData.create(raw, topcat, subcat, src, req_pops));
        return this;
    }

    static Token create(Raw raw, TopCategory topcat, SubCategory subcat, Source src, uint req_pops) {
        return new Token(raw, topcat, subcat, src, req_pops);
    }
}


class Tokenizer
{
    immutable(Tokenizer) tokenize() {
        while (this.identify() && this.next()) {}
        return cast(immutable) this;
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
}
