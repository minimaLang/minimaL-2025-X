module minimal.tokenization.types;

import std.container.slist : SList;
import std.outbuffer       : OutBuffer;
import std.logger          : errorf, warningf, infof;
import std.format          : format;
import std.conv            : to;
import core.vararg;

import minimal.error.predefined : SyntaxError, InputError;
import minimal.error.errors     : ErrorList;

enum TokenType {
    Any, None,

    LineEnd,

    Operator,
    MathOperator,
    LogicOperator,
    UnaryOperator,
    StackOperator,
    SpecialOperator,

    Label,
    Tuple,
    Block,

    Value,
    Variable,
    String,
    Routine,

    Literal,
    Number,
    Alpha,

    ERROR //.
}

alias TokenList    = Token[];
alias StringList   = string[];
alias VariableList = Variable[];
alias RoutineList  = Routine[];
alias ContextList  = Context[];

interface ContextInterface
{
    immutable(TokenList*) tokens  ();
    immutable(StringList) strings ();
    immutable(ErrorList)  errors  ();
    immutable(OutBuffer*) view    ();

    bool failed();

    void   write(string content);
    string read();
}

interface StateInterface
{
    ulong line();
    ulong column();
    ulong position();

    void nextLine     (ulong);
    void nextColumn   (ulong);
    void nextPosition (ulong);

    void next(ulong[] ...);
}

final class State : StateInterface
{
    public:
    enum State { JustInitialized, Started, Done }
    enum JustInitialized = State.JustInitialized;
    enum Started         = State.Started;
    enum Done            = State.Done;

    private:
    ulong _line_;
    ulong _column_;
    ulong _position_;
    
    State _state_  = JustInitialized;
    bool  _failed_ = false;

    public:
    this(ulong line = 1, ulong column = 1, ulong position = 0)
    in {
        assert(line   > 0);
        assert(column > 0);
        assert(position <= (line + column)-2);
    }
    do {
        this._line_     = line;
        this._column_   = column;
        this._position_ = position;
    }

    State state()  => this._state_;
    bool  failed() => this._failed_;
    void  failed(bool value) {
        this._failed_ = value;
    }

    ulong line() {
        return this._line_;
    }

    ulong column() {
        return this._column_;
    }

    ulong position() {
        return this._position_;
    }

    void nextLine(ulong add = 1)
    in {
        assert(add > 0);
    }
    do {
        this._line_ += add;
    }

    void nextColumn(ulong add = 1)
    in {
        assert(add > 0);
    }
    do {
        this._column_ += add;
    }

    void nextPosition(ulong add = 1)
    in {
        assert(add > 0);
        assert((this.position <= (this.line + this.position)-2));
    }
    do {
        this._position_ += add;
    }

    void next(ulong[] lu ...)
    in {
        assert(lu.length < 4);
        assert(lu.length > 0);
    }
    do {
        import std.range : enumerate;
        import core.vararg;

        ulong count = lu.length;
        foreach (ulong i, a; enumerate(lu)) {
            switch (i) {
                case 0:
                    this.nextLine(a);
                break;
                case 1: 
                    this.nextColumn(a);
                break;
                case 2: 
                    this.nextPosition(a);
                break;
                default:
                    errorf("Invalid argument count; [%s].", count);
            }
        }
    }
}

final class Context : ContextInterface
{
    private:
    OutBuffer* _view_;
    TokenList* _tokens_;

    State      _state_;
    StringList _strings_ = StringList.init;
    ErrorList  _errors_  = ErrorList.init;

    ulong _line_     = 1;
    ulong _column_   = 1;
    ulong _position_ = 1;

    public:
    this(OutBuffer* view) {
        this._view_  = view;
        this._state_ = new State();
    }

    this(OutBuffer* view, ref StringList strings, TokenList* tokens) {
        this(view);
        this._strings_ = strings;
        this._tokens_  = tokens;
    }

    this(OutBuffer* view, in StringList strings, TokenList* tokens) {
        this(view);
        this._strings_ = strings;
        this._tokens_  = tokens;
    }

    Context dup() => new Context(this._view_, this.strings, this._tokens_);

    State state() => this._state_;

    immutable(TokenList*) tokens()  => cast(immutable) this._tokens_;
    immutable(StringList) strings() => cast(immutable) this._strings_;
    immutable(ErrorList)  errors()  => cast(immutable) this._errors_;
    immutable(OutBuffer*) view()    => cast(immutable) this._view_;

    bool failed() => (this.errors.length > 0);

    void write(string content) {
        this._view_.write(content);
    }

    string read() => this._view_.toString();

    ulong line()     => this._line_;
    ulong column()   => this._column_;
    ulong position() => this._position_;

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

interface TokenInterface
{
    immutable(Context)   context();
    immutable(string)    symbol();
    immutable(TokenType) type();

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

    bool isAny();
    bool isNone();
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

    public:
    this (ref Context context, string symbol, TokenType type) {
        this._context = context;
        this._symbol  = symbol;
        this._type    = type;
    }

