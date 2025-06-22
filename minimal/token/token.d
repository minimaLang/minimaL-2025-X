module minimal.token.token;

import std.algorithm.searching : canFind;
import std.container.slist : SList;
import std.functional : memoize;

//import std.file;
//import std.logger : FileLogger;
debug import std.logger : error, errorf, warning, warningf, info, infof;
debug import std.stdio : writeln, writefln;

const string NEWLINES = "\r\n";

import std.container.array : Array;

const string DIGITS
    = "0123456789";
const string LETTERS_LOWER
    = "abcdefghijklmnopqrstuvwxyz";
const string LETTERS_UPPER
    = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
const string LETTERS = LETTERS_LOWER ~ LETTERS_UPPER;

const string STACKOPS  = "^.~#";
const string MATHOPS   = "+-*/%";
const string LOGICOPS  = "&|\\!";
const string BINOPS    = "?!";
const string EVALOPS   = "=:";
const string OPERATORS = MATHOPS ~ STACKOPS ~ LOGICOPS ~ EVALOPS;

const string LINESEPS   = "\r\n";
const string COLSEPS    = "\t\v ";
const string SEPARATORS = LINESEPS ~ COLSEPS;


enum Command {
    Continue,
    Ignore,
    Halt,
    Drop,
}

enum Condition : uint {
    False,
    True,
    Any = 9,
}

struct SimpleCombo {
    string    sym;
    Command   cmd;
    Condition cat;
}

const SimpleCombo[] SIMPLECOMBOS = [
    SimpleCombo (
        "?:",
        Command.Continue,
        Condition.True,
    ),
    SimpleCombo (
        "!:",
        Command.Continue,
        Condition.False,
    ),
    SimpleCombo (
        "?;",
        Command.Ignore,
        Condition.True,
    ),
    SimpleCombo (
        "!;",
        Command.Ignore,
        Condition.False,
    ),
    SimpleCombo (
        "?.",
        Command.Halt,
        Condition.True,
    ),
    SimpleCombo (
        "!.",
        Command.Halt,
        Condition.False,
    ),
    SimpleCombo (
        "?~",
        Command.Drop,
        Condition.True,
    ),
    SimpleCombo (
        "!~",
        Command.Drop,
        Condition.False,
    ),
];

alias TTokenStack  = SList!Token;
alias TStringStack = SList!string;

alias TStringData = Data!(TStringStack, string, string);
alias TTokenData  = Data!(TTokenStack,  Token,  string);

enum TokenType {
    LineEnd,
    Literal,
    Operator,
}

interface Token
{
    string value();
    void   value(string s);
    bool   evaluate(ref TStringStack);

    T opCast(T: const(string))() const;
    T opCast(T: const(Object))() const;

    bool opEquals(Token  other) const;
    bool opEquals(string other) const;

    int opApply(scope int delegate(ref uint n) dg);

    TokenType type();
}

interface Data (TStack, TItem, TKey)
{
    void add(TItem item);
    bool empty();

    TItem get();
    TItem get(TKey);

    void ignoreLine();
    void ignoreLines(ulong);

    immutable(Data) data();
}

final class StringData : TStringData
{
    private TStringStack _stack_ = TStringStack();

    this() {}

    this(TStringStack stack) {
        this._stack_ = stack;
    }

    immutable(TStringStack) sequence() {
        return cast(immutable) this._stack_;
    }

    string get() {
        scope(exit) this._stack_.removeFront();
        return this._stack_.front;
    }

    string[] get(uint count) {
        debug if (count < 2) writeln("If lower than 2, you may use `get()` instead.");
        string[] result = [];
        for (uint i; (count > 0) && (!this._stack_.empty); count -= 1) {
            result[i] = this._stack_.front;
            this._stack_.removeFront();
        }
        return result;
    }

    void ignoreLine() {
        foreach (c; this._stack_) {
            if (LINESEPS.canFind(c)) return;
        }
    }

    void ignoreLines(ulong count) {
        if(!this._stack_.empty && count > 0) {
            debug writeln("Stack is empty.");
            return;
        }

        foreach (c; this._stack_) {
            if (count != 0 && LINESEPS.canFind(c)) {
                count -= 1;
                continue;
            }
        }
    }

    void add(string item) {
        this._stack_.insertFront(item);
    }

    bool empty() {
        return this._stack_.empty;
    }

    immutable(StringData) copy() {
        return cast(immutable) this;
    }
}

final class TokenData : TTokenData {
    private TTokenStack _stack_ = TTokenStack();

    this() {}

    this(TTokenStack stack) {
        this._stack_ = stack;
    }

    immutable(TTokenStack) sequence() {
        return cast(immutable) this._stack_;
    }

    Token get() {
        scope(exit) this._stack_.removeFront();
        return this._stack_.front;
    }

