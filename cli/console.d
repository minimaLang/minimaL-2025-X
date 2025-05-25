module cli.console;

import std.stdio;
import std.mmfile : MmFile;

struct Point {
    ulong x;
    ulong y;
}

struct Dimension {
    ulong width;
    ulong heigth;
}

struct Surface {
    Dimension dimension = {30, 40};
    Point     position  = { 0,  0};
}

struct Screen {
    MmFile    file;
    Surface[] surface;
    Dimension dimension = {90, 120};
    Point     position  = { 0,   0};
}

class Console {
    private Dimension dim;
    private Screen    active;
    private Screen    buffer;

    void clearscreen() { write(27 ~ "[2J"); }
}
