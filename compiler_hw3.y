/* Please feel free to modify any content */

/* Definition section */
%{
    #include "compiler_hw_common.h" //Extern variables that communicate with lex
    #define YYDEBUG 1
    int yydebug = 1;

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

    int yylex_destroy ();
    void yyerror (char const *s)
    {
        printf("error:%d: %s\n", yylineno, s);
    }

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

    /* Used to generate code */
    /* As printf; the usage: CODEGEN("%d - %s\n", 100, "Hello world"); */
    /* We do not enforce the use of this macro */
    #define CODEGEN(...) \
        do { \
            for (int i = 0; i < g_indent_cnt; i++) { \
                fprintf(fout, "\t"); \
            } \
            fprintf(fout, __VA_ARGS__); \
        } while (0)

    /* Symbol table function - you can add new functions if needed. */
    /* parameters and return type can be changed */
	static void create_symbol();
    static void insert_symbol(char *id, int type);
    static int lookup_symbol(char *id, int level);
	static int lookup_type(char *id, int level);
	static char *lookup_func_sig(char *id, int level);
    static void dump_symbol(int level);
	static void print_type(int type);
	static char *type2simple(int type);
	static char *type2simpleSmall(int type);
	static void error_type_mismatched(int a, char *b, int c);
	static void error_type_notdefined(char *b, int a);

    /* Global variables */
    bool g_has_error = false;
    FILE *fout = NULL;
    int g_indent_cnt = 0;
    
    int level = 0;
	int address = 0;
	int level_size[50] = {0};
	char func_signature[50] = {0};
	int func_type = 0;
    int label = 0;
    int forlabel = 0;
    int switchlabel = 0;
	int caselabel = 0;
	int caserec[10] = {0};
	int iflabel = 0;
	int ifexitlabel = 0;
    
	struct symbol_table{
		int index;
		char *name;
		int type; // 0:ERROR 1:int32, 2:float32, 3:string, 4:bool, 5:function
		int address;
		int lineno;
		char Func_sig[50];
	}data[50][100];
%}

%error-verbose

/* Use variable or self-defined structure to represent
 * nonterminal and token type
 *  - you can add new fields if needed.
 */
%union {
    int i_val;
    float f_val;
    char *s_val;
}

/* Token without return */
%token VAR NEWLINE
%token INT FLOAT BOOL STRING
%token INC DEC '>' '<' GEQ LEQ EQL NEQ LAND LOR '!'
%token '=' ADD_ASSIGN SUB_ASSIGN MUL_ASSIGN QUO_ASSIGN REM_ASSIGN
%token IF ELSE FOR SWITCH CASE DEFAULT
%token PRINT PRINTLN
%token ';' ',' ':' '"' '(' ')' '[' ']' '{' '}'
%token TRUE FALSE
%token '+' '-' '*' '/' '%'
%token PACKAGE FUNC RETURN

/* Token with return, which need to sepcify type */
%token <i_val> INT_LIT
%token <f_val> FLOAT_LIT
%token <s_val> STRING_LIT
%token <s_val> IDENT

/* Nonterminal with return, which need to sepcify type */
%type <i_val> Type
%type <i_val> Expression UnaryExpr PrimaryExpr Operand Literal ConversionExpr AssignmentStmt
%type <s_val> cmp_op add_op mul_op unary_op assign_op
%type <i_val> LORExpr LANDExpr CmpExpr AddExpr
%type <s_val> FuncOpen IDENT_Name

/* Yacc will start at this nonterminal */
%start Program

/* Grammar section */
%%

Program
    : GlobalStatementList
	{
		dump_symbol(level); 
		level--;
	}
;

GlobalStatementList
    : GlobalStatementList GlobalStatement
    | GlobalStatement
;

GlobalStatement
    : PackageStmt NEWLINE { yylineno++; }
    | FunctionDeclStmt
    | NEWLINE { yylineno++; }
;

PackageStmt
    : PACKAGE { create_symbol(); }  IDENT
	{
		printf("package: %s\n", $3);
	}
;