    Token[] get(uint count) {
        debug if (count < 2) writeln("If lower than 2, you may use `get()` instead.");
        Token[] result = [];
        for (uint i; (count > 0) && !this._stack_.empty; count -= 1) {
            result[i] = this._stack_.front;
            this._stack_.removeFront;
        }
        return result;
    }

    void ignoreLine(Token t) {
        if (LINESEPS.canFind(t.value)) this._stack_.removeFront;
    }

    void ignoreLines(ulong count) {
        ulong length = this._stack_.empty;
        if(length == 0 && count > 0) {
            debug writefln("Count [%s] is too high; contains only [%s] items.", length, count);
            return;
        }
        foreach (Token c; this._stack_) {
            if (count != 0 && LINESEPS.canFind(c.value)) {
                count -= 1;
                continue;
            }
        }
    }

    void add(Token item)
    in {
        static foreach(Token t; this._stack_) {
            static if (t.value == t.value) return false;
        }
    }
    do {
        this._stack_.insertFront(item);
    }

    bool empty() { return this._stack_.empty; }

    TokenData createAndAdd(string str) {
        debug writefln("Token [%s] created.", str);
        this._stack_.insertFront(TokenData.create(str));
        return this;
    }

    static Token create(string str) {
        return new TokenData(str);
    }
}

class Identifier
{
    static bool identify(string str, out Token current) {
        return
               Identifier.identifySingle(str, current)
            || Identifier.identifyCombo(str, current)
            || Identifier.identifySpecial(str, current)
            ;
    }

    static bool identifySingle(string str, out Token current) {
        return
               Identifier.identifyEnds(str, current)
            || Identifier.identifyLiteral(str, current)
            || Identifier.identifyOperator(str, current)
            ;
    }

    static bool identifyEnds(string str, out Token current) {
        if (LINESEPS.canFind(str)) {
            current = new LineEnd!str;
            return true;
        }
        else if(COLSEPS.canFind(str)) {
            current = new ColumnEnd!str;
            return true;
        }
        return false;
    }

    static bool identifyLiteral(string str, out Token current) {
        if (DIGITS.canFind(str)) {
            current = new Digit!str;
            return true;
        }
        else if (LETTERS.canFind(str)) {
            current = new Letter!str;
            return true;
        }

        return false;
    }

    static bool identifyOperator(string str, out Token current) {
        if (STACKOPS.canFind(str)) {
            current = StackOperation!str;
            return true;
        }
        else if (MATHOPS.canFind(str)) {
            current = MathOperation!str;
            return true;
        }
        else if (BINOPS.canFind(str))  {
            current = BitwiseOperation!str;
            return true;
        }
        else if (LOGICOPS.canFind(str)) {
            current = LogicOperation!str;
            return true;
        }
        else if (EVALOPS.canFind(str)) {
            current = EvalOperation!str;
            return true;
        }

        return false;
    }

    static bool identifySpecial(string str, out Token current) {
        if (str.length < 2) return false;
        info.log("Not yet implemented.");
        return false;
    }

    static bool identifyCombo(string str, out Token current) {
        return
               this.identifySimpleCombo(str)
            || this.identifyImported(str)
            || this.identifyRoutine(str)
            ;
    }

    static bool identifySimpleCombo(string str, out Token current) {
        if (str.length < 3) return false;
        info.log("Not yet implemented.");
        return false;
    }

    static bool identifyImported(string str, out Token current) {
        info.log("Not yet implemented.");
        return false;
    }

    static bool identifyRoutine(string str, out Token current) {
        info.log("Not yet implemented.");
        return false;
    }
}


final class Literal : Token {
    protected string _value;

    override bool _evaluate(ref TTokenStack stack) {
        this._value = stack.front.value;
        return true;
    }

    override string value() const => this._value.value;
}

interface Operator (string token, uint required_pops, uint optional_pops = 0) : Token {}
interface End : Token {}

final class Unknown : TokenBase, Token {
    override bool   evaluate(ref TTokenStack stack) { return false;       }
    override string value() const                   { return this._value; }
             void   value(string s)                 { this._value = s;    }
}

final class Comment : Token {
    protected string _token   = ";";
    protected string _comment = "";

    this(Token token) {
        this._token = cast(string) token;
    }

    override bool evaluate(ref TTokenStack stack) {
        import std.range : back;
        foreach (Token c; stack.peek) {
            if (LINESEPS.canFind(c.value)) return true;
            this._comment.back(c.value);
        }
        return true;
    }

    override string value() const { return this._comment; }
}

final class LineEnd : End {
    override bool evaluate(ref TStringStack stack) {
        string token = stack.front;
        switch (token) {
            case "\n":
            goto case;
            case "\r":
            goto case;
            case "\r\n":
                stack.removeFront();
            break;
            default:
                debug writefln("Unknown `LineEnd` [%s].", token);
        }
    }
}

