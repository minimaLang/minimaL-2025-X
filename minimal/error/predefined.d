module minimal.error.predefined;

import minimal.error.type    : IError, ErrorLevel;
import minimal.error.errors  : ErrorClass;

final class InputError  : IError, ErrorClass!("Input",  ErrorLevel.Error) {}
final class SyntaxError : IError, ErrorClass!("Syntax", ErrorLevel.Error) {}


void log(in TContext context) {
    import std.logger : infof, warningf, errorf, criticalf;
    debug import std.stdio : writefln;
    import std.typecons : tuple, Tuple;

    Tuple c = tuple(context.line, context.column, context.file);

    switch(this.level) {
        case ErrorLevel.OK:
            debug writeln("OK \"%s\" >", this.messagef);
        break;
        case ErrorLevel.Info:
            infof(   "%s; at %s:%s in `%s`", this.messagef, c.expand);
        break;
        case ErrorLevel.Warning:
            warningf("%s; at %s:%s in `%s`", this.messagef, c.expand);
        break;
        case ErrorLevel.Error:
            errorf(  "%s; at %s:%s in `%s`", this.messagef, c.expand);
        break;
        case ErrorLevel.Critical:
        goto default;
        default:
            criticalf(ERRMESSAGE_FMT_NONCATCHABLE[0], ERRMESSAGE_FMT_NONCATCHABLE[1], this.code, this.message);
    }
}
