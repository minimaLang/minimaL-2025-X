module minimal.main;


import std.string : split, format, endsWith, replace;
import std.stdio : writeln, writefln;

import minimal;

public const VERSION = "0.2025.0";
public const BUILD   = "alpha0";

public const HTTP = "https://github.com/minimaLang/";
public const NAME = "Hello minimaL";
public const CLI  = "hello";

public const DESC = `
...
minimaL  %s-%s

minimaL is an RPN (Reverse Polish Notation) interpreter.
Lookup  %s for more information.`.format(VERSION, BUILD, HTTP);

public const USAGE_SHORT =
"Usage
    1. %s <OPTION> <arguments>
    2. %s <file>.mmal
Example
    (1) %s -e \"4 2 + = #\"
    (2) %s foo.mmal
    (2) %s foo"
.format(CLI, CLI, CLI, CLI, CLI);
public const USAGE = `
%s
>--------+-------------+-------------------------------------<
> Option | Arguments   | Description  ...                    <
>--------+-------------+-------------------------------------<
| -v     |             | Shows version.                      |
+--------+-------------+-------------------------------------+
| -h     | [topic]     | This screen or help for 'topic'     |
+--------+-------------+-------------------------------------+
| -e     | <seq> ./#   | Evaluate given sequence.            |
+--------+-------------+-------------------------------------+
| -i     |             | Run in interactive mode (REPL)      |
+--------+-------------+-------------------------------------+
| -d     | [v+]        | Debug a script; (v = verbose level) |
+--------+-------------+-------------------------------------+
| -r     | <file>.mmal | Runs a script                       |
+--------+-------------+-------------------------------------+
%s`.format(USAGE_SHORT, DESC);


int main(string[] args)
{
    debug writeln("[DEBUG]");
    handleInput(args);
    if (errorcode > 0) writefln("\nERROR  [%d] %s", errorcode, errormsg);
    return errorcode;
}

void handleInput(string[] args)  {
    if (args.length < 2) {
        writeln("\nArgument required or file name.");
        writeln(USAGE_SHORT);
        errormsg = "No argument given.";
        errorcode = 1;
    }
    else {
        handleOpt(args);
    }
}

void handleOpt(string[] args) {
    import std.getopt : getopt, config;

    arguments = args[1..$];
    debug writefln("Number of arguments  %d", arguments.length);

    auto help = getopt(
        args,
        config.passThrough,
        "help",    &handleHelp,

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
    );

    if(help.helpWanted) {
        debug writeln("[helpWanted]");
        handleHelp(arguments[0]);
    }
    else if (arguments.length == 1) {
        if (arguments[0] == "help") {
            handleHelp("usage");
        }
        else {
            debug writeln("[UnsuportedArgs]");
            handleUnsupportedArgs();
        }
    }

    if (errorcode > 0) return;
}

void handleUnsupportedArgs() {
    foreach (arg; arguments) writefln("\nOption [%s] is unsupported.", arg);
    errormsg  = "Got unsupported option.";
    errorcode = 2;
}

void handleHelp(string topic) {
    switch (topic) {
        case "e", "eval": writeln(
            "               Evaluates a sequence. Must end with [.] or [#].");
            break;
        case "i", "repl": writeln(
            "               Runs interactive mode a.k.a REPL.");
            break;
        case "d", "debug": writeln(
            "<file>[.mmal]  Debugs a script.");
            break;
        case "r", "run": writeln(
            "<file>[.mmal]  Runs a script.");
            break;
        default:
            writeHelpTopics("usage");
    }
}

void writeHelpTopics(string topic) {
    writeln("Help  ...");

    switch (topic) {
        case "", " ", "h", "help":
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
        case "usage":
            writeln(USAGE);
            break;
        default:
            writefln("\nTopic [%s] is unknown.", topic);
    }
}

void handleVersion(string args) {
    if (args.length == 0) {
        writefln("%s\n%s", NAME, VERSION);
    }
}

void handleEvaluate(string optname, string optvalue) {
    writeln("-- EVALUATION --");
    writeln("Thanks for your input.");

    debug writefln(
          "\nName   %s"
        ~ "\nValue  %s",
        optname, optvalue);

    Tokenizer nizer = new Tokenizer(optvalue.split(" "));
    if (!(endsWith(optvalue, '.') || endsWith(optvalue, "#"))) {
        writeln("\nERROR  Sequence must end with [.] or [#].\n");
        errorcode = 1;

        debug writeln(optvalue[$-1]);
        return;
    }

    debug {
        writeln();
        writeln("Length:   ", nizer.length);
        writeln("Sequence: ", nizer.rawseq);
        writeln();
    }

    string t = "\0";
    while (nizer.next()) {

        if (t == " " || t == "\0") continue;
        debug writeln("Position: ", nizer.position);
        t = nizer.current;
        writeln(t);
    }

    writeln("--    DONE    --");
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


void writeEvaluateHelp() {
    writeln("Usage  -e / eval  <expression> #");
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