FunctionDeclStmt
    : FuncOpen '(' ParameterList ')' Type { 
		strcat(func_signature,")");
		strcat(func_signature, type2simple($5));
		func_type = $5;
		printf("func_signature: %s\n", func_signature);
		insert_symbol($1, 5);
		level++;
        CODEGEN(".method public static %s%s\n", $1, func_signature);
        CODEGEN(".limit stack 100\n");
        CODEGEN(".limit locals 100\n");
		} FuncBlock { 
        CODEGEN("\t%sreturn\n", type2simpleSmall($5));
        CODEGEN(".end method\n"); 
		address = 0;
        }
    | FuncOpen '(' ')' { 
		strcat(func_signature,"()V");
		func_type = 0;
		printf("func_signature: %s\n", func_signature);
		insert_symbol($1, 5);
		level++;
		if(!strcmp($1, "main"))
		{
        	CODEGEN(".method public static %s([Ljava/lang/String;)V\n", $1);
		}
		else
		{
			CODEGEN(".method public static %s()V\n", $1);
		}
        CODEGEN(".limit stack 100\n");
        CODEGEN(".limit locals 100\n");
		} FuncBlock { 
        CODEGEN("\treturn\n");
        CODEGEN(".end method\n"); 
		address = 0;
        }
;

FuncOpen
	: FUNC IDENT
	{
		memset(func_signature, 0, 50);
		printf("func: %s\n", $2);
		level++;
		create_symbol();
		level--;
		$$ = $2;
	}
;

ParameterList
	: IDENT Type
	{
		strcat(func_signature, "(");
		printf("param %s, type: %s\n", $1, type2simple($2));
		strcat(func_signature, type2simple($2));
		level++;
		insert_symbol($1,$2);
		level--;
	}
	| ParameterList ',' IDENT Type
	{
		printf("param %s, type: %s\n", $3, type2simple($4));
		strcat(func_signature, type2simple($4));
		level++;
		insert_symbol($3,$4);
		level--;
	}
;

FuncBlock
	: '{' StatementList '}'
	{ 
		dump_symbol(level); 
		level--;
	}
;

ReturnStmt
	: RETURN
	{
		printf("return\n");
	}
	| RETURN Expression
	{
		printf("%sreturn\n",type2simpleSmall(func_type));
	}
;

StatementList
    : StatementList Statement
    | Statement
;

UnaryExpr
	: PrimaryExpr
	{
		$$ = $1;
	}
	| unary_op UnaryExpr
	{
		printf("%s\n", $1);
		$$ = $2;
        if(!strcmp($1, "NEG"))
		{
			switch($2 % 4)
			{
				case 1:
					CODEGEN("\tineg\n");
					break;
				case 2:
                    CODEGEN("\tfneg\n");
                    break;
			}
		}
		else if(!strcmp($1, "NOT"))
		{
			CODEGEN("\tixor\n");
		}
	}
;

Expression 
	: LORExpr LOR LORExpr 
	{
		if($1 % 4 != 0)
        {   
            error_type_notdefined("LOR", $1);
        }
        else if($3 % 4 != 0)
        {   
            error_type_notdefined("LOR", $3);
        }
		printf("LOR\n"); 
		$$ = 4;
        CODEGEN("\tior\n");
	}
	| LORExpr 
	{ 
		$$ = $1;
	}
;

LORExpr
	: LORExpr LAND LANDExpr 
	{
		if($1 % 4 != 0)
		{
			error_type_notdefined("LAND", $1);
		}
		else if($3 % 4 != 0)
		{
            error_type_notdefined("LAND", $3);
        }
		printf("LAND\n"); 
		$$ = 4;
        CODEGEN("\tiand\n");
	}
	| LANDExpr 
	{ 
		$$ = $1;
	}
;

