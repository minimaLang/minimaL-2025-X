module minimal.tokenizer;

public import minimal.tokenization.types;
public import minimal.tokenization.tokenizer;


debug {
    import std.stdio : writeln;
    import std.array : split;

    Context context;

    int main(string[] args) {
        writeln("Hello Tokenizer!\n");

        string[] sliced;
        if(args.length == 2) {
            sliced = args[1].split(" ");
        }
        else {
            sliced = args[1..$];
        }

        Tokenizer tokenizer = new Tokenizer(context, sliced);
        tokenizer.tokenize();

        writeln(tokenizer);

        return 0;
    }
}
