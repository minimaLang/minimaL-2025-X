module minimal.interpreter;

public const VERSION = "0.2025.0";
public const BUILD   = "alpha0";

public import minimal.interpreter.interpreter : Interpreter;
debug {
    import minimal.token.token : RawSeq;

    import std.path;

    int dllmain () {
        return 0;
    }

    int main(string[] args) {
        import std.stdio : writeln;
        import std.string : splitLines, split;
        import minimal.token.token : Token;
        import minimal.token.tokenizer : Context, Tokenizer;

        Context     context;
        RawSeq      splitted  = cast(RawSeq) args[1].split();
        Tokenizer   tokenizer = new Tokenizer(splitted, context);
        writeln(tokenizer.raw);
        writeln("Hello.");
        Interpreter interpreter = new Interpreter(tokenizer);
        interpreter.run();
        writeln("Bye.");

        return 0;
    }
}
