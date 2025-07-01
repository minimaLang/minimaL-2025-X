module minimal.tokenization.types;

import std.container.slist : SList;
import std.outbuffer : OutBuffer;
import std.variant : Variant;
import std.logger : errorf, warningf, infof;
import std.format;


alias StringStack = SList!string;
alias TokenStack  = SList!Token;

enum TokenType {
    Any, None,

    LineEnd,

    MathOperator,
    LogicOperator,
    UnaryOperator,
    StackOperator,
    SpecialOperator,

    Label,
    Tuple,
    Block,

    Value,
    String,
    Routine,

    Literal,
    Number,
    Alpha,


    ERROR //.
}

struct State
{
    private:
    ulong _line_     = 0;
    ulong _column_   = 0;
    ulong _position_ = 0;
    bool  _failed_   = false;

    InputError  _input_error_;
    SyntaxError _syntax_error_;

    public:
    this(ulong line, ulong column, ulong position = 0, bool failed = false) {
        this._line_     = line;
        this._column_   = column;
        this._position_ = position;
        this._failed_   = failed;
    }

    void setError(InputError error) {
        this._input_error_ = error;
    }

    void setError(SyntaxError error) {
        this._syntax_error_ = error;
    }

    ulong nextLine(ulong add = 1)
    in (add > 0) {
        this._line_ += add;
    }

    ulong nextColumn(ulong add = 1)
    in (add > 0) {
        this._column_ += add;
    }

    ulong nextPosition(ulong add = 1)
    in (add > 0) {
        this._position_ += add;
    }

    immutable(ulong) line() {
        return cast(immutable) this._line_;
    }

    immutable(ulong) column() {
        return cast(immutable) this._column_;
    }

    immutable(ulong) position() {
        return cast(immutable) this._position_;
    }
}

interface TokenInterface
{
    immutable(string)    name();
    immutable(string)    symbol();
    immutable(TokenType) type();
    immutable(Context)   context();

    TokenType[] expect();

    bool isLineEnd();
    bool isOperator();

    bool isLabel();
    bool isTuple();
    bool isBlock();

    bool isValue();
    bool isString();
    bool isRoutine();

    bool isLiteral();
    bool isNumber();
    bool isAlpha();

    bool isError();
}

interface OperatorInterface : TokenInterface
{
    TokenInterface opOperate (string operator) (TokenInterface...);
}

class Token : TokenInterface
{
    protected:
    Context   _context;
    string    _symbol;
    TokenType _type;
    string    _name;
    ulong     _value;

    public:
    this (ref Context context, string symbol, TokenType type = TokenType.Any, string name = "", long value = 0) {
        this._context = context;
        this._symbol  = symbol;
        this._type    = type;
        this._value   = value;

        if (name.length == 0) {
            if (this._type == TokenType.Any) {
                name = "<Any>";
            }
            else if (this._type == TokenType.None) {
                name = "<None>";
            }
            else if (this._type == TokenType.ERROR) {
                name = "<Error>";
            }
            else {
                throw new Exception("Name is required!");
            }
        }

        this._name = name;
    }

    immutable(string) name() {
        return cast(immutable) this.Name;
    }

    immutable(string) symbol() {
        return cast(immutable) this._symbol;
    }

    immutable(TokenType) type() {
        return cast(immutable) this._type;
    }

    immutable(Context) context() {
        return cast(immutable) this._context;
    }

    immutable(ulong) value() {
        return cast(immutable) this._value;
    }

    bool isLineEnd() {
        static if (this.type == TokenType.LineEnd) return true;
        return false;
    }

    bool isOperator() {
        static if (
               this.type == TokenType.MathOperator
            || this.type == TokenType.LogicOperator
            || this.type == TokenType.UnaryOperator
            || this.type == TokenType.StackOperator
            || this.type == TokenType.SpecialOperator
        ) {
            return true;
        }
        return false;
    }

    bool isLabel() {
        static if (this.type == TokenType.Label) return true;
        return false;
    }

    bool isTuple() {
        static if (this.type == TokenType.Tuple) return true;
        return false;
    }

    bool isBlock() {
        static if (this.type == TokenType.Block) return true;
        return false;
    }

    bool isValue() {
        static if (this.type == TokenType.Value) return true;
        return false;
    }

    bool isString() {
        static if (this.type == TokenType.String) return true;
        return false;
    }

    bool isRoutine() {
        static if (this.type == TokenType.Routine) return true;
        return false;
    }

    bool isLiteral() {
        static if (
               this.type == TokenType.Alpha
            || this.type == TokenType.Number
            || this.type == TokenType.Value
        ) {
            return true;
        }
        return false;
    }