LANDExpr
	: LANDExpr cmp_op CmpExpr 
	{ 
		if($1 == 0 || $3 == 0)//type = ERROR
        {
			error_type_mismatched($1, $2, $3);
		}
        else if($1 % 4 != $3 % 4)
        {
            error_type_mismatched($1, $2, $3);
        }
		printf("%s\n", $2); 
		$$ = 4; 
        if(!strcmp($2, "EQL"))
		{
			switch($1 % 4)
			{
				case 1:
					CODEGEN("\tisub\n");
					CODEGEN("\tifeq L_cmp_%d\n", label);
					break;
				case 2:
					CODEGEN("\tfcmpl\n");
					CODEGEN("\tifeq L_cmp_%d\n", label);
					break;
			}
		}
		else if(!strcmp($2, "GTR"))
		{
            switch($1 % 4)
            {
                case 1:
                    CODEGEN("\tisub\n");
					CODEGEN("\tifgt L_cmp_%d\n", label);
                    break;
                case 2:
                    CODEGEN("\tfcmpl\n");
					CODEGEN("\tifgt L_cmp_%d\n", label);
                    break;
            }
		}
		else if(!strcmp($2, "LSS"))
        {
            switch($1 % 4)
            {
                case 1:
                    CODEGEN("\tisub\n");
					CODEGEN("\tiflt L_cmp_%d\n", label);
                    break;
                case 2:
                    CODEGEN("\tfcmpl\n");
					CODEGEN("\tiflt L_cmp_%d\n", label);
                    break;
            }
        }
		else if(!strcmp($2, "GEQ"))
        {
            switch($1 % 4)
            {
                case 1:
                    CODEGEN("\tisub\n");
					CODEGEN("\tifge L_cmp_%d\n", label);
                    break;
                case 2:
                    CODEGEN("\tfcmpl\n");
					CODEGEN("\tifge L_cmp_%d\n", label);
                    break;
            }
        }
		else if(!strcmp($2, "LEQ"))
        {
            switch($1 % 4)
            {
                case 1:
                    CODEGEN("\tisub\n");
					CODEGEN("\tifle L_cmp_%d\n", label);
                    break;
                case 2:
                    CODEGEN("\tfcmpl\n");
					CODEGEN("\tifle L_cmp_%d\n", label);
                    break;
            }
        }
		else if(!strcmp($2, "NEQ"))
        {
            switch($1 % 4)
            {
                case 1:
                    CODEGEN("\tisub\n");
					CODEGEN("\tifne L_cmp_%d\n", label);
                    break;
                case 2:
                    CODEGEN("\tfcmpl\n");
					CODEGEN("\tifne L_cmp_%d\n", label);
                    break;
            }
        }
		CODEGEN("\ticonst_0\n");
		CODEGEN("\tgoto L_cmp_%d\n", label + 1);
		CODEGEN("L_cmp_%d:\n", label);
		CODEGEN("\ticonst_1\n");
		CODEGEN("L_cmp_%d:\n", label + 1);
        label = label + 2;
	}
	| CmpExpr 
	{ 
		$$ = $1;
	}
;

CmpExpr
	: CmpExpr add_op AddExpr 
	{
		if($1 == 0 || $3 == 0)
		{
			error_type_mismatched($1, $2, $3);
		}
		else if($1 % 4 != $3 % 4)
        {
            error_type_mismatched($1, $2, $3);
        }
		printf("%s\n", $2); 
		$$ = $1; 
		if(!strcmp($2, "ADD"))
		{
			switch($1 % 4)
			{
				case 1:
					CODEGEN("\tiadd\n");
					break;
				case 2:
					CODEGEN("\tfadd\n");
					break;
			}
		}
		else if(!strcmp($2, "SUB")) 
		{
            switch($1 % 4)
			{
				case 1:
					CODEGEN("\tisub\n");
					break;
				case 2:
					CODEGEN("\tfsub\n");
					break;
			}
        }
	}
	| AddExpr 
	{ 
		$$ = $1;
	}
;

AddExpr
	: AddExpr mul_op UnaryExpr 
	{
		if(!strcmp($2, "REM") && ($1 % 4 == 2 || $3 % 4 == 2))
		{
			error_type_notdefined($2, 2);
		}
		else if($1 == 0 || $3 == 0)
        {
			error_type_mismatched($1, $2, $3);
		}
		else if($1 % 4 != $3 % 4)
		{
			error_type_mismatched($1, $2, $3);
		}
		printf("%s\n", $2); 
		$$ = $1; 
        if(!strcmp($2, "MUL")) 
		{
            switch($1 % 4)
			{
				case 1:
					CODEGEN("\timul\n");
					break;
				case 2:
					CODEGEN("\tfmul\n");
					break;
			}
        }
        else if(!strcmp($2, "QUO")) 
		{
            switch($1 % 4)
			{
				case 1:
					CODEGEN("\tidiv\n");
					break;
				case 2:
					CODEGEN("\tfdiv\n");
					break;
			}
        }
		else if(!strcmp($2, "REM")) 
		{
            CODEGEN("\tirem\n");
        }
	}
	| UnaryExpr 
	{ 
		$$ = $1;
	}
;

cmp_op
	: EQL { $$ = "EQL"; }
	| NEQ { $$ = "NEQ"; }
	| '<' { $$ = "LSS"; }
	| LEQ { $$ = "LEQ"; }
	| '>' { $$ = "GTR"; }
	| GEQ { $$ = "GEQ"; }
;

add_op
	: '+' { $$ = "ADD"; }
	| '-' { $$ = "SUB"; }
