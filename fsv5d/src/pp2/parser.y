/* File: parser.y
 * --------------
 * Yacc input file to generate the parser for the compiler.
 *
 * pp2: your job is to write a parser that will construct the parse tree
 *      and if no parse errors were found, print it.  The parser should 
 *      accept the language as described in specification, and as augmented 
 *      in the pp2 handout.
 */

%{

/* Just like lex, the text within this first region delimited by %{ and %}
 * is assumed to be C/C++ code and will be copied verbatim to the y.tab.c
 * file ahead of the definitions of the yyparse() function. Add other header
 * file inclusions or C++ variable declarations/prototypes that are needed
 * by your code here.
 */
#include "scanner.h" // for yylex
#include "parser.h"
#include "errors.h"

void yyerror(const char *msg); // standard error-handling routine

%}

/* The section before the first %% is the Definitions section of the yacc
 * input file. Here is where you declare tokens and types, add precedence
 * and associativity options, and so on.
 */
 
/* yylval 
 * ------
 * Here we define the type of the yylval global variable that is used by

 * the scanner to store attibute information about the token just scanned
 * and thus communicate that information to the parser. 
 *
 * pp2: You will need to add new fields to this union as you add different 
 *      attributes to your non-terminal symbols.
 */
%union {
    int integerConstant;
    bool boolConstant;
    char *stringConstant;
    double doubleConstant;
    char identifier[MaxIdentLen+1]; // +1 for terminating null
    Decl *decl;
    VarDecl *var;
    FnDecl *fDecl;
    ClassDecl *cDecl;
    InterfaceDecl *iDecl;
    Type *type;
    Stmt *stmt;
    Expr *expr;
    List<Stmt*> *stmtList;
    List<VarDecl*> *varList;
    List<Decl*> *declList;
    List<Expr*> *exprList;
}



/* Tokens
 * ------
 * Here we tell yacc about all the token types that we are using.
 * Yacc will assign unique numbers to these and export the #defineR
 * in the generated y.tab.h header file.
 */
%token   T_Void T_Bool T_Int T_Double T_String T_Class 
%token   T_LessEqual T_GreaterEqual T_Equal T_NotEqual T_Dims
%token   T_And T_Or T_Null T_Extends T_This T_Interface T_Implements
%token   T_While T_For T_If T_Else T_Return T_Break
%token   T_New T_NewArray T_Print T_ReadInteger T_ReadLine

%token   <identifier> T_Identifier
%token   <stringConstant> T_StringConstant 
%token   <integerConstant> T_IntConstant
%token   <doubleConstant> T_DoubleConstant
%token   <boolConstant> T_BoolConstant


/* Non-terminal types
 * ------------------
 * In order for yacc to assign/access the correct field of $$, $1, we
 * must to declare which field is appropriate for the non-terminal.
 * As an example, this first type declaration establishes that the DeclList
 * non-terminal uses the field named "declList" in the yylval union. This
 * means that when we are setting $$ for a reduction for DeclList ore reading
 * $n which corresponds to a DeclList nonterminal we are accessing the field
 * of the union named "declList" which is of type List<Decl*>.
 * pp2: You'll need to add many of these of your own.
 */
%type <declList>  DeclList 
%type <decl>      Decl
%type <type>      Type 
%type <var>       Variable VarDecl
%type <varList>   Formals FormalList VarDecls
%type <fDecl>     FnDecl FnHeader
%type <iDecl>     InterfaceDecl
%type <cDecl>	  ClassDecl
%type <field>     Field
%type <fields>    Fields
%type <prototype> Prototype
%type <protoList> ProtoList
%type <stmtList>  StmtList
%type <stmt>      StmtBlock IfStmt WhileStmt ForStmt BreakStmt ReturnStmt PrintStmt
%type <expr> 	  Expr PeExpr
%type <exprList>  ExprList NeExprList



//Precedence Rules
%nonassoc LTELSE
%nonassoc T_Else
%left '<' '>' T_LessEqual T_GreaterEqual T_Equal T_NotEqual '='
%left T_Or T_And
%left '+' '-'
%left '/' '*' '%'
%left '!'
%left  '.' 
%left '(' '['
%left UNARY

%%
/* Rules
 * -----
 * All productions and actions should be placed between the start and stop
 * %% markers which delimit the Rules section.
	 
 */
Program   :    DeclList            { 
                                      @1; 
                                      /* pp2: The @1 is needed to convince 
                                       * yacc to set up yylloc. You can remove 
                                       * it once you have other uses of @n*/
                                      Program *program = new Program($1);
                                      // if no errors, advance to next phase
                                      if (ReportError::NumErrors() == 0) 
                                          program->Print(0);
                                    }
          ;

DeclList  :    DeclList Decl        { ($$=$1)->Append($2); }
          |    Decl                 { ($$ = new List<Decl*>)->Append($1); };

Decl      :    VarDecl              { $$=$1; }
          |    FnDecl               { $$=$1; }
	  |    ClassDecl	    {}
	  |    InterfaceDecl	    {}
;

InterfaceDecl: T_Interface T_Identifier '{' ProtoList '}' {}

ProtoList: {}
	 | Prototype ProtoList {}

Prototype : Type T_Identifier '(' Formals ')' ';' {}
	  | T_Void T_Identifier '(' Formals ')' ';' {}

