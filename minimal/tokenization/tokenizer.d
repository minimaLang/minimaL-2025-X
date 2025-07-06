module minimal.tokenization.tokenizer;

debug import std.stdio            : writeln, writefln, writef;
import std.container.array        : Array;
import std.outbuffer              : OutBuffer;
import minimal.error.predefined   : SyntaxError, InputError;
import minimal.error.errors       : ErrorList;
import minimal.tokenization.types;

interface Interface
{
    void  tokenize();
    ulong line();
    ulong column();
    ulong position();

    immutable(Context) context();
}

final class Tokenizer : Interface
{
    private:
           Identifier _identifier_;
    shared Context    _context_;
    shared TokenList  _tokens_;
    shared StringList _strings_;

    public:
    this(ref Context context) {
        if (context is null) context = new Context(view, strings, tokens);
        this._identifier_ = new Identifier(context, State.JustInitialized, strings, tokens);
    }

    void tokenize()
    in (this._context_.instack.values.length > 0) {
        foreach (string token; this._identifier_.strings) {
            if (!this._identifier_.evaluate()) {
                static import std.format;
                this._identifier_.token = new ErrorToken("<NotEvaluable>", "Token [%s] not evaluable.".format(token));
            }
            else {
                this._context_._state_.nextPosition();
            }
        }
    }

    immutable(Context) context() => cast(immutable) this._context_;

    ulong line() {
        return this._context_.line;
    }

    ulong column() {
        return this._context_.column;
    }

    ulong position() {
        return this._context_.position;
    }

    void nextLine(ulong add = 1)
    in {
        assert(add > 0);
    } do {
        this._line_ += add;
    }

    void nextColumn(ulong add = 1)
    in {
        assert(add > 0);
    } do {
        this._column_ += add;
    }

    void nextPosition(ulong add = 1)
    in  {
        assert(add > 0);
        assert((this._line_ + this._column_) <= (this._position_ + add));
    } do {
        this._position_ += add;
    }
}

final class Identifier
{
    // import minimal.tokenization.
    private:
    Context _context_;
    State   _state_;

    public:
    this(ref in Context context, in StringList strings, in TokenList tokens) {
        this._context_ = context;
    }

    immutable(TokenList)  tokens  () => cast(immutable) this._context_.tokens;
    immutable(StringList) strings () => cast(immutable) this._context_.strings;

    State state() => this._state_;

    void push(ref Token token) {
        this._context_.tokens ~= token;
    }
    immutable(Token) peek() => cast(immutable) this._context_.tokens.front;
    immutable(Token) pop()  {
        Token token = this.peek;
        this._context_.removeFront();
        return token;
    }

    bool evaluate() {
        ulong len  = 0;
        bool  same = false;

        foreach (string s; this._context_.instack) {
            len = s.length;
            if (len > 1) {
                same = this.identify(s[0]) == this.identify(s[1]);
                if (same) {
                    this._context_.outstack[this._context_];
                }
            }
        }
    }

    Token identify (string s) {
        switch(s) {
            case "\f", "\r", "\n":
                // LineEnd
            break;
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                // Number
                return new Literal;
            break;
            case "a", "b", "c", "d", "e", "f", "g", "h", "i",
                 "j", "k", "l", "m", "n", "o", "p", "q", "r",
                 "s", "t", "u", "v", "w", "x", "y", "z":
            goto case;
            case "A", "B", "C", "D", "E", "F", "G", "H",
                 "I", "J", "K", "L", "M", "N", "O", "P", "Q",
                 "R", "S", "T", "U", "V", "W", "X", "Y", "Z":
                return new Token(s, TokenType.Alpha, this._context_);
            break;
            case "+", "-", "*", "/":
                return new Operator(s, TokenType.MathOperator, this._context_);
            break;
            case "|", "&", "^":
                return new Operator(s, TokenType.LogicOperator, this._context_);
            break;
            case "!", "?", "=":
                return new Operator(s, TokenType.UnaryOperator, this._context_);
            break;
            case ":", "~", ".", "#":
                return new Operator(s, TokenType.StackOperator, this._context_);
            break;
            case "!:", "?:", "!~", "?~",
                 "!.", "?.", "!#", "?#":
                return new Operator(s, TokenType.SpecialOperator, this._context_);
            case "`":
                return new String(s, TokenType.StringBegin, this._context_);
            break;
            case "'":
                return new String(s, TokenType.StringEnd, this._context_);
            break;
            case "{":
                return new Block(s, TokenType.BlockBegin, this._context_);
            case "}":
                return new Block(s, TokenType.BlockEnd, this._context_);
        }
    }
}