;

mul_op
	: '*' { $$ = "MUL"; }
	| '/' { $$ = "QUO"; }
	| '%' { $$ = "REM"; }
;

unary_op
	: '+' { $$ = "POS"; }
	| '-' { $$ = "NEG"; }
	| '!' { $$ = "NOT"; CODEGEN("\ticonst_1\n"); }
;

PrimaryExpr
	: Operand 
	{ 
		$$ = $1; 
	}
	| ConversionExpr 
	{ 
		$$ = $1; 
	}
;

Operand
	: Literal 
	{ 
		$$ = $1; 
	}
	| IDENT
	{
		int addr = lookup_symbol($1, level);
		if(addr != -1)
		{
			printf("IDENT (name=%s, address=%d)\n", $1, addr);
			$$ = lookup_type($1, level);
			switch($$)
			{
				case 1:
					CODEGEN("\tiload %d\n", addr);
					break;
				case 2:
					CODEGEN("\tfload %d\n", addr);
					break;
				case 3:
					CODEGEN("\taload %d\n", addr);
					break;
				case 4:
					CODEGEN("\tiload %d\n", addr);
					break;
			}
		}
		else
		{
			printf("error:%d: ", yylineno);
			printf("undefined: %s\n", $1);
			g_has_error = true;
			$$ = 0;//type=0 means ERROR
		}
	}
	| '(' Expression ')'
	{
		$$ = $2;
	}
	| TRUE 
	{ 
		printf("TRUE 1\n"); 
		$$ = 4; 
        CODEGEN("\ticonst_1\n");
	}
    | FALSE 
	{ 
		printf("FALSE 0\n"); 
		$$ = 4; 
        CODEGEN("\ticonst_0\n");
	}
	|FuncStmt
;

Literal
	: INT_LIT
	{
		printf("INT_LIT %d\n", $1);
        CODEGEN("\tldc %d\n",$1);
		$$ = 9;
	}
	| FLOAT_LIT
	{
        printf("FLOAT_LIT %f\n", $1);
        CODEGEN("\tldc %f\n",$1);
		$$ = 10;
    }
	| '"' STRING_LIT '"' 
    {
		printf("STRING_LIT %s\n", $2);
        CODEGEN("\tldc \"%s\"\n",$2);
		$$ = 3;
    }
;

ConversionExpr
	: Type '(' Expression ')'
	{
		$$ = $1;
        switch($3 % 4)
        {
            case 1:
                printf("i");
				CODEGEN("\ti");
                break;
            case 2:
                printf("f");
				CODEGEN("\tf");
                break;
            case 3:
                printf("s");
				CODEGEN("\ts");
                break;
            case 4:
                printf("b");
				CODEGEN("\tb");
                break;
        }
        printf("2");
		CODEGEN("2");
		switch($1 % 4)
        {
            case 1:
                printf("i\n");
		        CODEGEN("i\n");
                break;
            case 2:
                printf("f\n");
		        CODEGEN("f\n");
                break;
            case 3:
                printf("s\n");
		        CODEGEN("s\n");
                break;
            case 4:
                printf("b\n");
		        CODEGEN("b\n");
                break;
        }
    }
;

Statement 
	: DeclarationStmt NEWLINE { yylineno++; }
	| SimpleStmt NEWLINE { yylineno++; }
	| Block NEWLINE { yylineno++; }
	| IfStmt NEWLINE { yylineno++; CODEGEN("L_if_exit_%d:\n", ifexitlabel); ifexitlabel++; }
	| ForStmt NEWLINE { yylineno++; }
	| SwitchStmt NEWLINE { yylineno++; }
	| CaseStmt NEWLINE { yylineno++; }
	| PrintStmt NEWLINE { yylineno++; }
	| ReturnStmt NEWLINE { yylineno++; }
	| FuncStmt NEWLINE { yylineno++; }
	| NEWLINE { yylineno++; }
;

FuncStmt
	: IDENT '(' ')'
	{
		printf("call: %s%s\n", $1, lookup_func_sig($1, level));
		CODEGEN("\tinvokestatic Main/%s()V\n", $1);
	}
	| IDENT '(' ArgumentList ')'
	{
		printf("call: %s%s\n", $1, lookup_func_sig($1, level));
		CODEGEN("\tinvokestatic Main/%s%s\n", $1, lookup_func_sig($1, level));
	}
;

ArgumentList
	: Operand
	| ArgumentList ',' Operand
