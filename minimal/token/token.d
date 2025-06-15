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

// ---

import std.logger : FileLogger;
import std.file;

FileLogger error = new FileLogger(stderr);
FileLogger info  = new FileLogger(stdout);

interface Token {}

class Identifier
{
    private Token   _current_;
    private RawData _raw_ = "";
    private bool    _identified_ = false;

    bool next() {
        this.identify(this._raw_.back);

        if (!this._identified_) {
            errorf("Could not identify token `[%s]`.", raw);
            return false;
        }

        this._raw_.removeBack();
        return true;
    }

    protected void identify(Raw raw) {
        this._identified_ =
               this.identifyLiteral(raw)
            || this.identifyOperator(raw)
            || this.identifyImported(raw)
            || this.identifyRoutine(raw)
    }

    protected bool identifyLiteral(raw) {
        info.log("Not yet implemented.");
    }

    protected bool identifyOperator(raw) {
        info.log("Not yet implemented.");
    }

    protected bool identifyImported(raw) {
        info.log("Not yet implemented.");
    }

    protected bool identifyRoutine(raw) {
        info.log("Not yet implemented.");
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