    TokenType[] expect() => [TokenType.Any, TokenType.None];

    immutable(Context) context() {
        return cast(immutable) this._context;
    }

    immutable(string) symbol() {
        return cast(immutable) this._symbol;
    }

    immutable(TokenType) type() {
        return cast(immutable) this._type;
    }

    bool isLineEnd() const {
        if (this._type == TokenType.LineEnd) return true;
        return false;
    }

    bool isOperator() const {
        if (
               this._type == TokenType.MathOperator
            || this._type == TokenType.LogicOperator
            || this._type == TokenType.UnaryOperator
            || this._type == TokenType.StackOperator
            || this._type == TokenType.SpecialOperator
        ) {
            return true;
        }
        return false;
    }

    bool isLabel() const {
        return (this._type == TokenType.Label);
    }

    bool isValue() const {
        return (this._type == TokenType.Value);
    }

    bool isVariable() const {
        return (this._type == TokenType.Variable);
    }

    bool isTuple() const {
        return (this._type == TokenType.Tuple);
    }

    bool isBlock() const {
        if (this._type == TokenType.Block) return true;
        return false;
    }

    bool isString() const {
        if (this._type == TokenType.String) return true;
        return false;
    }

    bool isRoutine() const {
        if (this._type == TokenType.Routine) return true;
        return false;
    }

    bool isLiteral() const {
        if (
               this._type == TokenType.Alpha
            || this._type == TokenType.Number
            || this._type == TokenType.Value
        ) {
            return true;
        }
        return false;
    }

    bool isNumber() const {
        if (this._type == TokenType.Number) return true;
        return false;
    }

    bool isAlpha() const {
        if (this._type == TokenType.Alpha) return true;
        return false;
    }

    bool isError() const {
        if (this._type == TokenType.ERROR) return true;
        return false;
    }

    bool isAny() const {
        if (this._type == TokenType.Any) return true;
        return false;
    }

    bool isNone() const {
        if (this._type == TokenType.None) return true;
        return false;
    }

    Token opEvaluate() {
        if (this.isLiteral) return new Token(this._context, this._symbol, this._type);
        else if (this.isOperator) return this.opOperate();
        debug warningf("`%s` must be overridden; return `%s`.", "opEvaluate", "this");
        return this;
    }

    Token opOperate() {
        return new ErrorToken(this._context, "<NotAnOperator>", "This is not an operator or must be overridden.");
    }

    bool opEquals(T: Token)(T other) const {
        return (this.symbol == other.symbol);
    }

    override ulong toHash() const nothrow @trusted {
        return hashOf(this._symbol);
    }

    int opCmp(T: Token)(T other) const {
        if (this._type == TokenType.Any)
            return 0;
        if (this._type == TokenType.None && other._type != TokenType.None)
            return -1;
        if (this._type == other._type) return cmp(this.symbol, other.symbol);
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
            string  name,
            string  message
    ) {
        super(context, "<E>", TokenType.ERROR);
        this.error_name    = name;
        this.error_message = message;
    }

    this(ref Context context, string name, string message) {
        //context, symbol, TokenType, string name = ""
        super(context, "<E>", TokenType.ERROR);
        this.error_name    = "{E-"~name~"}";
        this.error_message = message;
    }

             string message() const => this.error_message;
    override bool   isError() const => true;
}

class Any : Token
{
    private:
    string _name_;
    long   _value_;

    public:
    this (
        ref Context   context,
            string    symbol,
            TokenType _type  = TokenType.Any,
            string    name  = "{*}",
            long      value = 0
    ) {
        super(context, symbol, _type);
        this._name_  = name;
        this._value_ = value;
    }

    override bool isAny() const => true;
}

class None : Token
{
    Context context;

    this () { super(this._context, "{~}", TokenType.None); }
    override bool isNone() const => true;
}

class Literal : Token
{
    private:
    string _name_;

    public:
    this(ref Context context, string symbol) {
        super(context, symbol, TokenType.Literal);
        this._name_ = "{L-"~symbol~"}";
    }

    string name() const => this._name_;

    override bool isLiteral() const => true;
}

interface ValueInterface {
    long value();
}

class Value : Token, ValueInterface
{
    protected:
    string _name;
    long   _value = 0;

    public:
    this(ref Context context, string symbol, long value) {
        super(context, "="~symbol, TokenType.Value);
        this._name  = "{V-"~symbol~"}";
        this._value = value;
        this._type  = TokenType.Value;
    }

    string name()  const => this._name;
    long   value() const => this._value;

    override bool isValue() const => true;
}

interface VariableInterface : ValueInterface {
    long value() const;
    void value(long new_value);
}

class Variable : Value, VariableInterface
{
    public:
    this(ref Context context, string symbol, string name) {
        super(context, symbol, 0);
        this._name  = "{R-"~name~"}";
    }

    override bool isVariable() const => true;
    override long value()      const => this._value;

