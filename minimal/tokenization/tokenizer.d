module minimal.tokenization.tokenizer;

debug import std.stdio            : writeln, writefln, writef;
import std.container.array        : Array;
import minimal.error.predefined   : SyntaxError, InputError, log;
import minimal.tokenization.types : Context, State, Token, TokenStack, StringStack;

interface Interface
{
    void  tokenize();
    ulong line();
    ulong column();
    ulong position();
}

final class Tokenizer : Interface
{
    private:
    Identifier _identifier_;

    public:
    this(ref Context context, StringStack strings, TokenStack tokens) {
        this._identifier_ = Identifier(context, State(), strings, tokens);
    }

    void tokenize()
    in (this._context_.instack.values.length > 0) {
        foreach (string token; this._identifier_.strings) {
            if (!this._identifier_.evaluate()) {
                static import std.format;
                this._identifier_.token = new ErrorToken("<NotEvaluable>", "Token [%s] not evaluable.".format(token));
            }
            else {
                this._state_.nextPosition();
            }
        }
    }

    ulong line() {
        return this._state_.line;
    }

    ulong column() {
        return this._state_.column;
    }

    ulong position() {
        return this._state_.position;
    }
}

final class Identifier
{
    // import minimal.tokenization.
    private:
    Context _context_;
    State   _state_;

    public:
    this(ref Context context, ref State state, in StringStack strings, in TokenStack tokens) {
        if (context is null) this._context_ = Context(strings, tokens);
        if (state   is null) this._state_   = State();
    }

    immutable(TokenStack)  tokens  () => cast(immutable) this._context_.tokens;
    immutable(StringStack) strings () => cast(immutable) this._context_.strings;
    immutable(State)       state   () => cast(immutable) this._state_;

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
