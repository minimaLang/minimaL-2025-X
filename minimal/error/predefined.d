module minimal.error.predefined;

public import minimal.error.errors : BaseError, Context, ErrorLevel, ErrorList;

final class InputError  : BaseError
{
    this(string message, uint code, ulong line, ulong column) {
        Context context;
        super(message, code, ErrorLevel.Error, context);
        context.set(line, column, 0);
    }

    override bool catchable() => true;
}

final class SyntaxError : BaseError
{
    this(string message, uint code, ulong line, ulong column) {
        Context context;
        super(message, code, ErrorLevel.Error, context);
        context.set(line, column, 0);
    }

    override bool catchable() => false;
}