;

SimpleStmt
	: AssignmentStmt
	| Expression
	| IncDecStmt
;

DeclarationStmt
	: VAR IDENT Type
	{
		insert_symbol($2, $3);
		int addr = lookup_symbol($2, level);
        switch($3)
		{
			case 1:
				CODEGEN("\tldc 0\n");
				CODEGEN("\tistore %d\n", addr);
				break;
			case 2:
				CODEGEN("\tldc 0\n");
                CODEGEN("\tfstore %d\n", addr);
                break;
			case 3:
				CODEGEN("\tldc \"\"\n");
                CODEGEN("\tastore %d\n", addr);
                break;
			case 4:
                break;
		}
	}
	| VAR IDENT Type '=' Expression
	{
		insert_symbol($2, $3);
        int addr = lookup_symbol($2, level);
        switch($3)
		{
			case 1:
				CODEGEN("\tistore %d\n", addr);
				break;
			case 2:
                CODEGEN("\tfstore %d\n", addr);
                break;
			case 3:
                CODEGEN("\tastore %d\n", addr);
                break;
			case 4:
                CODEGEN("\tistore %d\n", addr);
                break;
		}
	}
;

AssignmentStmt
	: IDENT assign_op Expression
	{
        int type=lookup_type($1, level);
        int addr=lookup_symbol($1, level);
        if(!strcmp($2, "ASSIGN"))
        {
            switch(type)
            {
                case 1:
                    CODEGEN("\tistore %d\n", addr);
                    break;
                case 2:
                    CODEGEN("\tfstore %d\n", addr);
                    break;
                case 3:
                    CODEGEN("\tastore %d\n", addr);
                    break;
                case 4:
                    CODEGEN("\tistore %d\n", addr);
                    break;
            }
        }
        else if(!strcmp($2, "ADD"))
        {
            switch(type)
            {
                case 1:
                    CODEGEN("\tiload %d\n", addr);
                    CODEGEN("\tiadd\n");
                    CODEGEN("\tistore %d\n", addr);
                    break;
                case 2:
                    CODEGEN("\tfload %d\n", addr);
                    CODEGEN("\tfadd\n");
                    CODEGEN("\tfstore %d\n", addr);
                    break;
            }
        }
        else if(!strcmp($2, "SUB"))
        {
            switch(type)
            {
                case 1:
                    CODEGEN("\tiload %d\n", addr);
                    CODEGEN("\tswap\n\tisub\n");
                    CODEGEN("\tistore %d\n", addr);
                    break;
                case 2:
                    CODEGEN("\tfload %d\n", addr);
                    CODEGEN("\tswap\n\tfsub\n");
                    CODEGEN("\tfstore %d\n", addr);
                    break;
            }
        }
        else if(!strcmp($2, "MUL"))
        {
            switch(type)
            {
                case 1:
                    CODEGEN("\tiload %d\n", addr);
                    CODEGEN("\timul\n");
                    CODEGEN("\tistore %d\n", addr);
                    break;
                case 2:
                    CODEGEN("\tfload %d\n", addr);
                    CODEGEN("\tfmul\n");
                    CODEGEN("\tfstore %d\n", addr);
                    break;
            }
        }
        else if(!strcmp($2, "QUO"))
        {
            switch(type)
            {
                case 1:
                    CODEGEN("\tiload %d\n", addr);
                    CODEGEN("\tswap\n\tidiv\n");
                    CODEGEN("\tistore %d\n", addr);
                    break;
                case 2:
                    CODEGEN("\tfload %d\n", addr);
                    CODEGEN("\tswap\n\tfdiv\n");
                    CODEGEN("\tfstore %d\n", addr);
                    break;
            }
        }
        else if(!strcmp($2, "REM"))
        {
            switch(type)
            {
                case 1:
                    CODEGEN("\tiload %d\n", addr);
                    CODEGEN("\tswap\n\tirem\n");
                    CODEGEN("\tistore %d\n", addr);
                    break;
                case 2:
                    break;
            }
        }
		if(type == 0 || $3 == 0)
		{
			error_type_mismatched(type, $2, $3);
		}
		else if(type % 4 != $3 % 4)
        {
            error_type_mismatched(type, $2, $3);
        }
		printf("%s\n", $2);
		$$ = type;
	}
;

