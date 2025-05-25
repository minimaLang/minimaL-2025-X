module minimal.token.token;


alias Raw      = string;
alias RawSeq   = Raw[512];
alias TokenSeq = Token[Raw];

enum Identity {
    Alpha,
    Number,
    AlphaNum,

    StackOperator,
    MathOperator,
    Evaluator,

    LineEnd,
    Space,

    EndEval,
    Unknown
}

struct Token {
    protected Raw      _raw;
    protected Identity _identity;

    @property immutable(Raw)      raw()
        => cast(immutable(Raw)) _raw;
    @property immutable(Identity) identity()
        => cast(immutable(Identity)) _identity;
}
