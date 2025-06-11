module minimal.interpreter.interpreter;

import std.stdio : writeln, write, writefln, readln, readf, readfln;
import std.format;
import std.conv : to;
import minimal.token.token
    : Token, TokenSeq, RawSeq, Raw, Source,
      TopCategory, SubCategory
    ;
import minimal.token.tokenizer : Tokenizer;

enum State {
    JustInitialized,
    Running,
    Done,
}

struct Context {
    import std.exception : enforce;

    private {
        RawSeq    _consumed_ = RawSeq();
        Tokenizer _tokenizer_;
        Token     _current_;

        bool  _failed_ = false;
        State _state_  = State.JustInitialized;
    }

    RawSeq    consumed()   { return this._consumed_;           }
    RawSeq    unconsumed() { return this._tokenizer_.sequence; }
    State     state()      { return this._state_;              }
    Tokenizer tokenizer()  { return this._tokenizer_;          }

    this (ref Tokenizer tokenizer) {
        this._consumed_  = RawSeq();
        this._tokenizer_ = tokenizer;
    }

    void consume() {
        if (this._state_ == State.JustInitialized)
            this._state_ = State.Running;
        else if (this._failed_)
            throw new Exception("Already failed. Cannot continue.");
        else if (this._state_ == State.Done)
            throw new Exception("Already done. Cannot continue.");

        this._current_ = this.tokenizer.context.token;
        scope(exit) this._consumed_.insertBack(this._current_.raw);
        scope(exit) this.unconsumed.removeBack;
    }

    bool next() {
        if (this.tokenizer.done) this._state_ = State.Done;
        this._failed_ = this.tokenizer.failed;

        if (!this._tokenizer_.identify) {
            throw new Exception(
                "Unidentifiable token `%s`"
                .format(this._tokenizer_.context.raw));
        }

        this.consume;
        return !this.tokenizer.done;
    }
}

class Interpreter {
    private {
        debug import std.stdio;
        import std.string : splitLines, split;
        import std.exception : enforce;
        import std.format : format;

        Context _context_;
    }

    Tokenizer tokenizer() => this._context_.tokenizer;

    this(ref Tokenizer tokenizer) {
        enforce(!tokenizer.done,   "Tokenizer must not been done.");
        enforce(!tokenizer.failed, "Tokenizer must not been failed.");

        this._context_ = Context(tokenizer);
    }

    bool next() => this._context_.next;

    ulong run() {
        import std.format : format;

        while (this._context_.state != State.Done) {

            try {
                if (this.tokenizer.identify) {
                    debug writeln(this.tokenizer.done);
                }
            }
            catch (Exception e2) {
                auto e1 = new Exception(
                    "Token not idenifiable `%s`."
                    .format(this.tokenizer.raw));
                throw Exception.chainTogether(e1, e2);
            }

            bool literal_begin;
            bool comment_begin;
            bool consume;

            auto token = this.tokenizer.context.token;
            debug writefln("Token [%s].", token.raw);

            if (token.source == Source.Builtin) {
                debug writefln(token.raw);

                switch (token.topcat) {
                    case TopCategory.Operator:
                        this.run_operator(token, consume);
                    break;
                    case TopCategory.Literal:
                        this.run_literal(token, consume, literal_begin);
                    break;
                    case TopCategory.Comment:
                        this.run_comment(token, consume, comment_begin);
                    break;
                    case TopCategory.Routine:
                        this.run_routine(token, consume, token);
                    break;
                    case TopCategory.Special:
                        this.run_special(token, consume, token);
                    break;
                    default:
                        debug writefln("Unknown token [%s].", token);
                        this.tokenizer.context.markAsFail;
                        return 0;
                }
            }

            if (consume) this.tokenizer.context.advance;
        }
        return this.tokenizer.context.length;
    }

    protected void run_literal(
        in Token token, out bool literal_begin, out bool consume
    ) {
        if (
               token.subcat == SubCategory.Digit
            || token.subcat == SubCategory.Letter
        ) {
            consume = true;
        }
        switch(token.raw) {
            case ".l":
                    // Literal begin
                literal_begin = true;
            break;
            case ":l":
                    // Literal end
                literal_begin = false;
            break;
            default:
                // Accepting all chars
                if (literal_begin) break;
                throw new Exception(
                    "Unsupported literal token [%s]; review needed."
                    .format(token.raw));
        }
        consume = true;
    }