final class ColumnEnd : End {
    override bool evaluate(ref TStringStack stack) {
        if (token == ";")
            stack.front = new Comment!token(_poped);
    }
}

final class Imported (string token) : Token
{
    this() { debug writeln("Not yet implemented."); }
}

final class Routine (string token) : Token
{
    string[uint] parameter = null;
    string[uint] values    = null;
    string       returns   = null;
}

final class Digit (string token) : Literal!token
{
    this() { debug writeln("Not yet implemented."); }
}

final class Letter (string token) : Literal!token
{
    this() { debug writeln("Not yet implemented."); }
}

struct OperationError {
    string message;
    uint   code;
}

abstract class Operator (string token, uint reqpops) : Token
{
    const ERROR_MESSAGE = "Unsupported [%s] operator of [%s]";

    alias doToken  = this.opDo!token;
    alias memoized = memoize!doToken;

    protected TStringStack* _stack;
    protected OutBuffer*    _buffer;

    protected OperationError error;

    this(OutBuffer* buffer, TStringStack* stack) {
        this._buffer = buffer;
        this._stack  = stack;
    }

    bool evaluate() const {
        return this.opEvaluate!token;
    }

    uint required_pops() { return reqpops; }

    abstract bool opEvaluate(string operator = token)();
}

import std.outbuffer : OutBuffer;

final class StackOperation (string token) : Operator!(token, 1)
{
    bool opEvaluate(string operator) {
        import std.variant : Variant;
        Variant x = this._stack_.front();

        switch(operator) {
            case ".":

            break;
            case "^":
                info("[^] may not be implemented; but as `swap` operator.");
                return false;
            break;
            case "~":

            break;
            case "#":

            break;
            default:
                errorf(Operator.ERROR_MESSAGE, "stack", operator);
                return false;
        }
    }

    bool opEvaluate(string operator = ".")() {
        foreach (ref string result; this._eval_) {
            this._buffer_.writeln(result);
        }
        return true;
    }

    bool opEvaluate(string operator = "~") {
        for (uint index; index < this._eval_.length; index += 1) {
            this._stack_.front = "";
        }
        return false;
    }

    bool opEvaluate(string operator = "#") {
        foreach (ref string result; this._stack_) {
            this._buffer_.writeln(result);
        }
        return true;
    }
}

final class MathOperation (string token) : Operator!(token, 2)
{
    bool opEvaluate(string operator)() {
        int a = cast(int) this._stack_.front();
        this._stack_.removeFront();
        int b = cast(int) this._stack_.front();
        this._stack_.removeFront();

        switch(token) {
            case "+":
                this._value = a + b;
                return true;
            case "-":
                this._value = a - b;
                return true;
            case "*":
                this._value = a * b;
                return true;
            case "/":
                this._value = a / b;
                return true;
            case "^^": // (a) pow (b)
                this._value = a ^^ b;
                return true;
            default:
                errorf(Operator.ERROR_MESSAGE, "math", token);
                return false;
        }
    }
}

final class LogicOperation (string token) : Operator!(token, 2)
{
    bool opEvaluate(string operator)() {
        bool a = cast(bool) this._stack_.front();
        this._stack_.removeFront();

        bool b = cast(bool) this._stack_.front();
        this._stack_.removeFront();

        switch (operator) {
            case "&&":
                this._value = cast(string) (a && b);
            break;
            case "||":
                this._value = cast(string) (a || b);
            break;
            case "\\":
                this._value = cast(string) (a ^ b);
            break;
            case "!&":
                this._value = cast(string) (!a && b);
            break;
            case "&!":
                this._value = cast(string) (a && !b);
            break;
            case "!|":
                this._value = cast(string) (!a || b);
            break;
            case "|!":
                this._value = cast(string) (a || !b);
            break;
            case "!\\":
                this._value = cast(string) (!a ^ b);
            break;
            case "\\!":
                this._value = cast(string) (a ^ !b);
            break;
            case "==":
                this._value = cast(string) (a == b);
            break;
            case "!=", "=!":
                this._value = cast(string) (a != b);
            break;
            default:
                errorf(Operator.ERROR_MESSAGE, "logic", token);
                return false;
        }

        return true;
    }
}

final class UnaryOperation (string token) : Operator!(token, 1)
{
    bool opEvaluate(string operator)() {
        bool x = cast(bool) this._stack_.front();

        switch(operator) {
            case "!", "!!":
                this._value = cast(string) x == false;
            case "?", "??":
                this._value = cast(string) x == true;
            break;
            default:
                errorf(Operator.ERROR_MESSAGE, "unary", token);
                return false;
        }

        return true;
    }
}

final class EvaluationOperation  (string token) : Operator!(token, 1) {}
final class BitwiseOperation     (string token) : Operator!(token, 1) {}
final class ConditionalOperation (string token) : Operator!(token, 1) {}


abstract class TokenizerClass {
    abstract bool tokenize();
    abstract bool identify();
}
