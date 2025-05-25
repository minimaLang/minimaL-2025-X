module minimal.token.tokenizer;

import minimal.token.token : Identity, Token, Raw, RawSeq, TokenSeq;
import std.uni : isAlphaNum, isAlpha, isNumber;

import std.array : appender, array, split;

debug import std.stdio;

enum State {
    JustInitiated,

    Started,
    Tokenizing,
    Done,
}


class Tokenizer {

    protected TokenSeq _tseq  = null;
    protected RawSeq   _rseq  = null;
    protected Raw      _raw   = "";

    protected ulong _pos   = 0;
    protected ulong _len   = 0;
    private   State _state = State.JustInitiated;

    @property TokenSeq tokenseq() => _tseq;
    @property RawSeq   rawseq()   => _rseq;

    @property State  state()    => _state;
    @property ulong  position() => _pos;
    @property ulong  length()   => _rseq.length;
    @property string current()  => _rseq[_pos-1];

    this (string[] raw) {
        _rseq = raw;
    }

    bool next() {
        if (state != State.Started) _pos += 1;

        Identity identity = Identity.Unknown;

        bool valid = ensureValidPosition();
        if (valid) {
            if (!identify(identity)) return false;
            return (_state != State.Done);
        }

        nextState();
        return false;
    }

    protected void nextState() {
        switch (_state) {
            case State.JustInitiated:
                _state = State.Started;
                break;
            default:
                _state = State.Tokenizing;
        }
    }

    protected bool identify(out Identity identity) {
        ulong index = -1;
        ulong line  = -1;

        foreach (c; current.split())
        {
            index += 1;

            if (state == State.Done) return false;

            if (c == "") {
                identity = Identity.Space;
                debug writeln("Empty");
            }
            else if (c.length == 1 && isAlpha(c[0])) {
                identity = Identity.Alpha;
                debug writeln("Alpha    ", c);
                // ...
            }
            else if (c.length == 1 && isNumber(c[0])) {
                identity = Identity.Number;
                debug writeln("Number    ", c);
                // ...
            }
            else if (c.length >= 2 && (isAlphaNum(c[0]) && isAlphaNum(c[1])) ) {
                identity = Identity.AlphaNum;
                debug writeln("AlphaNum  ", c);
            }
            else if (c.length == 1 && c == "#") {
                identity = Identity.EndEval;
                _state = State.Done;
                debug writeln("EndEval   ", c);
                return false;
            }
            else {

                if (identifyStackOperator(current, _state)) {
                    identity = Identity.StackOperator;
                    debug writeln("StackOp   ", c);
                }
                else if (identifyMathOperator(current)) {
                    identity = Identity.MathOperator;
                    debug writeln("MathOp    ", c);
                }
                else if (current == ";") {
                    identity = Identity.LineEnd;
                    debug writeln("LineEnd   ", c);

                }
                else if (current == "=") {
                    identity = Identity.Evaluator;
                    debug writeln("Evaluator ", c);
                }
                else {

                    switch (current) {
                        case "\n", "\r\n", "\r":
                            line += 1;
                            continue;
                        case " ", "", "\0": // ...
                            debug writeln("Empty     ");
                        break;

                        case ",": // ...
                        break;

                        case ":": // Continue
                        break;

                        case "?": // Condition
                        break;

                        case "!": // Command
                        break;

                        case "$": // Jump Execute
                        break;

                        case "&": // Jump Target (Label)
                        break;

                        default:
                            debug writefln(
                                "Not implemented: Token [%s]", current);
                        identity = Identity.Unknown;
                        return false;
                    }
                }
            }

            this._rseq[index] = c;
            this._tseq[c] = Token(c, identity);
        }

        return true;
    }

    protected bool identifyStackOperator(in char[] c, out State state) nothrow {
        if (c.length > 1) return false;

        switch (c[0]) {
            case '^', '.', '~':
                return true;
            case '#':
                state = State.Done;
                // TODO
                return true;
            default:
                return false;
        }
    }

    protected bool identifyMathOperator(in char[] c) const nothrow {
        if (c.length > 1) return false;

        switch (c[0]) {
            case '*', '/', '+', '-', '%':
                return true;
            default:
                return false;
        }
    }

    bool ensureValidPosition() {
        bool valid = (_pos + 1 <= _rseq.length);

        if (valid) {
            _pos += 1;
            return true;
        }
        else {
            debug writefln("Info: Invalid position %d.", _pos);
            return false;
        }
    }
}

class Index {

}