    protected void run_comment(
        in Token token, out bool consume, out bool comment_begin
    ) {
        switch (token.raw) {
            case ";":
                // Just go to next line
            break;
            case "{#":
                // Ignore everything until "#}"
                comment_begin = true;
            break;
            case "#}":
                // Found comment end.
                comment_begin = false;
            break;
                default:
                if (comment_begin) break;
                throw new Exception(
                    "Unsupported comment token [%s]; review needed."
                    .format(token.raw)
                );
        }
        consume = true;
    }

    protected void run_operator(ref Token token, out bool consume) {

        debug writeln("Operator: ", token);
        if (token.subcat == SubCategory.Stack) {
            debug writefln("Stack Operator [%s].", token.raw);

            switch (token.raw) {
                case ".":
                    debug writeln(".");
                break;
                case "^":
                    debug writeln("^");
                break;
                case "~":
                    debug writeln("~");
                break;
                case "=":
                    writeln("Evaluation not yet implemented.");
                break;
                case "#":
                    writeln("Stack flush not yet implemented.");
                break;
                default:
                    throw new Exception(
                        "Unknown Stack operator [%s]."
                        .format(token.raw)
                    );
                consume = true;
            }
        }
        else if (token.subcat == SubCategory.Math) {
            switch (token.raw) {
                case "+":
                break;
                case "-":
                break;
                case "*":
                break;
                case "/":
                break;
                default:
                    throw new Exception(
                        "Unknown Math operator [%s]."
                        .format(token.raw)
                    );
                consume = true;
            }
        }
        else if (token.subcat == SubCategory.Bitwise) {
            switch (token.raw) {
                case "&":
                break;
                case "|":
                break;
                case "\\":
                break;
                default:
                    throw new Exception(
                        "Unknown Bitwise operator [%s]."
                        .format(token.raw)
                );
                consume = true;
            }
        }
        else if (token.subcat == SubCategory.Logic) {
            switch (token.raw) {
                case "&&":
                break;
                case "||":
                break;
                case "//":
                break;
                case "!!":
                break;
                default:
                    throw new Exception(
                        "Unknown Logic operator [%s]."
                        .format(token.raw)
                    );
                consume = true;
            }
        }
        else if (token.subcat == SubCategory.Special) {
            writeln("Special token not yet implemented.");
            consume = true;
        }
        else {
            throw new Exception(
                "Unsupported Subcategory; review needed.");
            consume = true;
        }
    }

    // ---

    // TODO
    protected void run_routine(
        in Token token, out bool consume, out Token replacement
    ) {
        consume = false;
        Raw output = token.raw;
        .routines(token.raw, output);
        replacement = new Token(
            output,
            TopCategory.Routine,
            SubCategory.Special,
            Source.RoutineCall,
            token.pops_required,
            token.pops_optional,
        );
        consume = true;
        return;
    }

    protected void run_special(
        in Token token, out bool consume, out Token replacement) {
        writeln("Special not yet implemented.");
        //token;
    }
}

void routines(Raw r, out Raw output, Raw input...) {
    switch (r) {
        case ":input":
            output = routines_write_read(input);
        break;
        case ":print":
            routine_print(input);
            output = input[0].to!string;
        break;
        default:
            throw new Exception("No such routine; review required.");
    }
}

Raw routines_write_read(Raw args...) {
    assert(!is(args[0] == void));
    Raw name = args[0].to!string;

    static if (!is(args[1] == void)) {
        Raw value = args[1].to!string;
    }

    debug writeln(name, " ", value);

    switch (name) {
        case "line", "l":
            return readln();
        break;
        case "format", "f":
            if (is(value == void) || value.length == 0)
                throw new Exception("Option `format` requires 3 values.");
            if (is(args[2] == void))
                throw new Exception("Option `format` requires a 3rd value.");

            uint count = readfln(value, args[2].to!string);
            if (count == 0) {
                throw new Exception(
                    "Too few arguments; read only " ~ count.to!string);
            }
            else {
                return value;
            }
        break;
        default:
            throw new Exception("Invalid input.");
    }

    assert(0);
}

void routine_print(Raw args...) {
    assert(!is(args[0] == void));
    Raw name = args[0].to!string;

    static if (is(args[1] == void)) {
        alias value = noreturn;
    }
    else {
        Raw value = args[1].to!string;
    }

    debug writeln(name, " ", value);
    switch (name) {
        case "line", "l":
            writeln(value);
        break;
        case "format", "f":
            writefln(value);
        break;
        default:
            write(name, " ", value);
    }
}
