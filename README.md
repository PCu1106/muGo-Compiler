# muGo-Compiler

Implement lexical analyzer (scanner) by Lex and syntax analyzer (parser) by Yacc.

Also, check semantic correctness by implementing symbol table.

Output the jasmin assembly instructions, and test by Java Virtual Machine (JVM)

## Environment

Ubuntu18.04

## How to test

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


