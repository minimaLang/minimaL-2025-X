module minimal.token.token;

import std.container.array : Array;

alias Raw      = string;
alias RawSeq   = Array!Raw;
alias TokenSeq = Array!Token;

enum MathOperator {
    Add,
    Multiply,
    Sub,
    Divide,
}

enum StackOperator {
    Pop, Push, Drop, Flush
}

enum Source : char {
    Builtin     = 'B',
    UserDefined = 'U',
    Imported    = 'I', // TODO - Imported from a script.
    Unknown     = '?',
    RoutineCall = 'R',
}

enum TopCategory {
    Unknown,

    Literal,  // Pops:  0
    Operator, // Pops:  1, 2..n
    Routine,  // Pops:  0..n
    Comment,

    Special,
    UserDefined,
}

enum SubCategory {
    Unknown,

    Line,  // ex. <code> ; <comment>
    Block, // ex. `Hello World', ;l Hello World .l

    Digit,
    Letter,

    Stack,
    Math,
    Logic,
    Bitwise,
    Evaluation,

    Special,
    UserDefined,

    Space,
    Newline,

    NotApplicable
}

enum BuiltinSingleGroup : dchar {
    None = '\0',

    StackPop   = '^',
    StackPush  = '.',
    StackDrop  = '~',
    StackFlush = '#',

    MathAdd = '+',
    MathSub = '-',
    MathMul = '*',
    MathDiv = '/',
    MathMod = '%',

    LogicTrue  = '?',
    LogicFalse = '!',

    BitwiseAnd = '&',
    BitwiseOr  = '|',
    BitwiseXor = '\\',

    EvalNow = '=',
    EvaNext = ':',

    Space    = ' ',
    Newline  = '\n',
    Newline1 = '\r',
}

enum BuiltinCombinedGroup : dchar[2] {
    None = ['\0','\0'],

    StackClear = ['~','#'],

    MathPow = ['*','*'],

    LogicAnd = ['&','&'],
    LogicOr  = ['|','|'],
    LogicXor = ['/','/'],
    LogicNot = ['!','!'],

    PopOnTrue    = ['?','^'],
    PopOnFalse   = ['!','^'],
    PushOnTrue   = ['?','.'],
    PushOnFalse  = ['!','.'],
    DropOnTrue   = ['?','~'],
    DropOnFalse  = ['!','~'],
    FlushOnTrue  = ['?','#'],
    FlushOnFalse = ['!','#'],

    AddOnTrue  = ['?','+'],
    AddOnFalse = ['!','+'],

    SubOnTrue  = ['?','-'],
    SubOnFalse = ['!','-'],

    MulOnTrue  = ['?','*'],
    MulOnFalse = ['!','*'],

    DivOnTrue  = ['?','/'],
    DivOnFalse = ['!','/'],

    ModOnTrue  = ['?','%'],
    ModOnFalse = ['!','%'],

    ContinueOnTrue  = ['?',':'],
    ContinueOnFalse = ['!',':'],

    IgnoreNextOnTrue  = ['?',';'],
    IgnoreNextOnFalse = ['!',';'],

    Space   = [' ', ' '],
    Newline = ['\r', '\n'],
}

const string NEWLINES = "\r\n";

class KnownToken (Raw raw, uint required: 1, uint optional: 1) : Token {

    this() {
        this.raw = raw;
        this._pops_required_ = required;
        this._pops_optional_ = optional;
    }
}

struct TokenData {
    private string[] _extra_ = [];

    Raw         raw;
    TopCategory topcat;
    SubCategory subcat;
    Source      source;

    uint pops_required = 1;
    uint pops_optional = 0;

    inout(string[]) extra() inout => _extra_;
}

class Token {

    protected {
        TokenData _data_;
        string _qualified_name_;
    }

    uint pops_required()    const => this._data_.pops_required;
    uint pops_optional()    const => this._data_.pops_optional;
    inout(string[]) extra() inout => this._data_.extra;

    bool unknown()
        => this._data_.topcat == TopCategory.Unknown
        && this._data_.subcat == SubCategory.Unknown;

