module minimal.tokenization.types;

import std.container.slist : SList;
import std.outbuffer       : OutBuffer;
import std.logger          : errorf, warningf, infof;
import std.format          : format;
import std.conv            : to;
import core.vararg;

import minimal.error.predefined : SyntaxError, InputError;

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

final class State
{
    private:
    ulong _line_     = 0;
    ulong _column_   = 0;
    ulong _position_ = 0;
    bool  _failed_   = false;

    InputError  _input_error_;
    SyntaxError _syntax_error_;

    public:
    this() { this(0, 0); }

    this(ulong line, ulong column, ulong position = 0, bool failed = false) {
        this._line_     = line;
        this._column_   = column;
        this._position_ = position;
        this._failed_   = failed;
    }

    void setError(InputError error) {
        this.markAsFailed();
        this._input_error_ = error;
    }

    void setError(SyntaxError error) {
        this.markAsFailed();
        this._syntax_error_ = error;
    }

    void markAsFailed() { this._failed_ = true; }
    bool hasFailed()   => this._failed_;

    ulong nextLine(ulong add = 1)
    in (add > 0) {
        this._line_ += add;
        return this._line_;
    }

    ulong nextColumn(ulong add = 1)
    in (add > 0) {
        this._column_ += add;
        return this._column_;
    }

    ulong nextPosition(ulong add = 1)
    in (add > 0) {
        this._position_ += add;
        return this._position_;
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

interface ContextInterface
{
    immutable(OutBuffer)   view();
    immutable(TokenStack)  tokens();
    immutable(StringStack) strings();

    bool failed();
    void nextState();

    void   write(string content);
    string read();
}

final class Context : ContextInterface
{
    private:
    StringStack _instack_  = StringStack();
    TokenStack  _outstack_ = TokenStack();
    OutBuffer   _view_     = new OutBuffer();
    State       _state_    = new State();

    static VariableList varlist = VariableList();
    static RoutineList  roulist = RoutineList();

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

    immutable(OutBuffer)   view()    => cast(immutable) this._view_;
    immutable(TokenStack)  tokens()  => cast(immutable) this._outstack_;
    immutable(StringStack) strings() => cast(immutable) this._instack_;

    bool failed() => this._state_.hasFailed;

    void   write(string content) { this._view_.write(content); }
    string read() => this._view_.toString;
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
                name = "<*>";
            }
            else if (this._type == TokenType.None) {
                name = "< >";
            }
            else if (this._type == TokenType.ERROR) {
                name = "<E>";
            }
            else {
                throw new Exception("Name is required!");
            }
        }