assign_op
	: '=' { $$ = "ASSIGN"; }
	| ADD_ASSIGN { $$ = "ADD"; }
	| SUB_ASSIGN { $$ = "SUB"; }
	| MUL_ASSIGN { $$ = "MUL"; }
	| QUO_ASSIGN { $$ = "QUO"; }
	| REM_ASSIGN { $$ = "REM"; }
;

IncDecStmt
	: IDENT_Name INC 
	{ 
		printf("INC\n"); 
        int type=lookup_type($1,level);
        switch(type)
		{
			case 1:
				CODEGEN("\tldc 1\n");
				CODEGEN("\tiadd\n");
				CODEGEN("\tistore %d\n", lookup_symbol($1, level));
				break;
			case 2:
				CODEGEN("\tldc 1.0\n");
				CODEGEN("\tfadd\n");
				CODEGEN("\tfstore %d\n", lookup_symbol($1, level));
				break;
		}
	}
	| IDENT_Name DEC 
	{
		printf("DEC\n"); 
        int type=lookup_type($1,level);
        switch(type)
		{
			case 1:
				CODEGEN("\tldc 1\n");
				CODEGEN("\tisub\n");
				CODEGEN("\tistore %d\n", lookup_symbol($1, level));
				break;
			case 2:
				CODEGEN("\tldc 1.0\n");
				CODEGEN("\tfsub\n");
				CODEGEN("\tfstore %d\n", lookup_symbol($1, level));
				break;
		}
	}
;

IDENT_Name
	: IDENT
    {
        int addr = lookup_symbol($1, level);
        if(addr != -1)
        {
            printf("IDENT (name=%s, address=%d)\n", $1, addr);
            $$ = $1;
			int type = lookup_type($1, level);
			switch(type)
			{
				case 1:
					CODEGEN("\tiload %d\n", addr);
					break;
				case 2:
					CODEGEN("\tfload %d\n", addr);
					break;
			}		
        }
        else
        {
            printf("error:%d: ", yylineno + 1);
            printf("undefined: %s\n", $1);
            $$ = 0;
			g_has_error = true;
        }
    }
;

Block
	: '{' { level++; create_symbol(); } StatementList '}' 
	{  
		dump_symbol(level);
		level--;
	}
;

IfStmt
	: IFcondition Block { 
		CODEGEN("\tgoto L_if_exit_%d\n", ifexitlabel); 
		CODEGEN("L_if_%d:\n", iflabel); iflabel++; }
	| IfStmt ELSE IFcondition Block { 
		CODEGEN("\tgoto L_if_exit_%d\n", ifexitlabel); 
		CODEGEN("L_if_%d:\n", iflabel); iflabel++; }
	| IfStmt ELSE Block
	| IfStmt NEWLINE
;

IFcondition
	: IF Condition
	{
		CODEGEN("\tifeq L_if_%d\n", iflabel);
	}
;

Condition
	: Expression
	{
		if($1 % 4 != 0)
		{
		    printf("error:%d: non-bool (type ", yylineno);
			print_type($1);
			printf(") used as for condition\n");
			g_has_error = true;
		}
	}
;

ForStmt
	: FOR { CODEGEN("L_for_begin_%d:\n", forlabel); }
        Condition { CODEGEN("\tifeq L_for_exit_%d\n", forlabel); } Block {
            CODEGEN("\tgoto L_for_begin_%d\nL_for_exit_%d:\n", forlabel, forlabel);
            forlabel++; 
        }
	| FOR { CODEGEN("L_for_begin_%d:\n", forlabel); }
        ForClause Block {
            forlabel++; 
        }
;

ForClause
	: InitStmt ';' Condition ';' PostStmt
;

InitStmt
	: SimpleStmt
;

PostStmt
	: SimpleStmt
;

SwitchStmt
	: SWITCH Expression {
			caselabel = 0;
			CODEGEN("\tgoto L_switch_begin_%d\n", switchlabel);
		} Block { 
			CODEGEN("L_switch_begin_%d:\nlookupswitch\n", switchlabel);
			for(int i = 0; i < caselabel; i++)
			{
				if(caserec[i] != -1)
				{
					CODEGEN("\t%d: L_case_%d%d\n", caserec[i], switchlabel , i);
				}
				else
				{
					CODEGEN("\tdefault: L_case_%d%d\n", switchlabel , i);
				}
			}
			CODEGEN("L_switch_end_%d:\n", switchlabel);
			switchlabel++; }

