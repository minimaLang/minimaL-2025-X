module minimal.error.predefined;

import minimal.error.errors;

final class InputError  : BaseError
{
    override bool catchable() => true;
}

final class SyntaxError : BaseError
{
    override bool catchable() => false;
}