        this._name = name;
    }

    TokenType[] expect() => [TokenType.Any, TokenType.None];

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

    bool isAny() {
        static if (this.type == TokenType.Any) return true;
        return false;
    }

    bool isNone() {
        static if (this.type == TokenType.None) return true;
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
            string  name    = "E",
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

class Any : Token
{
    this (
        ref Context   context,
            string    symbol,
            TokenType type  = TokenType.Any,
            string    name  = "<*>",
            long      value = 0
    ) {
        super(context, symbol, type, name, value);
    }

    override bool isAny() => true;
}

class None : Token
{
    this () {
        super(new Context, symbol, type, name, value);
    }

    override bool isNone() => true;
}

class Literal : Token
{
    this (
        ref Context   context,
            string    symbol,
            TokenType type  = TokenType.Literal,
            string    name  = "<L>",
            long      value = 0
    ) {
        super(context, symbol, type, name, value);
    }

    this(ref Context context, string symbol, long value) {
        super(context, ".l"~symbol~"l.", TokenType.Literal, "<L>", value);
    }

    override bool isLiteral() => true;
}

class Value : Token
{
    this(ref Context context, long value) {
        super(context, "="~(value), TokenType.Value, "<V>", value);
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
                throw new Exception((cast(ErrorToken) t).message);
            }
            if (t.type != TokenType.Value || t.type != TokenType.Number) {
                valid += 1;
            }
        }
        return (valid == token.length);
    }

    public:
    this(ref Context context, string symbol, TokenType type = TokenType.Any) {
        super(context, symbol, type = TokenType.Any);
    }

    override bool isOperator() => true;

    Token opOperate(string operator)(Token token, ...) {
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

    override TokenType[] expect() {
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

VariableList createVarList(Variable a, ...) {
    return cast(VariableList) _arguments;
}

RoutineList createRoutineList(Routine a, ...) {
    return cast(RoutineList) _arguments;
}

ContextList createContextList(Context a, ...) {
    return cast(ContextList) _arguments;
}

module minimal.tokenization.types;

import std.container.slist : SList;
import std.outbuffer       : OutBuffer;
import std.logger          : errorf, warningf, infof;
import std.format          : format;
import std.conv            : to;
import core.vararg;

import minimal.error.predefined : SyntaxError, InputError;

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

final class State
{
    private:
    ulong _line_     = 0;
    ulong _column_   = 0;
    ulong _position_ = 0;
    bool  _failed_   = false;

    InputError  _input_error_;
    SyntaxError _syntax_error_;

    public:
    this() { this(0, 0); }

    this(ulong line, ulong column, ulong position = 0, bool failed = false) {
        this._line_     = line;
        this._column_   = column;
        this._position_ = position;
        this._failed_   = failed;
    }

    void setError(InputError error) {
        this.markAsFailed();
        this._input_error_ = error;
    }

    void setError(SyntaxError error) {
        this.markAsFailed();
        this._syntax_error_ = error;
    }

    void markAsFailed() { this._failed_ = true; }
    bool hasFailed()   => this._failed_;

    ulong nextLine(ulong add = 1)
    in (add > 0) {
        this._line_ += add;
        return this._line_;
    }

    ulong nextColumn(ulong add = 1)
    in (add > 0) {
        this._column_ += add;
        return this._column_;
    }

    ulong nextPosition(ulong add = 1)
    in (add > 0) {
        this._position_ += add;
        return this._position_;
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

interface ContextInterface
{
    immutable(OutBuffer)   view();
    immutable(TokenStack)  tokens();
    immutable(StringStack) strings();

    bool failed();
    void nextState();

    void   write(string content);
    string read();
}

final class Context : ContextInterface
{
    private:
    StringStack _instack_  = StringStack();
    TokenStack  _outstack_ = TokenStack();
    OutBuffer   _view_     = new OutBuffer();
    State       _state_    = new State();

    static VariableList varlist = VariableList();
    static RoutineList  roulist = RoutineList();

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

    immutable(OutBuffer)   view()    => cast(immutable) this._view_;
    immutable(TokenStack)  tokens()  => cast(immutable) this._outstack_;
    immutable(StringStack) strings() => cast(immutable) this._instack_;

    bool failed() => this._state_.hasFailed;

    void   write(string content) { this._view_.write(content); }
    string read() => this._view_.toString;
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
                name = "<*>";
            }
            else if (this._type == TokenType.None) {
                name = "< >";
            }
            else if (this._type == TokenType.ERROR) {
                name = "<E>";
            }
            else {
                throw new Exception("Name is required!");
            }
        }

        this._name = name;
    }

    TokenType[] expect() => [TokenType.Any, TokenType.None];

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

    bool isAny() {
        static if (this.type == TokenType.Any) return true;
        return false;
    }

    bool isNone() {
        static if (this.type == TokenType.None) return true;
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
            string  name    = "E",
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

class Any : Token
{
    this (
        ref Context   context,
            string    symbol,
            TokenType type  = TokenType.Any,
            string    name  = "<*>",
            long      value = 0
    ) {
        super(context, symbol, type, name, value);
    }

    override bool isAny() => true;
}

class None : Token
{
    this () {
        super(, symbol, type, name, value);
    }

    override bool isNone() => true;
}

class Literal : Token
{
    this (
        ref Context   context,
            string    symbol,
            TokenType type  = TokenType.Literal,
            string    name  = "<L>",
            long      value = 0
    ) {
        super(context, symbol, type, name, value);
    }

    this(ref Context context, string symbol, long value) {
        super(context, ".l"~symbol~"l.", TokenType.Literal, "<L>", value);
    }

    override bool isLiteral() => true;
}

class Value : Token
{
    this(ref Context context, long value) {
        super(context, "="~(value), TokenType.Value, "<V>", value);
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
                throw new Exception((cast(ErrorToken) t).message);
            }
            if (t.type != TokenType.Value || t.type != TokenType.Number) {
                valid += 1;
            }
        }
        return (valid == token.length);
    }

    public:
    this(ref Context context, string symbol, TokenType type = TokenType.Any) {
        super(context, symbol, type = TokenType.Any);
    }

    override bool isOperator() => true;

    Token opOperate(string operator)(Token token, ...) {
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

    override TokenType[] expect() {
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

VariableList createVarList(Variable a, ...) {
    return cast(VariableList) _arguments;
}

RoutineList createRoutineList(Routine a, ...) {
    return cast(RoutineList) _arguments;
}

ContextList createContextList(Context a, ...) {
    return cast(ContextList) _arguments;
}

alias VariableList = Variable[string];
alias RoutineList  = Routine [string];
alias ContextList  = Context [string];
alias StringStack  = string[];
alias TokenStack   = Token[];
