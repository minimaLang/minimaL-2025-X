module minimal;
public import minimal.main;
public import minimal.token;

import std.string : format;
import std.stdio;


package (minimal) {
    import std.getopt : Option;

    public enum ErrorCode : uint {
        OK  = 0,
        Err = 1,

        UnknownArgument,
        MissingArgument,

        UnknownValue,
        MissingValue,

        OutOfBounds,

        InvalidInput,
    }

    public enum ErrorMessage : string {
        OK  = "",
        Err = "Error",

        UnknownArgument = "Unknown argument [%s].",
        MissingArgument = "Missing argument.",

        UnknownValue = "Unknown value [%s].",
        MissingValue = "Missing value.",
    }

    private {
        string[]  _arguments   = [];
        string    _errormesage = "";
        ErrorCode _errorcode   = ErrorCode.OK;
        Option[]  _options     = null;
    }

    @property string[]  arguments()    nothrow => _arguments;
    @property ErrorCode errorcode()    nothrow => _errorcode;
    @property string    errormessage() nothrow => _errormesage;
    @property bool      hasError()     nothrow => (_errorcode != ErrorCode.OK);
    @property Option[]  options()      nothrow => _options;

    public void setOptions(ref Option[] options) {
        _options = options;
    }

    public void setArguments(string[] args) nothrow {
        _arguments = args;
    }

    public void setError(string message, ErrorCode code) nothrow {
        _errormesage = message;
        _errorcode   = code;
    }

    public void raiseOnError() {
        if (errorcode > 0) {
            string m = "[Code %d] %s".format(_errorcode, _errormesage);
            throw new Exception(m);
        }
    }

    public void writeOnError() {
        if (errorcode > 0) {
            string m = "[Code %d] %s".format(_errorcode, _errormesage);
            writeln(m);
        }
    }
}