ClassDecl :    T_Class T_Identifier  PolyList '{' Fields '}' {}
;
PolyList : T_Extends ImplList {}
	 | ImplList {}  
;
Fields : {}
       | Field Fields {}
;
Field : VarDecl {}
      |  FnDecl {}
;
ImplList: {}
	| T_Implements T_Identifier {}
	| ',' T_Implements T_Identifier {} 
;

VarDecl   :    Variable ';'         { $$=$1; }
; 

Variable   :   Type T_Identifier    { $$ = new VarDecl(new Identifier(@2, $2), $1); }
;

Type      :    T_Int                { $$ = Type::intType; }
          |    T_Bool               { $$ = Type::boolType; }
          |    T_String             { $$ = Type::stringType; }
          |    T_Double             { $$ = Type::doubleType; }
          |    T_Identifier         { $$ = new NamedType(new Identifier(@1,$1)); }
          |    Type T_Dims          { $$ = new ArrayType(Join(@1, @2), $1); }
;

FnDecl    :    FnHeader StmtBlock   { ($$=$1)->SetFunctionBody($2); }
;

FnHeader  :    Type T_Identifier '(' Formals ')'  
                                    { $$ = new FnDecl(new Identifier(@2, $2), $1, $4); }
          |    T_Void T_Identifier '(' Formals ')' 
                                    { $$ = new FnDecl(new Identifier(@2, $2), Type::voidType, $4); }
;

Formals   :    FormalList           { $$ = $1; }
          |    /* empty */          { $$ = new List<VarDecl*>; }
;

FormalList:    FormalList ',' Variable  
                                    { ($$=$1)->Append($3); }
          |    Variable             { ($$ = new List<VarDecl*>)->Append($1); }
;

StmtBlock :    '{' VarDecls StmtList '}' 
                                    { $$ = new StmtBlock($2, $3); }
;

VarDecls  : VarDecls VarDecl     { ($$=$1)->Append($2); }
          | /* empty*/           { $$ = new List<VarDecl*>; }
;

StmtList  : /* empty, add your grammar */  { $$ = new List<Stmt*>; }
	  | Stmt StmtList {}
;
Stmt : PeExpr ';'
     |  IfStmt {}
     | WhileStmt {}
     | ForStmt {}
     | BreakStmt {}
     | ReturnStmt {}
     | PrintStmt {} 
     | StmtBlock {}
;
	 
PeExpr : {} | Expr
;

IfStmt : T_If '(' Expr ')' Stmt %prec LTELSE  {}
	| T_If '(' Expr ')' Stmt T_Else Stmt {}
;


WhileStmt : T_While '('Expr')' Stmt {}
;

ForStmt : T_For '(' PeExpr ';' Expr ';' PeExpr ')' Stmt {}
;

ReturnStmt : T_Return PeExpr ';' {}
;

BreakStmt : T_Break ';' {}
;

PrintStmt : T_Print '(' NeExprList ')' ';' {}
;

NeExprList : NeExprList',' Expr | Expr {}
;

ExprList :NeExprList {} | {} 
;

Expr : LValue '=' Expr {}
	| Constant {}
	| LValue {} 
	| T_This {} 
	| Call {}
	| '(' Expr ')' {}
	| Expr '+' Expr {}
	| Expr '-' Expr {}
	| Expr '*' Expr {}
	| Expr '/' Expr {}
	| Expr '%' Expr {}
	| '-' Expr %prec UNARY  {$$ = new ArithmeticExpr(new Operator(@1, "-"), $2);}
	| Expr '<' Expr {}
	| Expr T_LessEqual Expr {}
	| Expr '>' Expr {}
	| Expr T_GreaterEqual Expr {}
	| Expr T_Equal Expr {}
	| Expr T_NotEqual Expr {}
	| Expr T_And Expr {}
	| Expr T_Or Expr {}
	| '!' Expr {}
	| T_ReadInteger '('')' {}
	| T_ReadLine '('')' {}
	| T_New '(' T_Identifier ')' {}
	| T_NewArray '(' Expr ',' Type ')' {}
;

LValue : T_Identifier {}
	| Expr '.' T_Identifier {}
	| Expr '['Expr']'{}
;
Call : T_Identifier '(' ExprList ')' {}
	| Expr '.' T_Identifier '('ExprList ')' {}
;

/* Actuals is implemented under the name "ExprList" because I thought it was more readable */

Constant : T_IntConstant {}
	| T_DoubleConstant {}
	| T_BoolConstant {}
	| T_StringConstant {}
	| T_Null {}  
;
%%

/* The closing %% above marks the end of the Rules section and the beginning
 * of the User Subroutines section. All text from here to the end of the
 * file is copied verbatim to the end of the generated y.tab.c file.
 * This section is where you put definitions of helper functions.
 */

/* Function: InitParser
 * --------------------
 * This function will be called before any calls to yyparse().  It is designed
 * to give you an opportunity to do anything that must be done to initialize
 * the parser (set global variables, configure starting state, etc.). One
 * thing it already does for you is assign the value of the global variable
 * yydebug that controls whether yacc prints debugging information about
 * parser actions (shift/reduce) and contents of state stack during parser.
 * If set to false, no information is printed. Setting it to true will give
 * you a running trail that might be helpful when debugging your parser.
 * Please be sure the variable is set to false when submitting your final
 * version.
 */
void InitParser()
{
   PrintDebug("parser", "Initializing parser");
   yydebug = false;
}