CaseStmt
	: CASE INT_LIT {
			printf("case %d\n", $2);
			CODEGEN("L_case_%d%d:\n", switchlabel, caselabel);
			caserec[caselabel] = $2;
			caselabel++;
		} ':' Block { CODEGEN("\tgoto L_switch_end_%d\n", switchlabel); }
	| DEFAULT {
			CODEGEN("L_case_%d%d:\n", switchlabel, caselabel);
			caserec[caselabel]=-1;
			caselabel++;
		} ':' Block { CODEGEN("\tgoto L_switch_end_%d\n", switchlabel); }

PrintStmt
	: PRINT '(' Expression ')' 
	{
		printf("PRINT ");
		print_type($3);
        printf("\n");
        switch($3 % 4)
		{
			case 1:
				CODEGEN("\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n\tswap\n");
				CODEGEN("\tinvokevirtual java/io/PrintStream/print(I)V\n");
				break;
			case 2:
				CODEGEN("\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n\tswap\n");
				CODEGEN("\tinvokevirtual java/io/PrintStream/print(F)V\n");
				break;
			case 3:
				CODEGEN("\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n\tswap\n");
				CODEGEN("\tinvokevirtual java/io/PrintStream/print(Ljava/lang/String;)V\n");
				break;
			case 0:
				CODEGEN("\tifne L_cmp_%d\n\tldc \"false\"\n\tgoto L_cmp_%d\nL_cmp_%d:\n\tldc \"true\"\nL_cmp_%d:\n", label, label + 1, label, label + 1);
				CODEGEN("\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n\tswap\n");
                CODEGEN("\tinvokevirtual java/io/PrintStream/print(Ljava/lang/String;)V\n");
				break;
			label = label + 2;
		}
	}
	| PRINTLN '(' Expression ')'
	{ 
		printf("PRINTLN ");
		print_type($3);
		printf("\n");
        switch($3 % 4)
        {
            case 1:
                CODEGEN("\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n");
                CODEGEN("\tswap\n");
                CODEGEN("\tinvokevirtual java/io/PrintStream/println(I)V\n");
                break;
            case 2:
                CODEGEN("\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n");
                CODEGEN("\tswap\n");
                CODEGEN("\tinvokevirtual java/io/PrintStream/println(F)V\n");
                break;
            case 3:
                CODEGEN("\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n");
                CODEGEN("\tswap\n");
                CODEGEN("\tinvokevirtual java/io/PrintStream/println(Ljava/lang/String;)V\n");
                break;
            case 0:
                CODEGEN("\tifne L_cmp_%d\n\tldc \"false\"\n\tgoto L_cmp_%d\nL_cmp_%d:\n\tldc \"true\"\nL_cmp_%d:\n", label, label + 1, label, label + 1);
				CODEGEN("\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n\tswap\n");
                CODEGEN("\tinvokevirtual java/io/PrintStream/println(Ljava/lang/String;)V\n");
				label = label + 2;
                break;
        }
	}
;

Type
    : INT { $$ = 1; }
    | FLOAT { $$ = 2; }
    | STRING { $$ = 3; }
    | BOOL { $$ = 4; }
;

%%

/* C code section */
int main(int argc, char *argv[])
{
    if (argc == 2) {
        yyin = fopen(argv[1], "r");
    } else {
        yyin = stdin;
    }
    if (!yyin) {
        printf("file `%s` doesn't exists or cannot be opened\n", argv[1]);
        exit(1);
    }

    /* Codegen output init */
    char *bytecode_filename = "hw3.j";
    fout = fopen(bytecode_filename, "w");
    CODEGEN(".source hw3.j\n");
    CODEGEN(".class public Main\n");
    CODEGEN(".super java/lang/Object\n");


    /* Symbol table init */
    // Add your code

    yylineno = 1;
    yyparse();

    /* Symbol table dump */
    // Add your code

	printf("Total lines: %d\n", yylineno-1);

    fclose(fout);
    fclose(yyin);

    if (g_has_error) {
        remove(bytecode_filename);
    }
    yylex_destroy();
    return 0;
}

static void create_symbol() {
	printf("> Create symbol table (scope level %d)\n", level);
}