    bool isNumber() {
        static if (this.type == TokenType.Number) return true;
        return false;
    }

    bool isAlpha() {
        static if (this.type == TokenType.Alpha) return true;
        return false;
    }

    bool isError() {
        static if (this.type == TokenType.ERROR) return true;
        return false;
    }


    Token opEvaluate() const {
        static      if (this.isLiteral)  return this;
        else static if (this.isOperator) return this.opOperate();
        debug warning("`opEvaluate` must be overridden; return `this`.");
        return this;
    }

    Token opOperate() {
        return new ErrorToken("<NotAnOperator>", "This is not an operator or must be overridden.");
    }

    bool opEquals(T: Token)(T other) const {
        return (this.symbol == other.symbol);
    }

    override ulong toHash() const nothrow @trusted {
        return hashOf(this.symbol);
    }

    int opCmp(T: Token)(T other) const {
        if (this.type == TokenType.Any)
            return 0;
        if (this.type == TokenType.None && other.type != TokenType.None)
            return -1;
        if (this.type == other.type) return cmp(this.symbol, other.symbol);
        return 1;
    }
}

interface ErrorTokenInterface
{
    string message();
}

class ErrorToken : Token, ErrorTokenInterface
{
    private:
    string error_name;
    string error_message;

    public:
    this (
        ref Context context,
            string  symbol,
            string  name    = "ERROR",
            string  message = "Token error."
    ) {
        super(context, "<"~name~">", TokenType.ERROR, name, 0);

        this.error_name    = name;
        this.error_message = message;
    }

    this(ref Context context, string name, string message) {
        super(context, "<"~name~">", TokenType.ERROR, name, 0);

        this.error_name    = name;
        this.error_message = message;
    }

    override bool isError() => true;

    string message() {
        return this.error_message;
    }
}

class Any : Token {}

class Literal : Token
{
    this (
        ref Context   context,
            string    symbol,
            TokenType type  = TokenType.Any,
            string    name  = "<Literal>",
            long      value = 0
    ) {
        super(context, symbol, type, name, value);
    }

    this(ref Context context, string symbol, long value) {
        super(context, ".l"~symbol~"l.", TokenType.Literal, "<Literal>", value);
    }

    override isLiteral() => true;
}

class Value : Token
{
    this(ref Context context, long value) {
        super(context, "="~(cast(string) value), TokenType.Value, "<Value>", value);
    }
}

class Variable : Value
{
    this(ref Context context, long value, string name) {
        super(context, name~"="~(cast(string) value), "<"~name~">", value);
    }
}

class Routine : Variable
{
    protected:
    static SList!Routine routines;

    private:
        Token delegate(ref Context) _runner_;

    public:
    this(ref Context context, string name, long value, Token delegate(ref Routine) dg) {
        super(context, "::"~(name), TokenType.Routine, "<"~name~">", value);
        this._runner_ = dg;

        bool has = false;
        if(!Routine.exists(name))
            Routine.routines ~= this;
        else
            debug writefln("Routine [%s] already exists; ignored.", name);
    }

    T opRun(T: Token)() {
        return this._runner_(this);
    }

    static bool exists(string name) {
        foreach (Routine r; Routine.routines) {
            if(r.name == name) {
                return true;
            }
        }
        return false;
    }
}

class Operator : Token, OperatorInterface
{
    protected:
    import core.vararg;

    bool checkValidity(Token token, ...) {
        ulong valid = 0;
        foreach (Token t; _arguments) {
            if (t.isError) {
                throw new Exception(t.message);
            }
            if (t.type != TokenType.Value || t.type != TokenType.Number) {
                valid += 1;
            }
        }
        return (valid == token.length);
    }

    public:
    this(string symbol, TokenType type = TokenType.Any, ref Context context) {
        super(symbol, type = TokenType.Any, context);
    }

    override bool isOperator() => true;

