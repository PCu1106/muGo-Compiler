# muGo-Compiler

Implement lexical analyzer (scanner) by Lex and syntax analyzer (parser) by Yacc.

Also, ensured semantic correctness by implementing a symbol table.

Generated Jasmin assembly instructions and tested the compiler on the Java Virtual Machine.


## Environment

Ubuntu18.04

## How to test

- Install dependencies: `sudo apt install flex bison git python3 python3-pip default-jre`
- Download repository `git clone https://github.com/PCu1106/muGo-Compiler.git`
- Enter repository directory: `cd muGo-Compiler/`
- Build your compiler by `make` command and you will get an executable named
`mycompiler`.
- Run your compiler using the command `$ ./mycompiler < input.go` , which is built by
lex and yacc, with the given μGO code ( `.go` file) to generate the corresponding Java
assembly code ( `.j` file).
- The Java assembly code can be converted into the Java Bytecode ( .class file) through the
Java assembler, Jasmin, i.e., use `$ java -jar jasmin.jar hw3.j` to generate
`Main.class` .
- Run the Java program ( `.class` file) with Java Virtual Machine (JVM); the program should
generate the execution results required by this assignment, i.e., use `$ java Main` to run
the executable.


