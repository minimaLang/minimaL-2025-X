module minimal.interpreter.view;

import std.outbuffer;

class Buffer {
    protected OutBuffer buffer;

    void   write(string input) { this.buffer.write(input); }
    string read()              => this.buffer.toString();

    void writef(alias fmt, A...)(A args) {
        this.buffer.writef(fmt, args);
    }

    void writefln(alias fmt, A...)(A args) {
        this.buffer.writefln(fmt, args);
    }

    void newline() {
        this.buffer.writefln("%s", "\n");
    }
}

class Frame {
    protected Buffer _buffer_;

    this() {
        this._buffer_ = new Buffer();
    }

    ref Buffer buffer() => this._buffer_;
}

public import std.container.array : Array;

alias Frames = Array!Frame;
void create(ref Frames frames, ulong amount = 1) {
    foreach (ulong i; 0..(amount-1)) frames.insertBack(new Frame());
}

class View {
    protected shared Frames frames;

    this(shared Frames frames) { this.frames = frames;   }
    this()                     { this.frames = Frames(); }

    abstract void draw();
    abstract void input(Input input);
}



struct Input {
    string   name;
    Position  emittedAt = { x: 0, y: 0 };
    Dimension area      = { width: 0, height: 0 };
}

struct Dimension {
    ulong width;
    ulong height;
}

struct Position {
    ulong x;
    ulong y;
}

struct Surface {
    Position  position;
    Dimension dimension;
    void delegate (View) draw;

}

alias Views = View[Surface];