    void value(long new_value) {
        this._value = new_value;
    }
}

interface RoutineInterface {
    T opRun(T: Token)();
    static bool exists(string name);
}

class Routine : Variable
{
    alias Callback = Token delegate(ref Context);

    protected:
    static SList!Routine routines;

    string   _name;
    Callback _callback;

    private:
    Token delegate(ref Context) _runner_;

    public:
    this(ref Context context, string name, long value, Callback dg) {
        super(context, "::"~name, name);
        this._runner_ = dg;
        this._name    = name;
        this._value   = value;
        this._type    = TokenType.Routine;

        bool has = false;
        if(!Routine.exists(name))
            Routine.routines.insertFront = this;
        else
            debug {
                import std.stdio;
                writefln("Routine [%s] already exists; ignored.", name);
            }
    }

    override bool isVariable() const => true;
    override bool isValue()    const => true;
    override bool isRoutine()  const => true;

    T opRun(T: Token)() {
        return this._runner_(this);
    }

    static bool exists(string name) {
        // if (name.startsWith("{")) ...
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
    bool checkValidity(Token[] token ...) {
        ulong valid = 0;
        foreach (Token t; token) {
            if (t.isError) {
                throw new Exception((cast(ErrorToken) t).message);
            }
            if (t._type != TokenType.Value || t._type != TokenType.Number) {
                valid += 1;
            }
        }
        return (valid == token.length);
    }

    protected:
    string _name;

    public:
    this(ref Context context, string symbol, string name = "Operator") {
        super(context, symbol, TokenType.Operator);
        this._name = "<O-"~name~"("~symbol~")>";
    }

    this(ref Context context, string symbol, TokenType type) {
        super(context, symbol, type);
        this.setNameByType();
    }

    protected void setNameByType() {
        switch(this._type) {
            case TokenType.Operator:
                // ERROR
                break;
            case TokenType.MathOperator:
                this._name = "<O-MathOperator("~symbol~")>";
                break;
            case TokenType.LogicOperator:
                this._name = "<O-LogicOperator("~symbol~")>";
                break;
            case TokenType.UnaryOperator:
                this._name = "<O-UnaryOperator("~symbol~")>";
                break;
            case TokenType.StackOperator:
                this._name = "<O-StackOperator("~symbol~")>";
                break;
            case TokenType.SpecialOperator:
                this._name = "<O-SpecialOperator("~symbol~")>";
                break;
            default:
                errorf("Unsupported (operator) type.");
                this._name = "<E-Unsupported("~symbol~")>";
        }
    }

    override bool isOperator() const => true;
    
    string name() => this._name;

    Token opOperate(string operator)(Token[] token ...) {
        if (this._type == TokenType.MathOperator) {
            if (token.length < 2) {
                return new ErrorToken(this._context, "<InvalidStack>", "Two (2) token required.");
            }

            switch(operator) {
                case "+":
                    if (!this.checkValidity(token[0], token[1])) {
                        return new ErrorToken(this._context, "<InvalidTokenType>", "Token must be of type `Value` or `Number`.");
                    }

                    Token a = token[0].asValue();
                    Token b = token[1].asValue();

                    return new Value(a + b);
                break;
                case "-":
                    if (!this.checkValidity(token[0], token[1])) {
                        return new ErrorToken(this._context, "<InvalidTokenType>", "Token must be of type `Value` or `Number`.");
                    }

                    Token a = token[0].asValue();
                    Token b = token[1].asValue();

                    return new Value(a - b);
                break;
                case "*":
                    if (!this.checkValidity(token[0], token[1])) {
                        return new ErrorToken(this._context, "<InvalidTokenType>", "Token must be of type `Value` or `Number`.");
                    }

                    Token a = token[0].asValue();
                    Token b = token[1].asValue();

                    return new Value(a * b);
                break;
                case "/":
                    if (!this.checkValidity(token[0], token[1])) {
                        return new ErrorToken(this._context, "<InvalidTokenType>", "Token must be of type `Value` or `Number`.");
                    }

                    Token a = token[0].asValue();
                    Token b = token[1].asValue();

                    return new Value(a / b);
                break;
                default:
                    static import std.format;
                    return new ErrorToken(this._context, "<InvalidOperator>", "Invalid math operator [%s].".format(operator));
            }
        }
        // TODO - StackOperator
        else if (this._type == TokenType.StackOperator) {
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
                    return new ErrorToken(this._context, "<InvalidOperator>", "Invalid stack operator [%s].".format(operator));
            }
        }
        // TODO - UnaryOperator
        else if (this._type == TokenType.UnaryOperator) {
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
                    return new ErrorToken(this._context, "<InvalidOperator>", "Invalid unary operator [%s].".format(operator));
            }
        }
        else {
            return new ErrorToken(this._context, "<InvalidToken>", "Invalid token [%s].".format(operator));
        }
    }

    override TokenType[] expect() {
        switch(this._name) {
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

// TODO
TList create(TList, TType)(TType a, ...) {
    return cast(TList) _arguments;
}
