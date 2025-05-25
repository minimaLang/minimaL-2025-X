module minimal.repl;

import std.stdio;
import minimal.repl.app;


int main (string[] args) {
    write(27 ~ "[?25l");

    writeIntroduction();

    return app_main(args);
}

void writeIntroduction() {
}