    TToken opOperate(string operator)(Token token, ...) {
        if (this.type == TokenType.MathOperator) {
            if (_arguments.length < 2) {
                return new ErrorToken!("<InvalidStack>", "Two (2) token required.");
            }

            switch(operator) {
                case "+":
                    if (!this.checkValidity(token[0], token[1])) {
                        return new ErrorToken!("<InvalidTokenType>", "Token must be of type `Value` or `Number`.");
                    }

                    Token a = token[0].asValue();
                    Token b = token[1].asValue();

                    return new Value(a + b);
                break;
                case "-":
                    if (!this.checkValidity(token[0], token[1])) {
                        return new ErrorToken!("<InvalidTokenType>", "Token must be of type `Value` or `Number`.");
                    }

                    Token a = token[0].asValue();
                    Token b = token[1].asValue();

                    return new Value(a - b);
                break;
                case "*":
                    if (!this.checkValidity(token[0], token[1])) {
                        return new ErrorToken!("<InvalidTokenType>", "Token must be of type `Value` or `Number`.");
                    }

                    Token a = token[0].asValue();
                    Token b = token[1].asValue();

                    return new Value(a * b);
                break;
                case "/":
                    if (!this.checkValidity(token[0], token[1])) {
                        return new ErrorToken!("<InvalidTokenType>", "Token must be of type `Value` or `Number`.");
                    }

                    Token a = token[0].asValue();
                    Token b = token[1].asValue();

                    return new Value(a / b);
                break;
                default:
                    static import std.format;
                    return new ErrorToken!("<InvalidOperator>", "Invalid math operator [%s].".format(operator));
            }
        }
        // TODO - UnaryOperator
        else if (this.type == TokenType.StackOperator) {
            static import std.format;
            throw new Exception("NOT YET IMPLEMENTED!");

            switch(operator) {
                case ".":
                    //! Operate
                break;
                case "~":
                    //! Drop last token
                break;
                case "#":
                    //! Flush all token
                break;
                default:
                    static import std.format;
                    return new ErrorToken!("<InvalidOperator>", "Invalid stack operator [%s].".format(operator));
            }
        }
        // TODO - UnaryOperator
        else if (this.type == TokenType.UnaryOperator) {
            throw new Exception("NOT YET IMPLEMENTED!");
            switch (operator) {
                //! Value required
                case "!":
                    //! Negate
                break;
                case "?":
                    //! --
                break;
                default:

                    static import std.format;
                    return new ErrorToken!("<InvalidOperator>", "Invalid unary operator [%s].".format(operator));
            }
        }
        else {
            return new ErrorToken!("<InvalidToken>", "Invalid token [%s].".format(operator));
        }
    }

    TokenType[] expect() {
        switch(this.name) {
            case "MathOperator":
                return [TokenType.Number, TokenType.Number];
            break;
            case "LogicOperator":
                return [TokenType.Value, TokenType.Value];
            break;
            case "UnaryOperator":
                return [TokenType.Value, TokenType.Value];
            break;
            case "StackOperator":
                return [TokenType.Any];
            break;
            case "SpecialOperator":
                return [TokenType.Any];
            break;
            default:
                return [TokenType.ERROR];
        }
    }
}

alias Function  = Variant function(...);
alias ParamList = Variant[string];


alias VariableList = Variable[string];
alias RoutineList  = Routine[string];
alias ContextList  = Context[string];

VariableList createVarList(args...) {
    if (args.length == 0)
        return cast(VariableList) [];
    return cast(VariableList) args;
}

RoutineList createRoutineList(args...) {
    if(args.length == 0)
        return cast(RoutineList) [];
    return cast(RoutineList) args;
}

ContextList createContextList(Context args...) {
    if(args.length == 0)
        return cast(ContextList) [];
    return cast(ContextList) args;
}

import minimal.error : PError = ParseError, ErrorLevel;

struct Context {
    private:

    StringStack  _instack_  = StringStack();
    TokenStack   _outstack_ = TokenStack();
    OutBuffer    _view_     = new OutBuffer();
    State        _state_    = State();

    VariableList varlist = VariableList();
    RoutineList  roulist = RoutineList();

    public:
    this(in StringStack outstack, in TokenStack instack) {
        this._outstack_ = outstack;
        this._instack_  = instack;
    }

    this(in StringStack outstack, in TokenStack instack, out OutBuffer view) {
        this._outstack_ = outstack;
        this._instack_  = instack;
        view = this._view_;
    }

    this() {}

    immutable(OutBuffer) view() {
        return cast(immutable) this._view_;
    }

    immutable(TokenStack) tokens() {
        return cast(immutable) this._instack_;
    }

    immutable(StringStack) strings() {
        return cast(immutable) this._outstack_;
    }

    bool failed() {
        return (this.error.failed);
    }

    void nextState() {
        switch(this._state_) {
            case State.JustInitialized:
                this._state_ = State.Started;
            break;
            case State.Started:
                this._state_ = State.Done;
            break;
            case State.Done:
                this._state_ = State.Failed ? (this.error.code > 0) : State.Done;
            break;
            default:
                errorf("Unsupported state [%s]. Code Review required!", this._state_);
        }
    }
}
