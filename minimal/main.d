module minimal.main;


import std.string :
    empty,      endsWith,
    strip,      split,
    splitLines, format,
    replace,    soundex
;

import std.getopt : getopt, config, Option;
import std.stdio : writeln, writefln;
import std.exception;

import minimal;

public const SPECVER = "0-2025-0";

public const VERSION = "0.2025.0";
public const BUILD   = "alpha0";

public const HTTP = "https://github.com/minimaLang/";
public const NAME = "Hello minimaL";
public const CLI  = "hello";

public const DESC = `
...
minimaL  %s-%s %%-%s

minimaL is an RPN (Reverse Polish Notation) interpreter.
Lookup  %s for more information.`.format(VERSION, BUILD, SPECVER, HTTP);

public const USAGE_SHORT =
`%s

Usage
    1. <OPTION> <arguments>
    2. <file>.mmal
Example
    (1) %s -e \"4 2 + = #\"
    (2) %s foo.mmal
    (2) %s foo
`.format(VERSION, CLI, CLI, CLI);
public const USAGE = `
>--------+-------------+-------------------------------------<
> Option | Arguments   | Description  ...                    <
>--------+-------------+-------------------------------------<
| -v     | ........... | Shows version.                      |
| -h     | [topic]     | This screen or help for 'topic'     |
| -e     | <seq> ./#   | Evaluate given sequence.            |
| -i     | ........... | Run in interactive mode (REPL)      |
| -d     | [v+]        | Debug a script; (v = verbose level) |
| -r     | <file>.mmal | Runs a script                       |
| show%  | ........... | Shows used specver                  |
| set%   | [<specver>] | Sets specver for current directory  |
<--------+-------------+------------------------------------->
For information about a specific option type [help <topic>]. `;


Context ctx;

int main(string[] args)
{
    debug writeln("[DEBUG]");
    handleInput(args);
    return errorcode;
}

void handleInput(ref string[] args)  {
    if (args.length == 0) {
        writeln("\nArgument required or file name.");
        writeln(USAGE_SHORT);
        setError("No argument given.", ErrorCode.Err);
    }
    else {
        handleOpt(args);
    }

    handleError(args);
}

void handleError(ref string[] args) {
    debug writeOnError();
    else  raiseOnError();
}

void handleOpt(ref string[] args) {

    try {
        auto help = getopt(
            args,
            config.passThrough,

            "v",       &handleVersion,
            "e",       &handleEvaluate,
            "d",       &handleDebug,
            "i",       &runREPL,
            "r",       &runScript,

            "version", &handleVersion,
            "eval",    &handleEvaluate,
            "debug",   &handleDebug,

            "repl",    &runREPL,
            "run",     &runScript,

            // TODO "set%",    &setSpecver,
            "show%",   &showSpecver,

            "help",    &handleHelp,
        );

        if(help.helpWanted) {
            debug writeln("[helpWanted]");
            handleHelp();
        }

        if (args.length >= 0) setArguments(cast() args[1..$]);
    }
    catch(Exception e) {
        setError(cast(string) e.message, ErrorCode.InvalidInput);
        return;
    }

    debug writeln(arguments);

    if(arguments.length == 0) {
        debug writefln("No argument remains.");
    }
    else {
        handleUnknownArgs(arguments);
    }

    if (errorcode > 0) return;
}

void handleUnknownArgs(in string[] arguments_to_be_checked) {
    foreach (arg; arguments_to_be_checked) {
        writefln("\nOption [%s] is unknown.", arg);
    }
    setError("Got unknown option.", ErrorCode.UnknownArgument);
}

void handleHelp() {
    debug writeln("[handleHelp()]");
    writeln(USAGE_SHORT);
}

void handleHelp(string topic) {
    topic = topic.strip();

    debug writefln("Topic %s", topic);
    switch (topic) {
        case "e", "eval":
            writeln("Evaluates a sequence. Must end with [.] or [#].");
            break;
        case "i", "repl":
            writeln("Runs interactive mode a.k.a REPL.");
            break;
        case "d", "debug":
            writeln("<file>[.mmal]  Debugs a script.");
            break;
        case "r", "run":
            writeln("<file>[.mmal]  Runs a script.");
            break;
        // TODO
        // case "set%", "setspecver":
        //     writeln(
        //         "Sets the _specver_"
        // /       ~"\nWhich should be used in current directory.");
        //     break;
        case "show%", "%":
            writeln(
                "Shows current _specver_"
                ~"\nWich is used in current directory.");
            break;
        default:
            writeHelpTopics("h", "usage");
    }
}

void writeHelpTopics(string opt, string topic) {
    opt   = opt.strip();
    topic = topic.strip();

    switch (topic) {
        case "", " ", "usage":
            writeln(USAGE);
            break;
        case "e", "evaluate":
            writeEvaluateHelp();
            break;
        case "repl":
            goto case;
        case "i", "interactive":
            writeREPLHelp();
            break;
        case "d", "debug":
            writeDebugHelp();
            break;
        case "r", "run":
            writeRunScriptHelp();
            break;
        default:
            writefln("\nTopic [%s] is unknown.", topic);
    }
}

void handleVersion() {
    writefln("%s\n%s", NAME, VERSION);
}

void handleEvaluate(string optname, string optvalue) {
    import core.exception : ArrayIndexError;

    optname  = optname.strip();
    optvalue = optvalue.strip();
    debug writefln("Option %s - %s\n", optname, optvalue[$-1]);

    if (optvalue[$-1] != '#' && optvalue[$-1] != '.') {
        writeln("Sequence must end with either `#` or `.`.");
        return;
    }

    Tokenizer tzr = new Tokenizer(cast(RawSeq) optvalue.split(" "), ctx);
    runTokenization(tzr);

    debug writeln("~ DONE");
}

void runTokenization (ref Tokenizer tzr) {
    bool cont = tzr.next(ctx);
    while (cont) cont = tzr.identify(ctx) && tzr.next(ctx);
}

void handleDebug(string optname, string optvalue) {
    debug writefln("Name   %s", optname);
    debug writefln("Value  %s", optvalue);

    writeln("NOT YET IMPLEMENTED.");
}


void runREPL() {
    writeln("NOT YET IMPLEMENTED.");
}

void runScript(string value) {
    debug writeln(value);
    writeln("NOT YET IMPLEMENTED.");
}


void setSpecver(string optvalue) {
    debug writeln(optvalue);
    writeln("NOT YET IMPLEMENTED.");
}

void showSpecver() nothrow {
    try {
        writefln("specver %s", SPECVER);
    }
    catch (Exception e) {
        setError(cast(string) e.message, ErrorCode.Err);
    }
}


void writeEvaluateHelp() {
    writeln("Usage  -e / eval \"<expression>\" #");
}

void writeREPLHelp() {
    writeln("Usage  -i / repl");
}

void writeDebugHelp() {
    writeln("Usage  -d / debug");
}

void writeRunScriptHelp() {
    writeln("Usage  -r / run  <file>[.mmal]");
}
