module minimal.token.tokenizer;


import minimal.token.token :
    Identifier,
    StringStack,
    TokenStack,
    StringData,
    TokenData,
    Token
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
        State      _state_  = State.JustInitiated;
        StringData _string_ = new StringData;
        TokenData  _token_  = new TokenData;
    }

    bool empty() {
        return this._string_.empty;
    }

    this(StringStack stack) {
        foreach (str; stack) this._string_.add(str);
    }

    void add(Token token) {
        this._token_.add(token);
    }

    string get() {
        return this._string_.get();
    }

    immutable(TokenData) tokenData() {
        return cast(immutable) this._token_;
    }

    immutable(StringData) strData() {
        return cast(immutable) this._string_;
    }
}

class Tokenizer
{
    private Context* _context_;

    this (ref Context context) {
        this._context_ = &context;
    }

    bool next() {
        return !this._context_.empty;
    }

    immutable(Tokenizer) tokenize() {
        Token      current;
        while (this.next() && Identifier.identify(this._context_._string_.get(), current)) {}
        return cast(immutable) this;
    }
}