static void insert_symbol(char *id, int type) {
	int j = 0, define = 0, line = 0;
	for(j = 0; j < level_size[level]; j++) {
        if(!strcmp(data[level][j].name, id)) { //strcmp=0代表字串一樣
            define = 1;
			line = data[level][j].lineno;
        }
    }
	if(define)
	{
		printf("error:%d: ", yylineno);
		printf("%s redeclared in this block. previous declaration at line %d\n", id, line);
			g_has_error = true;
	}
	if(type == 5)
	{
		printf("> Insert `%s` (addr: -1) to scope level %d\n", id, level);
	}
	else
	{
		printf("> Insert `%s` (addr: %d) to scope level %d\n", id, address, level);
	}
	data[level][level_size[level]].index = level_size[level];
	data[level][level_size[level]].name = id;
	data[level][level_size[level]].type = type; // 1:int32, 2:float32, 3:string, 4:bool
	if(type == 5)
	{
		data[level][level_size[level]].address = -1;
	}
	else
	{
		data[level][level_size[level]].address = address;
		address++;
	}
	data[level][level_size[level]].lineno = yylineno;
	strcpy(data[level][level_size[level]].Func_sig, func_signature);
	level_size[level]++;
}	

static int lookup_symbol(char *id, int level) {
	int i = 0, j = 0;
	for(i = level; i >= 0; i--) {
		for(j = 0; j < level_size[i]; j++) {
			if(!strcmp(data[i][j].name, id)) {
				return data[i][j].address;
			}
		}
	}
	return -1;
}

static int lookup_type(char *id, int level) {
    int i = 0, j = 0;
    for(i = level; i >= 0; i--) {
        for(j = 0; j < level_size[i]; j++) {
            if(!strcmp(data[i][j].name, id)) {
                return data[i][j].type;
            }
        }
    }
	return 0;
}

static char *lookup_func_sig(char *id, int level) {
    int i = 0, j = 0;
    for(i = level; i >= 0; i--) {
        for(j = 0; j < level_size[i]; j++) {
            if(!strcmp(data[i][j].name, id)) {
                return data[i][j].Func_sig;
            }
        }
    }
	return "";
}


static void dump_symbol(int level) {
    printf("\n> Dump symbol table (scope level: %d)\n", level);
	printf("%-10s%-10s%-10s%-10s%-10s%-10s\n",
           "Index", "Name", "Type", "Addr", "Lineno", "Func_sig");
	char datatype[50], dataFunc_sig[50];
	for(int i = 0; i < level_size[level]; i++) {
		switch(data[level][i].type) {// 1:int32, 2:float32, 3:string, 4:bool, 5:func
			case 1:
				strcpy(datatype, "int32");
				strcpy(dataFunc_sig, "-");
				break;
			case 2:
				strcpy(datatype, "float32");
                strcpy(dataFunc_sig, "-");
                break;
			case 3:
				strcpy(datatype, "string");
                strcpy(dataFunc_sig, "-");
                break;
			case 4:
				strcpy(datatype, "bool");
                strcpy(dataFunc_sig, "-");
                break;
			case 5:
				strcpy(datatype, "func");
                strcpy(dataFunc_sig, data[level][i].Func_sig);
                break;
			break;
		}
	    printf("%-10d%-10s%-10s%-10d%-10d%-10s\n", i, data[level][i].name, datatype, data[level][i].address, data[level][i].lineno, dataFunc_sig);
	}
	level_size[level] = 0;
	printf("\n");
}

static void print_type(int type)
{
	switch(type % 4)
	{
		case 1:
			printf("int32");
			break;
		case 2:
			printf("float32");
			break;
		case 3:
			printf("string");
			break;
		case 0:
			printf("bool");
			break;
	}
}

static char *type2simple(int type)
{
	switch(type % 4)
	{
		case 1:
			return "I";
			break;
		case 2:
			return "F";
			break;
		case 3:
			return "S";
			break;
		case 0:
			return "B";
			break;
	}
}

static char *type2simpleSmall(int type)
{
	switch(type % 4)
	{
		case 1:
			return "i";
			break;
		case 2:
			return "f";
			break;
		case 3:
			return "s";
			break;
		case 0:
			return "b";
			break;
	}
}

void error_type_mismatched(int a, char *b, int c)
{
	g_has_error = true;
	printf("error:%d: ", yylineno);
    printf("invalid operation: %s (mismatched types ", b);
    if(a == 0)
	{
		printf("ERROR");
	}
	else
	{
		print_type(a);
	}
    printf(" and ");
	if(c == 0)
	{
		printf("ERROR");
	}
	else
	{
		print_type(c);
	}
    printf(")\n");
}

static void error_type_notdefined(char *b, int a)
{
	g_has_error = true;
	printf("error:%d: ", yylineno);
    printf("invalid operation: (operator %s not defined on ", b);
    print_type(a);
    printf(")\n");
}