    immutable(Raw)         raw()    const pure @safe @nogc nothrow
        => cast(immutable) _data_.raw;
    immutable(TopCategory) topcat() const pure @safe @nogc nothrow
        => cast(immutable) _data_.topcat;
    immutable(SubCategory) subcat() const pure @safe @nogc nothrow
        => cast(immutable) _data_.subcat;
    immutable(Source)      source() const pure @safe @nogc nothrow
        => cast(immutable) _data_.source;

    immutable(string) qualified_name() const @nogc @safe pure nothrow
        => this._qualified_name_;

    override string toString() const @nogc @safe pure nothrow {
        return this.raw;
    }

    string opCast() const {
        return this.raw;
    }

    override bool opEquals(Object other) const {
        if(!is(other : Token) || !is(other : string)) return false;
        return false;
    }

    bool opEquals(Token other) const {
        return (this.raw == other.raw);
    }

    bool opEquals(string other) const {
        return (this.raw == other);
    }

    override size_t toHash() const @nogc @safe pure nothrow {
        return hashOf(this.qualified_name);
    }

    this(
        Raw raw,
        immutable(TopCategory) topcat,
        immutable(SubCategory) subcat,
        immutable(Source)      source,
        uint required_pops,
        uint optional_pops,
    ) {
        this._data_.raw    = raw;
        this._data_.topcat = topcat;
        this._data_.subcat = subcat;
        this._data_.source = source;
        this._data_.pops_required = required_pops;
        this._data_.pops_optional = optional_pops;
        this.createQualifiedName();
    }

    protected void createQualifiedName() {
        import std.format : format;
        import std.conv   : to;

        this._qualified_name_ =
            "%s-top:%s-sub:%s-src:%s-(%s,%s)".format(
                this.raw,
                this._data_.topcat.to!string,
                this._data_.subcat.to!string,
                this._data_.source.to!string,
                this._data_.pops_required.to!string,
                this._data_.pops_optional.to!string
            );
    }
}

class Literal  (Raw token) : Token {}
class Operator (Raw token, uint required, uint optional = 0)
    : Token!(token, required, optional) {}

class Imported (Raw token) : Token {}
class Routine (Raw token) : Token {

    string[uint] parameter = null;
    string[uint] values    = null;
    string       returns   = null;
}

class Digit   (Raw token) : Literal!token {}
class Letter  (Raw token) : Literal!token {}
class Other   (Raw token) : Literal!token {}

class Stackop (Raw token) : Operator!(token, 1, 2) {}
class Mathop  (Raw token) : Operator!(token, 2)    {}
class Logicop (Raw token) : Operator!(token, 2)    {}
class Evalop  (Raw token) : Operator!(token, 1, 2) {}
class Binop   (Raw token) : Operator!(token, 1, 2) {}
class Condop  (Raw token) : Operator!(token, 1, 2) {}

alias Unknown = noreturn;
alias TokenizeDg = bool delegate(in Raw);
alias IdentifyDg =
    bool delegate(
        out BuiltinSingleGroup,
        out BuiltinCombinedGroup,
    );

abstract class TokenizerClass {
    abstract bool tokenize(TokenizeDg);
    abstract bool identify(IdentifyDg);
}

class KnownTokenRegistry {
    private import std.array;

    private TokenSeq list = TokenSeq();

    void register(Token token) {
        list.insertBack(token);
    }

    Token getAt(ulong index) {
        import std.exception : enforce;
        enforce(
            index < this.list.length,
            "Index out of bounds in KnownTokenRegistry.");
        return this.list[index];
    }

    bool byCategory(
        out Token token,
            TopCategory topcat,
            SubCategory subcat = SubCategory.NotApplicable,
            Source      source = Source.Unknown,
    ) {
        foreach (_token; this.list) {
            if (_token.topcat == topcat) {
                if (
                    (_token.subcat == SubCategory.NotApplicable
                    || _token.subcat == subcat
                    ) && (_token.source == source)
                ) {
                    token = _token;
                    return true;
                }
            }
        }
        return false;
    }

    bool byString(Raw str, out Token token) {
        foreach (_token; this.list) {
            if (_token == str) {
                token = _token;
                return true;
            }
        }
        return false;
    }
}

public const knownTokenRegistry = new KnownTokenRegistry();
