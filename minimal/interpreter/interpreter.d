module minimal.interpreter.interpreter;

import std.algorithm.searching : canFind;
import minimal.token.tokenizer : Tokenizer;
import minimal.token.token : IToken;

interface Interface
{
    bool done();
    bool failed();
    void run();
}

class Interpreter : Interface
{
    bool done();
    bool failed();
    void run();
}
