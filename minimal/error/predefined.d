module minimal.error.predefined;

import minimal.error.errors;

final class InputError  : BaseError
{
    this(string message, uint code, ulong line, ulong column) { 
        super(message, code, line, column);
    }
    override bool catchable() => true;
}

final class SyntaxError : BaseError
{
    this(string message, uint code, ulong line, ulong column) { 
        super(message, code, line, column);
    }
    override bool catchable() => false;
}
