/*
 * $Source$
 * $Revision$
 * $Date$
 * $Author$
 */

%{

/*****************************************************************************
 * f2jparse                                                                  *
 *                                                                           *
 * This is a yacc parser for a subset of Fortran 77.  It builds an AST       *
 * which is used by codegen() to generate Java code.                         *
 *                                                                           *
 *****************************************************************************/

#include<stdio.h>
#include<stdlib.h>
#include<ctype.h>
#include<string.h>
#include"f2j.h"
#include"class.h"
#include"constant_pool.h"
#include"f2jmem.h"
#include"f2j_externs.h"

/*****************************************************************************
 * Define YYDEBUG as 1 to get debugging output from yacc.                    *
 *****************************************************************************/

#define YYDEBUG 0 

/*****************************************************************************
 * Global variables.                                                         *
 *****************************************************************************/

int 
  debug = FALSE,                  /* set to TRUE for debugging output        */
  emittem = 1,                    /* set to 1 to emit Java, 0 to just parse  */
  len = 1,                        /* keeps track of the size of a data type  */
  temptok,                        /* temporary token for an inline expr      */
  save_all;                       /* is there a SAVE stmt without a var list */

char
  tempname[60];                   /* temporary string                        */

AST 
  * equivList = NULL;             /* list to keep track of equivalences      */

CPNODE
  * lastConstant;                 /* last constant inserted into the c.pool  */

/*****************************************************************************
 * Function prototypes:                                                      *
 *****************************************************************************/

int 
  yylex(void);

double
  eval_const_expr(AST *);

char 
  * strdup(const char *),
  * lowercase(char * ),
  * first_char_is_minus(char *),
  * tok2str(int );

void 
  yyerror(char *),
  start_vcg(AST *),
  emit(AST *),
  jas_emit(AST *),
  init_tables(void),
  addEquiv(AST *),
  assign(AST *),
  typecheck(AST *),
  optScalar(AST *),
  type_insert (SYMTABLE * , AST * , enum returntype , char *),
  type_hash(AST *),
  merge_common_blocks(AST *),
  arg_table_load(AST *),
  exp_to_double (char *, char *),
  prepend_minus(char *),
  insert_name(SYMTABLE *, AST *, enum returntype),
  store_array_var(AST *),
  initialize_implicit_table(ITAB_ENTRY *),
  printbits(char *, void *, int);

AST 
  * dl_astnode_examine(Dlist l),
  * addnode(void),
  * switchem(AST *),
  * gen_incr_expr(AST *, AST *),
  * gen_iter_expr(AST *, AST *, AST *),
  * initialize_name(char *);

SYMTABLE 
  * new_symtable (int );

ITAB_ENTRY implicit_table[26];

%}

%union {
   struct ast_node *ptnode;
   int tok;
   enum returntype type;
   char lexeme[80];
}

/* generic tokens */

%token PLUS MINUS OP CP STAR POW DIV CAT CM EQ COLON NL
%token NOT AND OR
%token  RELOP EQV NEQV
%token <lexeme>  NAME DOUBLE INTEGER EXPONENTIAL 
%token CONST_EXP TrUE FaLSE ICON RCON LCON CCON
%token FLOAT CHARACTER LOGICAL COMPLEX NONE

/* a zillion keywords */

%token IF THEN ELSE ELSEIF ENDIF DO GOTO ASSIGN TO CONTINUE STOP
%token RDWR END  STRING CHAR  PAUSE
%token OPEN CLOSE BACKSPACE REWIND ENDFILE FORMAT
%token PROGRAM FUNCTION SUBROUTINE ENTRY CALL RETURN
%token <type> TYPE  
%token DIMENSION INCLUDE
%token COMMON EQUIVALENCE EXTERNAL PARAMETER INTRINSIC IMPLICIT
%token SAVE DATA COMMENT READ WRITE PRINT FMT EDIT_DESC REPEAT

%token OPEN_IOSTAT OPEN_ERR OPEN_FILE OPEN_STATUS OPEN_ACCESS 
%token OPEN_FORM OPEN_UNIT OPEN_RECL OPEN_BLANK

/* these are here to silence conflicts related to parsing comments */

%nonassoc RELOP 
%nonassoc LOWER_THAN_COMMENT
%nonassoc COMMENT

/*  All of my additions or changes to Levine's code. These 
 * non-terminals are in alphabetic order because I have had to 
 * change the grammar quite a bit.  It is tiring trying to root
 * out the location of a non-terminal, much easier to find when
 * in alphabetic order. 
 */

%type <ptnode> Arraydeclaration Arrayname Arraynamelist Assignment
%type <ptnode> Arrayindexlist Arithmeticif ArraydecList
%type <ptnode> Blockif Boolean Close Comment
%type <ptnode> Call Constant Continue
%type <ptnode> Data DataList DataConstant DataItem 
%type <ptnode> /* DataElement */ Do_incr Doloop 
%type <ptnode> DataLhs DataConstantList Dimension LoopBounds
%type <ptnode> Do_vals Double
%type <ptnode> EquivalenceStmt EquivalenceList EquivalenceItem
%type <ptnode> Else Elseif Elseifs End Exp Explist Exponential External
%type <ptnode> Function Functionargs F2java
%type <ptnode> Fprogram Ffunction Fsubroutine
%type <ptnode> Goto Common CommonList CommonSpec ComputedGoto
%type <ptnode> IfBlock Implicit Integer Intlist Intrinsic
%type <ptnode> ImplicitSpecItem ImplicitLetterList ImplicitLetter
%type <ptnode> Label Lhs Logicalif
%type <ptnode> Name UndeclaredName Namelist UndeclaredNamelist
%type <ptnode> LhsList Open
%type <ptnode> Parameter  Pdec Pdecs Program PrintIoList
%type <ptnode> Read IoExp IoExplist Return  Rewind
%type <ptnode> Save Specstmt Specstmts SpecStmtList Statements 
%type <ptnode> Statement Subroutinecall
%type <ptnode> Sourcecodes  Sourcecode Star
%type <ptnode> String  Subroutine Stop SubstringOp Pause
%type <ptnode> Typestmt Typevar Typevarlist
%type <type>   Types Type 
%type <ptnode> Write WriteFileDesc FormatSpec EndSpec
%type <ptnode> Format FormatExplist FormatExp FormatSeparator
%type <ptnode> RepeatableItem UnRepeatableItem RepeatSpec 
%type <ptnode> log_disjunct log_term log_factor log_primary
%type <ptnode> arith_expr term factor char_expr primary
%type <ptnode> Ios CharExp OlistItem Olist UnitSpec

%%

F2java:   Sourcecodes
          {
            AST *temp, *prev, *commentList = NULL;

            if(debug)
              printf("F2java -> Sourcecodes\n");
	    /* $$ = addnode(); */
	    $$ = switchem($1);

#if VCG
            if(emittem) start_vcg($$);
#endif
            prev = NULL;
            for(temp=$$;temp!=NULL;temp=temp->nextstmt)
            {
              if(emittem) {

                if(temp->nodetype == Comment)
                {
                  if((prev == NULL) ||
                     ((prev != NULL) && (prev->nodetype != Comment)))
                    commentList = temp;
                }
                else
                {
                  /* commentList may be NULL here so we must check
                   * for that in codegen.
                   */
                  temp->astnode.source.prologComments = commentList;

                  typecheck(temp);

                  if(omitWrappers)
                    optScalar(temp);

                  emit(temp);

                  commentList = NULL;
                }
              }
              prev = temp;
            }
          }
;

Sourcecodes:   Sourcecode 
               {
                 AST *temp;

                 if(debug)
                   printf("Sourcecodes -> Sourcecode\n"); 
                 $$=$1;

                 /* insert the name of the program unit into the
                  * global function table.  this will allow optScalar()
                  * to easily get a pointer to a function. 
                  */

                 if(omitWrappers && ($1->nodetype != Comment)) {
                   temp = $1->astnode.source.progtype->astnode.source.name;

                   type_insert(global_func_table, $1, 0, temp->astnode.ident.name);
                 }
               }
             | Sourcecodes Sourcecode 
               {
                 AST *temp;

                 if(debug)
                   printf("Sourcecodes -> Sourcecodes Sourcecode\n");
                 $2->prevstmt = $1; 
                 $$=$2;

                 /* insert the name of the program unit into the
                  * global function table.  this will allow optScalar()
                  * to easily get a pointer to a function. 
                  */

                 if(omitWrappers && ($2->nodetype != Comment)) {
                   temp = $2->astnode.source.progtype->astnode.source.name;

                   type_insert(global_func_table, $2, 0, temp->astnode.ident.name);
                 }
               }
;

Sourcecode :    Fprogram
                { 
                  if(debug)
                    printf("Sourcecode -> Fprogram\n"); 
                  $$=$1;
                }
              | Fsubroutine
                { 
                  if(debug)
                    printf("Sourcecode -> Fsubroutine\n"); 
                  $$=$1;
                }
              | Ffunction
                { 
                  if(debug)
                    printf("Sourcecode -> Ffunction\n"); 
                  $$=$1;
                }
              | Comment
                { 
                  if(debug)
                    printf("Sourcecode -> Comment\n"); 
                  $$=$1;
                }
;

Fprogram:   Program Specstmts Statements End 
              {
                if(debug)
                  printf("Fprogram -> Program  Specstmts  Statements End\n");

                $$ = addnode();

                /* store the tables built during parsing into the
                 * AST node for access during code generation.
                 */

                $$->astnode.source.type_table = type_table;
                $$->astnode.source.external_table = external_table;
                $$->astnode.source.intrinsic_table = intrinsic_table;
                $$->astnode.source.args_table = args_table;
                $$->astnode.source.array_table = array_table; 
                $$->astnode.source.format_table = format_table; 
                $$->astnode.source.data_table = data_table; 
                $$->astnode.source.save_table = save_table; 
                $$->astnode.source.common_table = common_table; 
                $$->astnode.source.parameter_table = parameter_table; 
                $$->astnode.source.constants_table = constants_table;
                $$->astnode.source.equivalences = equivList; 

                $$->astnode.source.javadocComments = NULL; 
                $$->astnode.source.save_all = save_all; 

                /* initialize some values in this node */

                $$->astnode.source.needs_input = FALSE;
                $$->astnode.source.needs_reflection = FALSE;
                $$->astnode.source.needs_blas = FALSE;

                if(omitWrappers)
                  $$->astnode.source.scalarOptStatus = NOT_VISITED;

	        $1->parent = $$; /* 9-4-97 - Keith */
	        $2->parent = $$; /* 9-4-97 - Keith */
	        $3->parent = $$; /* 9-4-97 - Keith */
	        $4->parent = $$; /* 9-4-97 - Keith */
                $$->nodetype = Progunit;
                $$->astnode.source.progtype = $1;
                $$->astnode.source.typedecs = $2;
                $4->prevstmt = $3;
                $$->astnode.source.statements = switchem($4);

                /* a PROGRAM has no args, so set the symbol table
                   to NULL */
                args_table = NULL;  

                $1->astnode.source.descriptor = MAIN_DESCRIPTOR;
              }
;


Fsubroutine: Subroutine Specstmts Statements End 
              {
                HASHNODE *ht;
                AST *temp;

                if(debug)
                  printf("Fsubroutine -> Subroutine Specstmts Statements End\n");
                $$ = addnode();
	        $1->parent = $$; 
	        $2->parent = $$;
	        $3->parent = $$;
	        $4->parent = $$;
                $$->nodetype = Progunit;
                $$->astnode.source.progtype = $1;

                /* store the tables built during parsing into the
                 * AST node for access during code generation.
                 */

                $$->astnode.source.type_table = type_table;
                $$->astnode.source.external_table = external_table;
                $$->astnode.source.intrinsic_table = intrinsic_table;
                $$->astnode.source.args_table = args_table;
                $$->astnode.source.array_table = array_table; 
                $$->astnode.source.format_table = format_table; 
                $$->astnode.source.data_table = data_table; 
                $$->astnode.source.save_table = save_table; 
                $$->astnode.source.common_table = common_table; 
                $$->astnode.source.parameter_table = parameter_table; 
                $$->astnode.source.constants_table = constants_table;
                $$->astnode.source.equivalences = equivList; 

                $$->astnode.source.javadocComments = NULL; 
                $$->astnode.source.save_all = save_all; 

                /* initialize some values in this node */

                $$->astnode.source.needs_input = FALSE;
                $$->astnode.source.needs_reflection = FALSE;
                $$->astnode.source.needs_blas = FALSE;

                if(omitWrappers)
                  $$->astnode.source.scalarOptStatus = NOT_VISITED;

                $$->astnode.source.typedecs = $2;
                $4->prevstmt = $3;
                $$->astnode.source.statements = switchem($4);

                /* foreach arg to this program unit, store the array 
                 * size, if applicable, from the hash table into the
                 * node itself.
                 */

                for(temp=$1->astnode.source.args;temp!=NULL;temp=temp->nextstmt)
                {
                  if((ht=type_lookup(type_table,temp->astnode.ident.name)) != NULL)
                  {
                    temp->vartype=ht->variable->vartype;
                    temp->astnode.ident.arraylist=ht->variable->astnode.ident.arraylist;
                  }
                }
                
                type_insert(function_table, $1, 0,
                   $1->astnode.source.name->astnode.ident.name);
              }
;

Ffunction:   Function Specstmts Statements  End
              {
                HASHNODE *ht;
                AST *temp;

                if(debug)
                  printf("Ffunction ->   Function Specstmts Statements  End\n");

                $$ = addnode();

                /* store the tables built during parsing into the
                 * AST node for access during code generation.
                 */

                $$->astnode.source.type_table = type_table;
                $$->astnode.source.external_table = external_table;
                $$->astnode.source.intrinsic_table = intrinsic_table;
                $$->astnode.source.args_table = args_table;
                $$->astnode.source.array_table = array_table; 
                $$->astnode.source.format_table = format_table; 
                $$->astnode.source.data_table = data_table; 
                $$->astnode.source.save_table = save_table; 
                $$->astnode.source.common_table = common_table; 
                $$->astnode.source.parameter_table = parameter_table; 
                $$->astnode.source.constants_table = constants_table;
                $$->astnode.source.equivalences = equivList; 

                $$->astnode.source.javadocComments = NULL; 
                $$->astnode.source.save_all = save_all; 

                /* initialize some values in this node */

                $$->astnode.source.needs_input = FALSE;
                $$->astnode.source.needs_reflection = FALSE;
                $$->astnode.source.needs_blas = FALSE;
                if(omitWrappers)
                  $$->astnode.source.scalarOptStatus = NOT_VISITED;

	        $1->parent = $$; /* 9-4-97 - Keith */
	        $2->parent = $$; /* 9-4-97 - Keith */
	        $3->parent = $$; /* 9-4-97 - Keith */
	        $4->parent = $$; /* 9-4-97 - Keith */
                $$->nodetype = Progunit;
                $$->astnode.source.progtype = $1;
                $$->astnode.source.typedecs = $2;
		$4->prevstmt = $3;
                $$->astnode.source.statements = switchem($4);

                /* foreach arg to this program unit, store the array 
                 * size, if applicable, from the hash table into the
                 * node itself.
                 */

                for(temp=$1->astnode.source.args;temp!=NULL;temp=temp->nextstmt)
                {
                  if((ht=type_lookup(type_table,temp->astnode.ident.name)) != NULL)
                  {
                    temp->vartype=ht->variable->vartype;
                    temp->astnode.ident.arraylist=ht->variable->astnode.ident.arraylist;
                  }
                }

                type_insert(function_table, $1, 0,
                  $1->astnode.source.name->astnode.ident.name);
              }
;

Program:      PROGRAM UndeclaredName NL
              {
                 if(debug)
                   printf("Program ->  PROGRAM UndeclaredName\n");

                 $$ = addnode();
	         $2->parent = $$; /* 9-4-97 - Keith */
		 lowercase($2->astnode.ident.name);
		 $$->astnode.source.name = $2;
                 $$->nodetype = Program;
                 $$->token = PROGRAM;
                 $$->astnode.source.args = NULL;

                 init_tables();

                 fprintf(stderr," MAIN %s:\n",$2->astnode.ident.name);
              }
;

Subroutine: SUBROUTINE UndeclaredName Functionargs NL
              {
                 if(debug)
                   printf("Subroutine ->  SUBROUTINE UndeclaredName Functionargs NL\n");

                 $$ = addnode();
                 $2->parent = $$; /* 9-4-97 - Keith */
                 if($3 != NULL)
                   $3->parent = $$; /* 9-4-97 - Keith */

        /*         lowercase($2->astnode.ident.name);
                      commented out 11-7-97 - Keith */

                 $$->astnode.source.name = $2; 
                 $$->nodetype = Subroutine;
                 $$->token = SUBROUTINE;
                 $$->astnode.source.args = switchem($3);

                 fprintf(stderr,"\t%s:\n",$2->astnode.ident.name);
              }
          | SUBROUTINE UndeclaredName NL
              {
                 if(debug)
                   printf("Subroutine ->  SUBROUTINE UndeclaredName NL\n");

                 init_tables();
                 $$ = addnode();
                 $2->parent = $$; /* 9-4-97 - Keith */

        /*         lowercase($2->astnode.ident.name);  
                       commented out 11-7-97 - Keith */
                 $$->astnode.source.name = $2; 
                 $$->nodetype = Subroutine;
                 $$->token = SUBROUTINE;
                 $$->astnode.source.args = NULL;
                 fprintf(stderr,"\t%s:\n",$2->astnode.ident.name);
              }
;

Function:  Type FUNCTION UndeclaredName Functionargs NL 
           {
             if(debug)
               printf("Function ->  Type FUNCTION UndeclaredName Functionargs NL\n");
             $$ = addnode();

  	     $3->parent = $$;  /* 9-4-97 - Keith */
             if($4 != NULL)
               $4->parent = $$;  /* 9-4-97 - Keith */
             $$->astnode.source.name = $3;
             $$->nodetype = Function;
             $$->token = FUNCTION;
             $$->astnode.source.returns = $1;
             $$->vartype = $1;
             $$->astnode.source.args = switchem($4);

             /* since the function name is the implicit return value
              * and it can be treated as a variable, we insert it into
              * the hash table for lookup later.
              */

             $3->astnode.ident.localvnum = -1;
             insert_name(type_table, $3, $1);

             fprintf(stderr,"\t%s:\n",$3->astnode.ident.name);
           }
; 

Specstmts: SpecStmtList    %prec LOWER_THAN_COMMENT
           {
             $1 = switchem($1);
             type_hash($1); 
             $$=$1;
           }
;

SpecStmtList: Specstmt
           {
             $$=$1;
           }
         | SpecStmtList  Specstmt
           { 
             $2->prevstmt = $1; 
             $$ = $2; 
           }
;

Specstmt:  Dimension
           {
	     $$ = $1;
	   }
         | EquivalenceStmt
	   {
	     $$ = $1;
	   }
         | Common
	   {
	     $$ = $1;
	   }
         | Save      
           {
             $$=$1;
           }
         | Intrinsic
           {
             $$=$1;
           }
         | Typestmt
           {
             $$=$1;
           }
         | External
           {
             $$=$1;
           }
         | Parameter
           {
             $$=$1;
           }
         | Implicit
           {
             $$=$1;
           }
         | Data NL
           {
             $$=$1;
           }
         | Comment
	   {
             $$ = $1;
	   }
;

Dimension: DIMENSION ArraydecList NL
           {
             $$ = addnode();
             $2->parent = $$;
             $2 = switchem($2);
             $$->nodetype = Dimension;

             $$->astnode.typeunit.declist = $2;
           }
;

ArraydecList: Arraydeclaration CM ArraydecList
              {
                $3->prevstmt = $1;
                $$ = $3;
                $$->nodetype = Dimension;
              }
            | Arraydeclaration
              {
                $$ = $1;
                $$->nodetype = Dimension;
              }
;

/*  the EQUIVALENCE productions are taken from Robert Moniot's 
 *  ftnchek grammar.
 */

EquivalenceStmt: EQUIVALENCE EquivalenceList NL
                 {
                   $$ = addnode();
                   $$->nodetype = Equivalence;
                   $$->prevstmt = NULL;
                   $$->nextstmt = NULL;
                   $$->astnode.equiv.nlist = switchem($2);
                 }
;

EquivalenceList: OP EquivalenceItem CP
                 {
                   AST *tmp;

                   $$ = addnode();
                   $$->nodetype = Equivalence;
                   $$->prevstmt = NULL;
                   $$->nextstmt = NULL;
                   $$->astnode.equiv.clist = switchem($2);

                   for(tmp=$2;tmp!=NULL;tmp=tmp->prevstmt)
                     tmp->parent = $$;

                   addEquiv($$->astnode.equiv.clist);
                 }
               | EquivalenceList CM OP EquivalenceItem CP
                 {
                   AST *tmp;

                   $$ = addnode();
                   $$->nodetype = Equivalence;
                   $$->astnode.equiv.clist = switchem($4);
                   $$->prevstmt = $1;
                   $$->nextstmt = NULL;

                   for(tmp=$4;tmp!=NULL;tmp=tmp->prevstmt)
                     tmp->parent = $$;

                   addEquiv($$->astnode.equiv.clist);
                 }
;

EquivalenceItem: Lhs
                 {
                   $$ = $1;
                 }
               | EquivalenceItem CM Lhs
                 {
                   $3->prevstmt = $1;
                   $$ = $3;
                 }
;

Common: COMMON CommonList NL
        {
          $$ = addnode();
          $$->nodetype = CommonList;
          $$->astnode.common.name = NULL;

          $$->astnode.common.nlist = switchem($2);
          merge_common_blocks($$->astnode.common.nlist);
        }
;

CommonList: CommonSpec
            {
              $$ = $1;
            }
         |  CommonList CommonSpec
            {
              $2->prevstmt = $1;
              $$ = $2;
            }
;

CommonSpec: DIV UndeclaredName DIV Namelist
           {
              AST *temp;
              int pos;

              $$ = addnode();
              $$->nodetype = Common;
              $$->astnode.common.name = strdup($2->astnode.ident.name);
              $$->astnode.common.nlist = switchem($4);

              pos = 0;

              /* foreach variable in the COMMON block... */
              for(temp=$$->astnode.common.nlist;temp!=NULL;temp=temp->nextstmt)
              {
                temp->astnode.ident.commonBlockName = 
                  strdup($2->astnode.ident.name);

                if(omitWrappers)
                  temp->astnode.ident.position = pos++;

                /* insert this name into the common table */
                if(debug)
                  printf("@insert %s (block = %s) into common table\n",
                    temp->astnode.ident.name, $2->astnode.ident.name);

                type_insert(common_table, temp, Float, temp->astnode.ident.name);
              }

              type_insert(global_common_table, $$, Float, $$->astnode.common.name);
              free_ast_node($2);
           }
         | CAT Namelist     /* CAT is // */
           {
              AST *temp;

              /* This is an unnamed common block */

              $$ = addnode();
              $$->nodetype = Common;
              $$->astnode.common.name = strdup("Blank");
              $$->astnode.common.nlist = switchem($2);

              /* foreach variable in the COMMON block... */
              for(temp=$2;temp!=NULL;temp=temp->prevstmt) {
                temp->astnode.ident.commonBlockName = "Blank";

                /* insert this name into the common table */

                if(debug)
                  printf("@@insert %s (block = unnamed) into common table\n",
                    temp->astnode.ident.name);

                type_insert(common_table, temp, Float, temp->astnode.ident.name);
              }

              type_insert(global_common_table, $$, Float, $$->astnode.common.name);
           }
;

/* SAVE is ignored by the code generator.
 * ..not anymore 12/10/01 kgs 
 */

Save: SAVE NL
       {
         /*
          * I think in this case every variable is supposed to
          * be saved, but we already emit every variable as
          * static.  do nothing here.  --Keith
          */

         $$ = addnode();
         $$->nodetype = Save;
         save_all = TRUE;
       }
    | SAVE DIV Namelist DIV NL
           {
             AST *temp;

             $$ = addnode();
             $3->parent = $$; /* 9-4-97 - Keith */
             $$->nodetype = Save;

             for(temp=$3;temp!=NULL;temp=temp->prevstmt) {
               if(debug)
                 printf("@@insert %s into save table\n",
                    temp->astnode.ident.name);

               type_insert(save_table, temp, Float, temp->astnode.ident.name);
             }
	   }
    | SAVE Namelist NL
           {
             AST *temp;

             $$ = addnode();
             $2->parent = $$; /* 9-4-97 - Keith */
             $$->nodetype = Save;

             for(temp=$2;temp!=NULL;temp=temp->prevstmt) {
               if(debug)
                 printf("@@insert %s into save table\n",
                    temp->astnode.ident.name);

               type_insert(save_table, temp, Float, temp->astnode.ident.name);
             }
	   }
;

Implicit:   IMPLICIT ImplicitSpecList NL
            {
	      $$=addnode();
	      $$->nodetype = Specification;
	      $$->token = IMPLICIT;
	    }
         |  IMPLICIT NONE NL
            {
	      $$=addnode();
	      $$->nodetype = Specification;
	      $$->token = IMPLICIT;
              fprintf(stderr,"Warning: IMPLICIT NONE ignored.\n");
	    }
;

ImplicitSpecList: ImplicitSpecItem
                  {
                    /* I don't think anything needs to be done here */
                  }
                | ImplicitSpecList CM ImplicitSpecItem
                  {
                    /* or here either. */
                  }
;

ImplicitSpecItem:  Types OP ImplicitLetterList CP
                   {
                     AST *temp;

                     for(temp=$3;temp!=NULL;temp=temp->prevstmt) {
                       char *start_range, *end_range;
                       char start_char, end_char;
                       int i;

                       start_range = temp->astnode.expression.lhs->astnode.ident.name;
                       end_range = temp->astnode.expression.rhs->astnode.ident.name;

                       start_char = tolower(start_range[0]);
                       end_char = tolower(end_range[0]);

                       if((strlen(start_range) > 1) || (strlen(end_range) > 1)) {
                         yyerror("IMPLICIT spec must contain single character.");
                         exit(EXIT_FAILURE);
                       }

                       if(end_char < start_char) {
                         yyerror("IMPLICIT range in backwards order.");
                         exit(EXIT_FAILURE);
                       }

                       for(i=start_char - 'a'; i <= end_char - 'a'; i++) {
                         if(implicit_table[i].declared) {
                           yyerror("Duplicate letter specified in IMPLICIT statement.");
                           exit(EXIT_FAILURE);
                         }

                         implicit_table[i].type = $1;
                         implicit_table[i].declared = TRUE;
                         implicit_table[i].len = len;  /* global set in Types production */
                       }
                     }
                   }
;

ImplicitLetterList: ImplicitLetter
                    {
                      $$ = $1;
                    }
                  | ImplicitLetterList CM ImplicitLetter
                    {
                      $3->prevstmt = $1;
                      $$ = $3;
                    }
;

ImplicitLetter: UndeclaredName
                {
                  $$ = addnode();
                  $$->nodetype = Expression;
                  $$->astnode.expression.lhs = $1;
                  $$->astnode.expression.rhs = $1;
                }
              | UndeclaredName MINUS UndeclaredName
                {
                  $$ = addnode();
                  $$->nodetype = Expression;
                  $$->astnode.expression.lhs = $1;
                  $$->astnode.expression.rhs = $3;
                }
;

Data:       DATA DataList
            {
              /* $$ = $2; */
              $$ = addnode();
              $$->nodetype = DataList;
              $$->astnode.label.stmt = $2;
            } 
;

DataList:   DataItem
            {
              $$ = $1;
            }
        |   DataList CM DataItem
            {
              $3->prevstmt = $1;
              $$ = $3;
            }
;

DataItem:   LhsList DIV DataConstantList DIV
            {
              AST *temp;

              $$ = addnode();
              $$->astnode.data.nlist = switchem($1);
              $$->astnode.data.clist = switchem($3);

              $$->nodetype = DataStmt;
              $$->prevstmt = NULL;
              $$->nextstmt = NULL;

              for(temp=$1;temp!=NULL;temp=temp->prevstmt) {
                if(debug)
                  printf("@@insert %s into data table\n",
                     temp->astnode.ident.name);
                
                temp->parent = $$;

                if(temp->nodetype == DataImpliedLoop)
                  type_insert(data_table, temp, Float,
                     temp->astnode.forloop.Label->astnode.ident.name);
                else
                  type_insert(data_table, temp, Float, temp->astnode.ident.name);
              }
            }
;

DataConstantList:  DataConstant
                   {
                     $$ = $1;
                   }
                |  DataConstantList CM DataConstant
                   {
                     $3->prevstmt = $1;
                     $$ = $3;
                   }
;

DataConstant:  Constant
               {
                 $$ = $1;
               }
            |  UndeclaredName
               {
                 HASHNODE *hash_temp;
                 if((parameter_table != NULL) &&
                 ((hash_temp = type_lookup(parameter_table,yylval.lexeme)) != NULL))
                 {
                    $$ = addnode();
                    $$->nodetype = Constant;
                    $$->vartype = hash_temp->variable->vartype;
                    $$->token = hash_temp->variable->token;
                    strcpy($$->astnode.constant.number,
                      hash_temp->variable->astnode.constant.number);
                 }
                 else{
                    printf("Error: '%s' is not a constant\n",yylval.lexeme);
                    exit(1);
                 }
               }   
            |  MINUS Constant   
               {
                 prepend_minus($2->astnode.constant.number);
                 $$ = $2;
               }
            |  Constant STAR Constant
               {
                 $$ = $1;
                 $$=addnode();
                 $$->nodetype = Binaryop;
                 $$->token = STAR;
                 $1->expr_side = left;
                 $3->expr_side = right;
                 $1->parent = $$;
                 $3->parent = $$;
                 $$->astnode.expression.lhs = $1;
                 $$->astnode.expression.rhs = $3;
                 $$->astnode.expression.optype = '*';
               }
;

LhsList:  DataLhs
          {
            $$ = $1;
          }
        | DataLhs CM LhsList
          {
            $3->prevstmt = $1;
            $$ = $3;
          }
;

DataLhs:  Lhs
          {
            $$ = $1;
          }
        | OP Lhs CM UndeclaredName EQ LoopBounds CP
          {
            $6->astnode.forloop.counter = $4;
            $6->astnode.forloop.Label = $2;
            $$ = $6;
            $2->parent = $$;
            $4->parent = $$;
          }
;

LoopBounds:  Integer CM Integer
             {
               $$ = addnode();
               $1->parent = $$;
               $3->parent = $$;
               $$->nodetype = DataImpliedLoop;
               $$->astnode.forloop.start = $1;
               $$->astnode.forloop.stop = $3;
               $$->astnode.forloop.incr = NULL;
             }
           | Integer CM Integer CM Integer
             {
               $$ = addnode();
               $1->parent = $$;
               $3->parent = $$;
               $5->parent = $$;
               $$->nodetype = DataImpliedLoop;
               $$->astnode.forloop.start = $1;
               $$->astnode.forloop.stop = $3;
               $$->astnode.forloop.incr = $5;
             }
;

/*  Here is where the fun begins.  */

/*  No newline token here.  Newlines have to be dealt with at 
 *  a lower level.
 */

Statements:    Statement  
               {  
                 $$ = $1; 
               }
             | Statements  Statement 
               { 
                 $2->prevstmt = $1; 
                 $$ = $2; 
               }
;

Statement:    Assignment  NL /* NL has to be here because of parameter dec. */
              {
                $$ = $1;
                $$->nodetype = Assignment;   
              }
            | Call
              {
                $$ = $1;
                $$->nodetype = Call;
              }
            | Logicalif
              {
                $$ = $1;
                $$->nodetype = Logicalif;
              }
            | Arithmeticif
              {
                $$ = $1;
                $$->nodetype = Arithmeticif;
              }
            | Blockif
              {
                $$ = $1;
                $$->nodetype = Blockif;
              }
            | Doloop
              {
                $$ = $1;
                $$->nodetype = Forloop;
              }
            | Return
              {
                $$ = $1;
                $$->nodetype = Return;
              }
            | ComputedGoto
              {
                $$ = $1;
                $$->nodetype = ComputedGoto;
              }
            | Goto
              {
                $$ = $1;
                $$->nodetype = Goto;
              }
            | Label
              {
                $$ = $1;
                $$->nodetype = Label;
              }
            | Continue
              {
                $$ = $1;
                $$->nodetype = Label;
              }
            | Write
              {
                $$ = $1;
                $$->nodetype = Write;
              }
            | Read
              {
                $$ = $1;
                $$->nodetype = Read;
              }
            | Stop
              {
                $$ = $1;
                $$->nodetype = Stop;
              }
            | Pause
              {
                $$ = $1;
                $$->nodetype = Pause;
              }
            | Open
              {
                $$ = $1;
                $$->nodetype = Unimplemented;
              }
            | Close
              {
                $$ = $1;
                $$->nodetype = Unimplemented;
              }
            | Comment
              {
                $$ = $1;
                $$->nodetype = Comment;
              }
            | Rewind
              {
                $$ = $1;
                $$->nodetype = Unimplemented;
              }
;           

Comment: COMMENT NL
         {
           $$ = addnode();
           $$->token = COMMENT;
           $$->nodetype = Comment;
           $$->astnode.ident.len = 0;
           strcpy($$->astnode.ident.name, yylval.lexeme);
         }
;

Open: OPEN OP Olist CP NL
      {
        fprintf(stderr,"Warning: OPEN not implemented.. skipping.\n");
      }
;

Olist: Olist CM OlistItem
        /* UNIMPLEMENTED */
     | OlistItem
        /* UNIMPLEMENTED */
;

OlistItem: OPEN_UNIT EQ UnitSpec
           {
             /* UNIMPLEMENTED */
             $$ = $3;
           }
         | OPEN_IOSTAT EQ Ios
           {
             /* UNIMPLEMENTED */
             $$ = $3;
           }
         | OPEN_ERR EQ Integer
           {
             /* UNIMPLEMENTED */
             $$ = $3;
           }
         | OPEN_FILE EQ CharExp
           {
             /* UNIMPLEMENTED */
             $$ = $3;
           }
         | OPEN_STATUS EQ CharExp
           {
             /* UNIMPLEMENTED */
             $$ = $3;
           }
         | OPEN_ACCESS EQ CharExp
           {
             /* UNIMPLEMENTED */
             $$ = $3;
           }
         | OPEN_FORM EQ CharExp
           {
             /* UNIMPLEMENTED */
             $$ = $3;
           }
         | OPEN_RECL EQ Exp
           {
             /* UNIMPLEMENTED */
             $$ = $3;
           }
         | OPEN_BLANK EQ CharExp
           {
             /* UNIMPLEMENTED */
             $$ = $3;
           }
;

UnitSpec: Exp
           {
             /* UNIMPLEMENTED */
             $$ = $1;
           }
        | STAR
           {
             /* UNIMPLEMENTED */
             $$ = addnode();
           }
;

CharExp: UndeclaredName
         /* UNIMPLEMENTED */
       | String
         /* UNIMPLEMENTED */
;

Ios: UndeclaredName
      /* UNIMPLEMENTED */
   | UndeclaredName OP Arrayindexlist CP
      /* UNIMPLEMENTED */
;

Close:  CLOSE OP UndeclaredName CP NL
        {
          fprintf(stderr,"WArning: CLOSE not implemented.\n");
          $$ = $3;
        }
;

Rewind: REWIND UndeclaredName NL
        {
          fprintf(stderr,"Warning: REWIND not implemented.\n");
          $$ = $2;
        }
;

End:    END  NL 
        {
          $$ = addnode();
          $$->token = END;
          $$->nodetype = End;
        }
;

/* 
 * We have to load up a symbol table here with the names of all the
 * variables that are passed in as arguments to our function or
 * subroutine.  Also need to pass `namelist' off to a procedure
 * to load a local variable table for opcode generation.   
 *
 * i inlined the call to init_tables() because when parsing the
 * argument list, if some arg matched a name previously defined as
 * a PARAMETER in some other program unit, then arg_table_load()
 * would catch that and assume that the Name represented a paramter
 * and reinitialize the node as if it were a constant.  kgs 7/26/00
 */

Functionargs:   OP {init_tables();} Namelist CP   
                {
                  $3 = switchem($3);
                  arg_table_load($3);
                  $$ = $3;
                }
              | OP CP
                {
                  init_tables();
                  $$ = NULL;
                }
;


Namelist:   Name  
            {
              $$=$1;
            }
          | Namelist CM Name 
            {
              $3->prevstmt = $1; 
              $$ = $3;
            }
;

/* 
 *  Somewhere in the actions associated with this production,
 * I need to ship off the type and variable list to get hashed.
 * Also need to pass `typevarlist' off to a procedure
 * to load a local variable table for opcode generation.
 */

Typestmt:      Types Typevarlist NL
              {
                 AST *temp;

                 $$ = addnode();
                 free_ast_node($2->parent);
                 $2 = switchem($2);
                 $$->nodetype = Typedec;

                 for(temp = $2; temp != NULL; temp = temp->nextstmt)
                 {
                   temp->vartype = $1;
                   temp->astnode.ident.len = len;
                   temp->parent = $$;
                 }

                 $$->astnode.typeunit.declist = $2;
                 $$->astnode.typeunit.returns = $1; 
	       }
;


Types:       Type 
             {
               $$ = $1;
               len = 1;
             }
          |  Type Star Integer
             {
               $$ = $1;
               len = atoi($3->astnode.constant.number);
               free_ast_node($2);
               free_ast_node($3);
             }
	  |  Type Star OP Star CP
             {
               $$ = $1;
               len = -1;
               free_ast_node($2);
               free_ast_node($4);
             }
;

Type:  TYPE
       { 
         $$ = yylval.type;
       }
;

/* Here I'm going to do the same thing I did with Explist.  That is,
 * each element in the list of typevars will have a parent link to a 
 * single node indicating that the context of the array is a
 * declaration.  --Keith 
 */

Typevarlist: Typevar
             {
               $1->parent = addnode();
               $1->parent->nodetype = Typedec;

               $$ = $1;
             }
          |  Typevarlist CM  Typevar
             {
               $3->prevstmt = $1;
               $3->parent = $1->parent;
               $$ = $3;
             }
;

Typevar:   Name 
           {
             $$ = $1;
           }
         | Arraydeclaration 
           {
             $$ = $1;
           }
;

/*  Deleted the Type REAL hack...  Need to take care of that in the 
 *  lexer.  This CHAR and STRING stuff is in the wrong place and
 *  needs to get axed.  Putting the TYPE back in ...
 *        ^^^^^^^^^^^ it is commented out for now 9-12-97, Keith
 *                 moved to 'Constant' production 9-17-97, Keith
 */

/*
 *  Might have to explicitly set the arraydeclist pointer to
 *  NULL in this action.  `Name' gets pointed to by the node
 *  that carries the array information.
 */

Name:    NAME  
         {
           HASHNODE *hashtemp;

           lowercase(yylval.lexeme);

           if(type_lookup(java_keyword_table,yylval.lexeme) ||
             type_lookup(jasmin_keyword_table,yylval.lexeme))
                yylval.lexeme[0] = toupper(yylval.lexeme[0]);


           /* check if the name we're looking at is defined as a parameter.
            * if so, instead of inserting an Identifier node here, we're just
            * going to insert the Constant node that corresponds to
            * the parameter.  normally the only time we'd worry about
            * such a substitution would be when the ident was the lhs
            * of some expression, but that should not happen with parameters.
            *
            * otherwise, if not a parameter, get a new AST node initialized
            * with this name.
            *
            * added check for null parameter table because this Name could
            * be reduced before we initialize the tables.  that would mean
            * that this name is the function name, so we dont want this to
            * be a parameter anyway.  kgs 11/7/00
            * 
            */

           if((parameter_table != NULL) &&
              ((hashtemp = type_lookup(parameter_table,yylval.lexeme)) != NULL))
           {
             /* had a problem here just setting $$ = hashtemp->variable
              * when there's an arraydec with two of the same PARAMETERS
              * in the arraynamelist, e.g. A(NMAX,NMAX).   so, instead we
              * just copy the relevant fields from the constant node.
              */
             $$ = addnode();
             $$->nodetype = hashtemp->variable->nodetype;
             $$->vartype = hashtemp->variable->vartype;
             $$->token = hashtemp->variable->token;
             strcpy($$->astnode.constant.number,
                 hashtemp->variable->astnode.constant.number);
           }
           else
             $$ = initialize_name(yylval.lexeme);
         }
;

/* 
 * UndeclaredName is similar to Name except that it is used in
 * contexts where the name is not actually going to be a declared
 * variable.  Thus in Name, we can insert implicitly defined variables
 * into the hash table, but here in UndeclaredName we do not.
 */

UndeclaredName: NAME
                {
                  lowercase(yylval.lexeme);

                  $$=addnode();
                  $$->token = NAME;
                  $$->nodetype = Identifier;

                  $$->astnode.ident.needs_declaration = FALSE;

                  if(omitWrappers)
                    $$->astnode.ident.passByRef = FALSE;

                  if(type_lookup(java_keyword_table,yylval.lexeme) ||
                     type_lookup(jasmin_keyword_table,yylval.lexeme))
                        yylval.lexeme[0] = toupper(yylval.lexeme[0]);

                  strcpy($$->astnode.ident.name, yylval.lexeme);
                }
;

UndeclaredNamelist:   UndeclaredName
            {
              $$=$1;
            }
          | UndeclaredNamelist CM UndeclaredName
            {
              $3->prevstmt = $1;
              $$ = $3;
            }
;

String:  STRING
         {
           $$=addnode();
           $$->token = STRING;
           $$->nodetype = Constant;
           strcpy($$->astnode.constant.number, yylval.lexeme);

           $$->vartype = String;
           if(debug)
             printf("**The string value is %s\n",$$->astnode.constant.number);
         }
       | CHAR
         {
           $$=addnode();
           $$->token = STRING;
           $$->nodetype = Constant;
           strcpy($$->astnode.constant.number, yylval.lexeme);

           $$->vartype = String;
           if(debug)
             printf("**The char value is %s\n",$$->astnode.constant.number);
         }
;

Arraydeclaration: Name OP Arraynamelist CP 
                  {
                    AST *temp;
                    int count, i;

		    /*
                     *  $$ = addnode();
                     *  $$->nodetype = Identifier;
                     *  strcpy($$->astnode.ident.name, $1->astnode.ident.name);
		     */

		    $$ = $1;
                    if(debug)
                      printf("reduced arraydeclaration... calling switchem\n");
		    $$->astnode.ident.arraylist = switchem($3);
                  
                    count = 0;
                    for(temp = $$->astnode.ident.arraylist; temp != NULL; 
                        temp=temp->nextstmt)
                      count++;

                    if(count > MAX_ARRAY_DIM) {
                      fprintf(stderr,"Error: array %s exceeds maximum ",
                         $$->astnode.ident.name);
                      fprintf(stderr,"number of dimensions: %d\n", 
                         MAX_ARRAY_DIM);
                      exit(EXIT_FAILURE);
                    }

                    $$->astnode.ident.dim = count;

                    for(temp = $$->astnode.ident.arraylist, i = 0;
                        temp != NULL; 
                        temp=temp->nextstmt, i++)
                    {
/* $$->astnode.ident.D[i] = (int) eval_const_expr(temp); */

                      /* if this dimension is an implied size, then set both
                       * start and end to NULL.
                       */

                      if((temp->nodetype == Identifier) && 
                        (temp->astnode.ident.name[0] == '*'))
                      {
                        $$->astnode.ident.startDim[i] = NULL;
                        $$->astnode.ident.endDim[i] = NULL;
                      }
                      else if(temp->nodetype == ArrayIdxRange) {
                        $$->astnode.ident.startDim[i] = temp->astnode.expression.lhs;
                        $$->astnode.ident.endDim[i] = temp->astnode.expression.rhs;
                      }
                      else {
                        $$->astnode.ident.startDim[i] = NULL;
                        $$->astnode.ident.endDim[i] = temp;
                      }
                    }
                       
/*
*                    $$->astnode.ident.lead_expr = NULL;
*/
 	            $$->astnode.ident.leaddim = NULL;
   
                    /* leaddim might be a constant, so check for that.  --keith */
                    if($$->astnode.ident.arraylist->nodetype == Constant) 
                    {
 	              $$->astnode.ident.leaddim = 
                       strdup($$->astnode.ident.arraylist->astnode.constant.number);
                    }
/*
*                   else if(($$->astnode.ident.arraylist->nodetype == Binaryop) ||
*                           ($$->astnode.ident.arraylist->nodetype == ArrayIdxRange)) {
*	              $$->astnode.ident.lead_expr = $$->astnode.ident.arraylist;
*                   }
*/
                    else {
 	              $$->astnode.ident.leaddim = 
                       strdup($$->astnode.ident.arraylist->astnode.ident.name);
                    }
/*
*
*                   if(debug)
*                   {
*                     printf("leaddim nodetype = %s\n",
*                       print_nodetype($$->astnode.ident.arraylist));
*
*                     if($$->astnode.ident.leaddim != NULL)
*                       printf("setting leaddim = %s\n",$$->astnode.ident.leaddim);
*                   }
*/

		    store_array_var($$);
                  }
;

Arraynamelist:    Arrayname 
                  {
                    AST *temp;

                    temp = addnode();
                    temp->nodetype = ArrayDec;
                    $1->parent = temp;
                    if($1->nodetype == ArrayIdxRange) {
                      $1->astnode.expression.lhs->parent = temp;
                      $1->astnode.expression.rhs->parent = temp;
                    }

                    $$=$1;
                  }
                | Arraynamelist CM Arrayname 
                  {
                    $3->prevstmt = $1; 
                    $3->parent = $1->parent;
                    if($3->nodetype == ArrayIdxRange) {
                      $3->astnode.expression.lhs->parent = $1->parent;
                      $3->astnode.expression.rhs->parent = $1->parent;
                    }
                    $$ = $3;
                  }
;

Arrayname: Exp 
           {
             $$ = $1; 
           }
         | Star 
           {
             $$=$1;
           }
         | Exp COLON Exp 
           {
             $$ = addnode();
             $$->nodetype = ArrayIdxRange;
             $$->astnode.expression.lhs = $1;
             $$->astnode.expression.rhs = $3;
           }
;

/*  We reduce STAR here, make changes in the Binaryops
 *  reductions for that.  This handles the fortran array
 *  declaration, e.g., array(*).  
 */

Star:  STAR 
       {
         $$=addnode();
         $$->nodetype = Identifier;
        *$$->astnode.ident.name = '*';
       }
;

/*  At some point, I will need to typecheck the `Name' on the left
 *  hand side of this rule in case it has an array form.  If it looks like
 *  an array, but it isn't in the array table, that's an error. 
 */

Assignment:  Lhs  EQ Exp /* NL (Assignment is also used in the parameter
                          *  declaration, where it is not followed by a NL.
                          */
             { 
                $$ = addnode();
                $1->parent = $$; /* 9-4-97 - Keith */
                $3->parent = $$; /* 9-4-97 - Keith */
                $$->nodetype = Assignment;
                $$->astnode.assignment.lhs = $1;
                $$->astnode.assignment.rhs = $3;
             }
;

Lhs:     Name
         {
           $$=$1;
           $$->nextstmt = NULL;
           $$->prevstmt = NULL;
         }
      |  Name OP Arrayindexlist CP
         {
           AST *temp;

           /*   Use the following declaration in case we 
            *   need to switch index order. 
            *
            *   HASHNODE * hashtemp;  
            */

           $$ = addnode();
           $1->parent = $$; /* 9-4-97 - Keith */
           $$->nodetype = Identifier;
           $$->prevstmt = NULL;
           $$->nextstmt = NULL;

           free_ast_node($3->parent);
           for(temp = $3; temp != NULL; temp = temp->prevstmt)
             temp->parent = $$;

           strcpy($$->astnode.ident.name, $1->astnode.ident.name);

           /*  This is in case we want to switch index order later.
            *
            *  hashtemp = type_lookup(array_table, $1->astnode.ident.name);
            *  if(hashtemp)
            *    $$->astnode.ident.arraylist = $3;
            *  else
            *    $$->astnode.ident.arraylist = switchem($3);
            */

           /* We don't switch index order.  */

           $$->astnode.ident.arraylist = switchem($3);
           free_ast_node($1);
         }
      |  Name OP Exp COLON Exp CP
         {
           $$=addnode();
           $1->parent = $$;
           $3->parent = $$;
           $5->parent = $$;
           strcpy($$->astnode.ident.name, $1->astnode.ident.name);
           $$->nodetype = Substring;
           $$->token = NAME;
           $$->prevstmt = NULL;
           $$->nextstmt = NULL;
           $$->astnode.ident.arraylist = $3;
           $3->nextstmt = $5;
           free_ast_node($1);
         }
;

Arrayindexlist:   Exp 
                  { 
                    $1->parent = addnode();
                    $1->parent->nodetype = Identifier;

                    $$ = $1;
                  }
                | Arrayindexlist CM Exp
                  {
                    $3->prevstmt = $1;
                    $3->parent = $1->parent;
		    $$ = $3;
		  }
;

/*  New do loop productions.  Entails rewriting in codegen.c
 *  to emit java source code.  
 */

Doloop:   Do_incr Do_vals
          {
            $$ = $2;
            $$->nodetype = Forloop;
            $$->astnode.forloop.Label = $1;
          }
;


Do_incr:  DO Integer 
          { 
            $$ = $2;
          } 

        | DO Integer CM 
          { 
            $$ = $2;
          }
;


Do_vals:  Assignment CM Exp   NL
          {
            AST *counter;

            $$ = addnode();
	    $1->parent = $$; /* 9-4-97 - Keith */
	    $3->parent = $$; /* 9-4-97 - Keith */
            counter = $$->astnode.forloop.counter = $1->astnode.assignment.lhs;
            $$->astnode.forloop.start = $1;
            $$->astnode.forloop.stop = $3;
            $$->astnode.forloop.incr = NULL;
            $$->astnode.forloop.iter_expr = gen_iter_expr($1->astnode.assignment.rhs,$3,NULL);
            $$->astnode.forloop.incr_expr = gen_incr_expr(counter,NULL);
          }
       | Assignment CM Exp CM Exp   NL
         {
           AST *counter;

           $$ = addnode();
	   $1->parent = $$; /* 9-4-97 - Keith */
	   $3->parent = $$; /* 9-4-97 - Keith */
	   $5->parent = $$; /* 9-4-97 - Keith */
           counter = $$->astnode.forloop.counter = $1->astnode.assignment.lhs;
           $$->nodetype = Forloop;
           $$->astnode.forloop.start = $1;
           $$->astnode.forloop.stop = $3;
           $$->astnode.forloop.incr = $5;
           $$->astnode.forloop.iter_expr = gen_iter_expr($1->astnode.assignment.rhs,$3,$5);
           $$->astnode.forloop.incr_expr = gen_incr_expr(counter,$5);
         }
;

/* 
 * changed the Label production to allow any statement to have
 * a line number.   -- keith
 */
Label: Integer Statement
       {
         $$ = addnode();
         $1->parent = $$;
         $2->parent = $$;
         $$->nodetype = Label;
         $$->astnode.label.number = atoi($1->astnode.constant.number);
         $$->astnode.label.stmt = $2;
         free_ast_node($1);
       }
     | Integer Format NL 
       {
         /* HASHNODE *newnode; */
         char *tmpLabel;

         tmpLabel = (char *) f2jalloc(10); /* plenty of space for a f77 label num */

         /* newnode = (HASHNODE *) f2jalloc(sizeof(HASHNODE)); */

         $$ = addnode();
         $1->parent = $$;
         $2->parent = $$;
         $$->nodetype = Format;
         $$->astnode.label.number = atoi($1->astnode.constant.number);
         $$->astnode.label.stmt = $2;
         $2->astnode.label.number = $$->astnode.label.number;
         if(debug)
           printf("@@ inserting format line num %d\n",$$->astnode.label.number);

         sprintf(tmpLabel,"%d",$2->astnode.label.number);

         type_insert(format_table,$2,0,tmpLabel);
         free_ast_node($1);
       }
;

/*  The following productions for FORMAT parsing are derived
 *  from Robert K. Moniot's grammar (see ftnchek-2.9.4) 
 */

Format: FORMAT OP FormatExplist CP
       {
         $$ = addnode();
         $$->nodetype = Format;
         $$->astnode.label.stmt = switchem($3);
       }
;

FormatExplist:   FormatExp
           {
             AST *temp;

             temp = addnode();
             temp->nodetype = Format;
             $1->parent = temp;

             $$ = $1;
           }
         | FormatExplist FormatExp
           {
             $1->nextstmt = $2;
             $2->prevstmt = $1;
             $2->parent = $1->parent;
             if(($2->token == REPEAT) && ($1->token == INTEGER)) {
               $2->astnode.label.number = atoi($1->astnode.constant.number);

               if(debug)
                 printf("## setting number = %s\n", $1->astnode.constant.number);
             }
             if(debug) {
               if($2->token == REPEAT)
                 printf("## $2 is repeat token, $1 = %s ##\n",tok2str($1->token));
               if($1->token == REPEAT)
                 printf("## $1 is repeat token, $2 = %s ##\n",tok2str($2->token));
             }
             $$ = $2;
           }
;

FormatExp:  
       RepeatableItem
       {
         $$ = $1;
       }
     | UnRepeatableItem 
       {
         $$ = $1;
       }
     | FormatSeparator
       {
         $$ = $1;
       }
;

RepeatableItem:  EDIT_DESC  /* A, F, I, D, G, E, L, X */
       {
         $$ = addnode();
         $$->token = EDIT_DESC;
         strcpy($$->astnode.ident.name, yylval.lexeme);
       }
     | UndeclaredName
       {
         $$ = $1;
       }
     | UndeclaredName '.' Constant
       {
         /* ignore the constant part for now */
         free_ast_node($3);

         $$ = $1;
       }
     | OP FormatExplist CP
       {
         $$ = addnode();
         $$->token = REPEAT;
         $$->astnode.label.stmt = switchem($2);
         if(debug)
           printf("## setting number = 1\n");
         $$->astnode.label.number = 1;
       }
;

UnRepeatableItem:  String
       {
         $$ = $1;
       }
     | RepeatSpec
       {
         $$ = $1;
       }
;

FormatSeparator:
       CM
       {
         $$ = addnode();
         $$->token = CM;
       }
     | DIV
       {
         $$ = addnode();
         $$->token = DIV;
       }
     | CAT   /* CAT is two DIVs "//" */
       {
         $$ = addnode();
         $$->token = CAT;
       }
     | COLON
       {
         $$ = addnode();
         $$->token = COLON;
       }
;

RepeatSpec:  Integer
       {
         $$ = $1;
       }
     | PLUS Integer
       {
         $$ = $2;
       }
/*
  this will stay commented out until I know the
meaning of a negative repeat specification.

     | MINUS Integer
       {
         $$ = $1;
       }
*/
;

Continue:  Integer CONTINUE NL
       {
         $$ = addnode();
	 $1->parent = $$; /* 9-4-97 - Keith */
	 $$->nodetype = Label;
	 $$->astnode.label.number = atoi($1->astnode.constant.number);
	 $$->astnode.label.stmt = NULL;
         free_ast_node($1);
       }
;

Write: WRITE OP WriteFileDesc CM FormatSpec CP IoExplist NL
       {
         AST *temp;

         $$ = addnode();
         $$->astnode.io_stmt.io_type = Write;
         $$->astnode.io_stmt.fmt_list = NULL;

         /*  unimplemented
           $$->astnode.io_stmt.file_desc = ;
         */

         if($5->nodetype == Constant)
         {
           if($5->astnode.constant.number[0] == '*') {
             $$->astnode.io_stmt.format_num = -1;
             free_ast_node($5);
           }
           else if($5->token == STRING) {
             $$->astnode.io_stmt.format_num = -1;
             $$->astnode.io_stmt.fmt_list = $5;
           }
           else {
             $$->astnode.io_stmt.format_num = atoi($5->astnode.constant.number);
             free_ast_node($5);
           }
         }
         else
         {
           /* is this case ever reached??  i don't think so.  --kgs */
           $$->astnode.io_stmt.format_num = -1;
           $$->astnode.io_stmt.fmt_list = $5;
         }
 
         $$->astnode.io_stmt.arg_list = switchem($7);

         for(temp=$$->astnode.io_stmt.arg_list;temp!=NULL;temp=temp->nextstmt)
           temp->parent->nodetype = Write;

         /* currently ignoring the file descriptor.. */
         free_ast_node($3);
       }
     | PRINT Integer PrintIoList NL
       {
         AST *temp;

         $$ = addnode();
         $$->astnode.io_stmt.io_type = Write;
         $$->astnode.io_stmt.fmt_list = NULL;

         $$->astnode.io_stmt.format_num = atoi($2->astnode.constant.number);
         $$->astnode.io_stmt.arg_list = switchem($3);

         for(temp=$$->astnode.io_stmt.arg_list;temp!=NULL;temp=temp->nextstmt)
           temp->parent->nodetype = Write;
         free_ast_node($2);
       }
     | PRINT STAR PrintIoList NL
       {
         AST *temp;

         $$ = addnode();
         $$->astnode.io_stmt.io_type = Write;
         $$->astnode.io_stmt.fmt_list = NULL;

         $$->astnode.io_stmt.format_num = -1;
         $$->astnode.io_stmt.arg_list = switchem($3);
           
         for(temp=$$->astnode.io_stmt.arg_list;temp!=NULL;temp=temp->nextstmt)
           temp->parent->nodetype = Write;
       }
     | PRINT String PrintIoList NL
       {
         AST *temp;

         $$ = addnode();
         $$->astnode.io_stmt.io_type = Write;
         $$->astnode.io_stmt.fmt_list = $2;

         $$->astnode.io_stmt.format_num = -1;
         $$->astnode.io_stmt.arg_list = switchem($3);

         for(temp=$$->astnode.io_stmt.arg_list;temp!=NULL;temp=temp->nextstmt)
           temp->parent->nodetype = Write;
       }
;

PrintIoList: CM IoExplist
             {
               $$ = $2;
             }
           | /* empty */
             {
               $$ = NULL;
             }
;

/* Maybe I'll implement this stuff someday. */

WriteFileDesc: 
      Exp
       {
         /* do nothing for now */
         $$ = $1;
       }
    | STAR
       {
         /* do nothing for now */
          $$ = addnode();
          $$->token = INTEGER;
          $$->nodetype = Constant;
          strcpy($$->astnode.constant.number,"*");
          $$->vartype = Integer;
       }
;
     
FormatSpec:
       FMT EQ Integer
        {
          $$ = $3;
        }
     | Integer
        {
          $$ = $1;
        }
     | FMT EQ STAR
        {
          $$ = addnode();
	  $$->token = INTEGER;
          $$->nodetype = Constant;
          strcpy($$->astnode.constant.number,"*");
	  $$->vartype = Integer;
        }
     | STAR
        {
          $$ = addnode();
	  $$->token = INTEGER;
          $$->nodetype = Constant;
          strcpy($$->astnode.constant.number,"*");
	  $$->vartype = Integer;
        }
     | FMT EQ String
        {
          $$ = $3;
        }
     | FMT EQ UndeclaredName
        {
          fprintf(stderr,"Warning - ignoring FMT = %s\n",
             $3->astnode.ident.name);
          $$ = addnode();
	  $$->token = INTEGER;
          $$->nodetype = Constant;
          strcpy($$->astnode.constant.number,"*");
	  $$->vartype = Integer;
        }
;

Read: READ OP WriteFileDesc CM FormatSpec CP IoExplist NL
      {
         AST *temp;

         $$ = addnode();
         $$->astnode.io_stmt.io_type = Read;
         $$->astnode.io_stmt.fmt_list = NULL;
         $$->astnode.io_stmt.end_num = -1;

         $$->astnode.io_stmt.arg_list = switchem($7);

         if($$->astnode.io_stmt.arg_list && $$->astnode.io_stmt.arg_list->parent)
           free_ast_node($$->astnode.io_stmt.arg_list->parent);

         for(temp=$$->astnode.io_stmt.arg_list;temp!=NULL;temp=temp->nextstmt)
           temp->parent = $$;

         /* currently ignoring the file descriptor and format spec. */
         free_ast_node($3);
         free_ast_node($5);
      }
    | READ OP WriteFileDesc CM FormatSpec CM EndSpec CP IoExplist NL
      {
         AST *temp;

         $$ = addnode();
         $$->astnode.io_stmt.io_type = Read;
         $$->astnode.io_stmt.fmt_list = NULL;
         $$->astnode.io_stmt.end_num = atoi($7->astnode.constant.number);
         free_ast_node($7);

         $$->astnode.io_stmt.arg_list = switchem($9);

         if($$->astnode.io_stmt.arg_list && $$->astnode.io_stmt.arg_list->parent)
           free_ast_node($$->astnode.io_stmt.arg_list->parent);

         for(temp=$$->astnode.io_stmt.arg_list;temp!=NULL;temp=temp->nextstmt)
           temp->parent = $$;

         /* currently ignoring the file descriptor.. */
         free_ast_node($3);
         free_ast_node($5);
      }
;

IoExplist: IoExp
           {
             $1->parent = addnode();
             $1->parent->nodetype = IoExplist;

             $$ = $1;
           }
         | IoExplist CM IoExp
           {
             $3->prevstmt = $1;
             $3->parent = $1->parent;
             $$ = $3;
           }
         | /* empty - should this be allowed for READ? */
           {
             $$ = NULL;
           }
;

IoExp: Exp
       {
         $$ = $1;
       }
     | OP Explist CM UndeclaredName EQ Exp CM Exp CP /* implied do loop */
       {
         AST *temp;

         $$ = addnode();
         $$->nodetype = IoImpliedLoop;
         $$->astnode.forloop.start = $6;
         $$->astnode.forloop.stop = $8;
         $$->astnode.forloop.incr = NULL;
         $$->astnode.forloop.counter = $4;
         $$->astnode.forloop.Label = switchem($2);
         $$->astnode.forloop.iter_expr = gen_iter_expr($6,$8,NULL);
         $$->astnode.forloop.incr_expr = gen_incr_expr($4,NULL);

         $2->parent = $$;
         for(temp = $2; temp != NULL; temp = temp->nextstmt)
           temp->parent = $$;
         $4->parent = $$;
         $6->parent = $$;
         $8->parent = $$;
       }
     | OP Explist CM UndeclaredName EQ Exp CM Exp CM Exp CP /* implied do loop */
       {
         AST *temp;

         $$ = addnode();
         $$->nodetype = IoImpliedLoop;
         $$->astnode.forloop.start = $6;
         $$->astnode.forloop.stop = $8;
         $$->astnode.forloop.incr = $10;
         $$->astnode.forloop.counter = $4;
         $$->astnode.forloop.Label = switchem($2);
         $$->astnode.forloop.iter_expr = gen_iter_expr($6,$8,$10);
         $$->astnode.forloop.incr_expr = gen_incr_expr($4,$10);

         $2->parent = $$;
         for(temp = $2; temp != NULL; temp = temp->nextstmt)
           temp->parent = $$;
         $4->parent = $$;
         $6->parent = $$;
         $8->parent = $$;
         $10->parent = $$;
       }
;

EndSpec: END EQ Integer
         {
           $$ = $3;
         }
;

/*  Got a problem when a Blockif opens with a Blockif.  The
 *  first statement of the second Blockif doesn't get into the
 *  tree.  Might be able to use do loop for example to fix this. 
 *
 *  --apparently the problem mentioned in the comment above has
 *    been fixed now.
 */

Blockif:   IF OP Exp CP THEN NL IfBlock Elseifs Else  ENDIF NL
           {
             $$ = addnode();
             $3->parent = $$;
             if($7 != NULL)
               $7->parent = $$; /* 9-4-97 - Keith */
             if($8 != NULL) 
               $8->parent = $$; /* 9-4-97 - Keith */
             if($9 != NULL)
               $9->parent = $$; /* 9-4-97 - Keith */
             $$->nodetype = Blockif;
             $$->astnode.blockif.conds = $3;
             $7 = switchem($7);
             $$->astnode.blockif.stmts = $7;

             /*  If there are any `else if' statements,
              *  switchem. Otherwise, NULL pointer checked
              *  in code generating functions. 
              */
             $8 = switchem($8); 
             $$->astnode.blockif.elseifstmts = $8; /* Might be NULL. */
             $$->astnode.blockif.elsestmts = $9;   /* Might be NULL. */
           }
;

IfBlock:  /* Empty. */ {$$=0;} /* if block may be null */
        | Statements
          {
             $$ = $1;
          }
;

Elseifs:  /* Empty. */ {$$=0;} /* No `else if' statements, NULL pointer. */
        |  Elseif 
           {
              $$ = $1;
           }
        | Elseifs Elseif 
          {
             $2->prevstmt = $1;
	     $$ = $2;
          } 
;


Elseif: ELSEIF OP Exp CP THEN NL Statements 
        {
          $$=addnode();
	  $3->parent = $$;  
	  $7->parent = $$; /* 9-4-97 - Keith */
	  $$->nodetype = Elseif;
	  $$->astnode.blockif.conds = $3;
	  $$->astnode.blockif.stmts = switchem($7);
        }
;


Else:  /* Empty. */  {$$=0;}  /* No `else' statements, NULL pointer. */
        | ELSE NL  Statements 
          {
             $$=addnode();
	     $3->parent = $$; /* 9-4-97 - Keith */
	     $$->nodetype = Else;
	     $$->astnode.blockif.stmts = switchem($3);
          }
;


Logicalif: IF OP Exp CP Statement
           {
             $$ = addnode();
             $3->parent = $$;
             $5->parent = $$; /* 9-4-97 - Keith */
             $$->astnode.logicalif.conds = $3;
             $$->astnode.logicalif.stmts = $5;
           }           
;

Arithmeticif: IF OP Exp CP Integer CM Integer CM Integer NL
              {
                $$ = addnode();
                $$->nodetype = Arithmeticif;
                $3->parent = $$;
                $5->parent = $$;
                $7->parent = $$;
                $9->parent = $$;

                $$->astnode.arithmeticif.cond = $3;
                $$->astnode.arithmeticif.neg_label  = atoi($5->astnode.constant.number);
                $$->astnode.arithmeticif.zero_label = atoi($7->astnode.constant.number);
                $$->astnode.arithmeticif.pos_label  = atoi($9->astnode.constant.number);
                free_ast_node($5);
                free_ast_node($7);
                free_ast_node($9);
              }
;

/* 
 * This _may_ have to be extended to deal with 
 * jasmin opcode.  Variables of type array need 
 * to have their arguments emitted in reverse order 
 * so that java can increment in row instead of column
 * order.  So we look each name up in the array table, 
 * it is in there we leave the argument list reversed, 
 * otherwise, it is a subroutine or function (method) 
 * call and we reverse the arguments.
 */

Subroutinecall:   Name OP Explist CP
                  {
                    /* Use the following declarations in case we 
                     * need to switch index order.
                     * 
                     * HASHNODE * hashtemp;  
                     * HASHNODE * ht;
                     */

                    $$ = addnode();
                    $1->parent = $$;  /* 9-4-97 - Keith */

                    /*  $3->parent = $$;  9-4-97 - Keith */

                    if($3 != NULL)
                      strcpy($3->parent->astnode.ident.name, 
                        $1->astnode.ident.name);

                    /*
                     *  Here we could look up the name in the array table and set 
                     *  the nodetype to ArrayAccess if it is found.  Then the code 
                     *  generator could easily distinguish between array accesses 
                     *  and function calls.  I'll have to implement the rest of 
                     *  this soon.  -- Keith
                     *
                     *     if(type_lookup(array_table, $1->astnode.ident.name))
                     *       $$->nodetype = ArrayAccess;
                     *     else
                     *       $$->nodetype = Identifier;
                     */

                    $$->nodetype = Identifier;

                    strcpy($$->astnode.ident.name, $1->astnode.ident.name);

                    /*  This is in case we want to switch index order later.
                     *
                     *  hashtemp = type_lookup(array_table, $1->astnode.ident.name);
                     *  if(hashtemp != NULL)
                     *    $$->astnode.ident.arraylist = $3;
                     *  else
                     */

                    /* We don't switch index order.  */
                    if($3 == NULL) {
                      $$->astnode.ident.arraylist = addnode();
                      $$->astnode.ident.arraylist->nodetype = EmptyArgList;
                    }
                    else
                      $$->astnode.ident.arraylist = switchem($3);

                    free_ast_node($1);
                  }
;

SubstringOp: Name OP Exp COLON Exp CP
           {
              if(debug)
                printf("SubString!\n");
              $$ = addnode();
              $1->parent = $$;
              $3->parent = $$;
              $5->parent = $$;
              strcpy($$->astnode.ident.name, $1->astnode.ident.name);
              $$->nodetype = Substring;
              $$->token = NAME;
              $$->astnode.ident.arraylist = $3;
              $3->nextstmt = $5;
              free_ast_node($1);
           }
;


/* 
 * What I'm going to try to do here is have each element
 * of the list linked back to a single node through its
 * parent pointer.  This will allow the code generator
 * to check the array context (whether it is being used
 * as part of an external call or part of a call to an
 * intrinsic function or some other use). --Keith 
 */

Explist:   Exp
           {
             AST *temp;

             temp = addnode();
             temp->nodetype = Call;
             $1->parent = temp;

             $$ = $1;
           }
         | Explist CM Exp
           {
             $3->prevstmt = $1;
             $3->parent = $1->parent;
             $$ = $3;
           }
         | /* empty */
           {
             $$ = NULL;
           }
;

/*  This is not exactly right.  There will need to 
 *  be a struct to handle this.
 */
Call:     CALL   Subroutinecall  NL
          {
             $$ = $2;
	     $$->nodetype = Call;
          }
       |  CALL UndeclaredName NL
          {
            $$ = addnode();
            $2->parent = $$;
            $$->nodetype = Identifier;
            strcpy($$->astnode.ident.name, $2->astnode.ident.name);
            $$->astnode.ident.arraylist = addnode();
            $$->astnode.ident.arraylist->nodetype = EmptyArgList;
            free_ast_node($2);
          }
;

/* again we borrowed from Moniot's grammar....from the Exp production down to
 * the primary production is from his ftnchek grammar.    --keith  2/17/98.
 */

Exp: log_disjunct
     {
       $$ = $1;
     }
   | Exp EQV log_disjunct
     {
       $$=addnode();
       $1->expr_side = left;
       $3->expr_side = right;
       $1->parent = $$;
       $3->parent = $$;
       $$->token = EQV;
       $$->nodetype = Logicalop;
       $$->astnode.expression.lhs = $1;
       $$->astnode.expression.rhs = $3;
     }
   | Exp NEQV log_disjunct
     {
       $$=addnode();
       $1->expr_side = left;
       $3->expr_side = right;
       $1->parent = $$;
       $3->parent = $$;
       $$->token = NEQV;
       $$->nodetype = Logicalop;
       $$->astnode.expression.lhs = $1;
       $$->astnode.expression.rhs = $3;
     }
;

log_disjunct: log_term
              {
                $$ = $1;
              }
            | log_disjunct OR log_term
              {
                $$=addnode();
		$1->expr_side = left;
		$3->expr_side = right;
		$1->parent = $$;
		$3->parent = $$;
		$$->token = OR;
		$$->nodetype = Logicalop;
		$$->astnode.expression.lhs = $1;
		$$->astnode.expression.rhs = $3;
              }
;
 
log_term: log_factor
          {
            $$ = $1;
          }
        | log_term AND log_factor
          {
            $$=addnode();
            $1->expr_side = left;
            $3->expr_side = right;
            $1->parent = $$;
            $3->parent = $$;
            $$->token = AND;
            $$->nodetype = Logicalop;
            $$->astnode.expression.lhs = $1;
            $$->astnode.expression.rhs = $3;
          }
;

log_factor: log_primary
            {
              $$ = $1;
            }
          | NOT log_primary
            {
              $$=addnode();
              $2->parent = $$;  /* 9-4-97 - Keith */
              $$->token = NOT;
              $$->nodetype = Logicalop;
              $$->astnode.expression.lhs = 0;
              $$->astnode.expression.rhs = $2;
            }
;
 
log_primary: arith_expr
             {
               $$ = $1;
             }
           | log_primary RELOP {temptok = yylval.tok;} log_primary
             {
               $$=addnode();
               $1->expr_side = left;
               $4->expr_side = right;
               $1->parent = $$;
               $4->parent = $$;
               $$->nodetype = Relationalop;
               $$->token = temptok;
               $$->astnode.expression.lhs = $1;
               $$->astnode.expression.rhs = $4;
             }
;

arith_expr: term
            {
              $$ = $1;
            }
          | MINUS term
            {
              if($2->nodetype == Constant) {
                prepend_minus($2->astnode.constant.number);
                $$ = $2;
              }
              else {
                $$ = addnode();
                $2->parent = $$;
                $$->astnode.expression.rhs = $2;
                $$->astnode.expression.lhs = 0;
                $$->astnode.expression.minus = '-';   
                $$->nodetype = Unaryop;
                $$->vartype = $2->vartype;
              }
            }
          | PLUS term
            {
              if($2->nodetype == Constant) {
                $$ = $2;
              }
              else {
                $$ = addnode();
                $2->parent = $$;
                $$->astnode.expression.rhs = $2;
                $$->astnode.expression.lhs = 0;
                $$->astnode.expression.minus = '+';
                $$->nodetype = Unaryop;
		  $$->vartype = $2->vartype;
              }
            }
          | arith_expr PLUS term
            {
              $$=addnode();
              $1->expr_side = left;
              $3->expr_side = right;
              $$->token = PLUS;
              $1->parent = $$;
              $3->parent = $$;
              $$->astnode.expression.lhs = $1;
              $$->astnode.expression.rhs = $3;
              $$->vartype = MIN($1->vartype, $3->vartype);
              $$->nodetype = Binaryop;
              $$->astnode.expression.optype = '+';
            }
          | arith_expr MINUS term
            {
              $$=addnode();
              $$->token = MINUS;
              $1->expr_side = left;
              $3->expr_side = right;
              $1->parent = $$;
              $3->parent = $$;
              $$->astnode.expression.lhs = $1;
              $$->astnode.expression.rhs = $3;
              $$->vartype = MIN($1->vartype, $3->vartype);
              $$->nodetype = Binaryop;
              $$->astnode.expression.optype = '-';
            }
;
 
term: factor
      {
        $$ = $1;
      }
    | term DIV factor
      {
        $$=addnode();
        $1->expr_side = left;
        $3->expr_side = right;
        $$->token = DIV;
        $1->parent = $$;
        $3->parent = $$;
        $$->astnode.expression.lhs = $1;
        $$->astnode.expression.rhs = $3;
	 $$->vartype = MIN($1->vartype, $3->vartype);
        $$->nodetype = Binaryop;
        $$->astnode.expression.optype = '/';
      }
    | term STAR factor
      {
        $$=addnode();

        $$->token = STAR;
        $1->expr_side = left;
        $3->expr_side = right;
        $1->parent = $$;
        $3->parent = $$;
        $$->astnode.expression.lhs = $1;
        $$->astnode.expression.rhs = $3;
	 $$->vartype = MIN($1->vartype, $3->vartype);
        $$->nodetype = Binaryop;
        $$->astnode.expression.optype = '*';
      }
;

factor: char_expr
        {
          $$ = $1;
        }
      | char_expr POW factor
        {
          $$=addnode();
          $1->parent = $$;
          $3->parent = $$;
 	  $$->nodetype = Power;
	  $$->astnode.expression.lhs = $1;
	  $$->astnode.expression.rhs = $3;
          $$->vartype = MIN($1->vartype, $3->vartype);
        }
;

char_expr: primary
           {
             $$ = $1;
           }
         | char_expr CAT primary
           {
             $$=addnode();
             $$->token = CAT;
             $1->expr_side = left;
             $3->expr_side = right;
             $1->parent = $$;
             $3->parent = $$;
             $$->astnode.expression.lhs = $1;
             $$->astnode.expression.rhs = $3;
             $$->vartype = MIN($1->vartype, $3->vartype);
             $$->nodetype = Binaryop;
             $$->astnode.expression.optype = '+';
           }
;

primary:     Name {$$=$1;}
          |  Constant
             {
	       $$ = $1;
	     }
   /*       |  Complex {$$=$1;} */
          |  Subroutinecall {$$=$1;}    
          |  SubstringOp {$$=$1;}    
          |  OP Exp CP  
             {
               $$ = addnode();
               $2->parent = $$;   /* 9-4-97 - Keith */
               $$->nodetype = Expression;
               $$->astnode.expression.parens = TRUE;
               $$->astnode.expression.rhs = $2;
               $$->astnode.expression.lhs = 0;
               $$->vartype = $2->vartype;
             }
;

/*
Complex: OP Constant CM Constant CP {$$=addnode();}
;
*/

/* `TRUE' and `FALSE' have already been typedefed
 * as BOOLEANs.  
 */
Boolean:  TrUE
             {
               $$ = addnode();
               $$->token = TrUE;
               $$->nodetype = Constant;
               strcpy($$->astnode.constant.number, "true");
               $$->vartype = Logical;
             }
         | FaLSE
             {
               $$ = addnode();
               $$->token = FaLSE;
               $$->nodetype = Constant;
               strcpy($$->astnode.constant.number, "false");
               $$->vartype = Logical;
             }

;

Constant:   
         Integer  
         { 
           $$ = $1; 
         }
       | Double
         { 
           $$ = $1; 
         }
       | Exponential
         { 
           $$ = $1; 
         }
       | Boolean
         { 
           $$ = $1; 
         }
       | String   /* 9-16-97, keith */
         { 
           $$ = $1; 
         }
; 

Integer :     INTEGER 
             {
               $$ = addnode();
               $$->token = INTEGER;
               $$->nodetype = Constant;
               strcpy($$->astnode.constant.number, yylval.lexeme);
               $$->vartype = Integer;
             }
;

Double:       DOUBLE
             {
               $$ = addnode();
	       $$->token = DOUBLE;
               $$->nodetype = Constant;
               strcpy($$->astnode.constant.number, yylval.lexeme);
               $$->vartype = Double;
             }
;
               
/*  Since jasmin doesn't have an EXPONENTIAL data type,
 *  the function exp_to_double rewrite numbers in the
 *  nn.dde+nn as floats.  The float is written back into
 *  the string temp.  
 *
 *  For small numbers, exp_to_double isn't good.  e.g., 
 *  something like 5.5e-15 would be transformed into
 *  "0.00000".
 *  
 *  I'll just change the 'D' to 'e' and emit as-is for
 *  Java.  With Jasmin, I'll still use exp_to_double
 *  for now, but it will be wrong.
 *
 *  3/11/98  -- Keith 
 */

Exponential:   EXPONENTIAL
             {
               $$ = addnode();
	       $$->token = EXPONENTIAL;
               $$->nodetype = Constant;
	       exp_to_double(yylval.lexeme, tempname);
               strcpy($$->astnode.constant.number, tempname);
               $$->vartype = Double;
             }
;

/*  All the easy productions that work go here.  */

Return:      RETURN NL
             {
                $$= addnode();
             }
;

Pause:  PAUSE NL
        {
          $$ = addnode();
          $$->nodetype = Pause;
          $$->astnode.constant.number[0] = 0;
        }
      | PAUSE String NL
        {
           $$ = $2;
           $$->nodetype = Pause;
        }
;

Stop:   STOP NL
        {
          $$ = addnode();
          $$->nodetype = Stop;
          $$->astnode.constant.number[0] = 0;
        }
      | STOP String NL
        {
           $$ = $2;
           $$->nodetype = Stop;
        }
;

Goto:   GOTO Integer  NL
        {
          $$ = addnode();
          $2->parent = $$;   /* 9-4-97 - Keith */
          $$->nodetype = Goto;
	  if(debug)
            printf("goto label: %d\n", atoi(yylval.lexeme)); 
          $$->astnode.go_to.label = atoi(yylval.lexeme);
          free_ast_node($2);
        }
;

ComputedGoto:   GOTO OP Intlist CP Exp NL
                {
                  $$ = addnode();
                  $3->parent = $$;   /* 9-4-97 - Keith */
                  $5->parent = $$;   /* 9-4-97 - Keith */
                  $$->nodetype = ComputedGoto;
                  $$->astnode.computed_goto.name = $5;
                  $$->astnode.computed_goto.intlist = switchem($3);
        	  if(debug)
        	    printf("Computed go to,\n");
                }    
              | GOTO OP Intlist CP CM Exp NL
                {
                  $$ = addnode();
                  $3->parent = $$;   /* 9-4-97 - Keith */
                  $6->parent = $$;   /* 9-4-97 - Keith */
                  $$->nodetype = ComputedGoto;
                  $$->astnode.computed_goto.name = $6;
                  $$->astnode.computed_goto.intlist = switchem($3);
        	  if(debug)
        	    printf("Computed go to,\n");
                }    
;

Intlist:   Integer
            {
              $$ = $1;
            }
      | Intlist CM Integer
            {
              $3->prevstmt = $1;
              $$ = $3;
            }
;

Parameter:   PARAMETER OP Pdecs CP NL 
             {
	       $$ = addnode();
               $3->parent = $$;   /* 9-4-97 - Keith */
	       $$->nodetype = Specification;
	       $$->astnode.typeunit.specification = Parameter;
               $$->astnode.typeunit.declist = switchem($3); 
             }
;

Pdecs:    Pdec 
          { 
            $$=$1;
          }
        | Pdecs CM Pdec 
          {
            $3->prevstmt = $1; 
            $$=$3;
          }
;

Pdec:     Assignment
          {
            void add_decimal_point(char *);
            double constant_eval;
            char *cur_id;
            AST *temp;

            if(debug)
              printf("Parameter...\n");

            $$ = $1;
            $$->nodetype = Assignment;

            constant_eval = eval_const_expr($$->astnode.assignment.rhs);

            if(debug) {
              printf("### constant_eval is %.40g\n", constant_eval);
              printf("### constant_eval is %.40e\n", constant_eval);
            }
            
            temp = addnode();
            temp->nodetype = Constant;
            temp->vartype = $$->astnode.assignment.rhs->vartype;
            
            switch($$->astnode.assignment.rhs->vartype) {
              case String:
              case Character:
                temp->token = STRING;
                strcpy(temp->astnode.constant.number, 
                       $$->astnode.assignment.rhs->astnode.constant.number);
                break;
              case Complex:
                fprintf(stderr,"Pdec: Complex not yet supported.\n");
                break;
              case Logical:
                temp->token = $$->astnode.assignment.rhs->token;
                strcpy(temp->astnode.constant.number, 
                       temp->token == TrUE ? "true" : "false");
                break;
              case Float:
              case Double:
                temp->token = DOUBLE;

                sprintf(temp->astnode.constant.number,"%.40g",constant_eval);
                add_decimal_point(temp->astnode.constant.number);
                
                break;
              case Integer:
                temp->token = INTEGER;
                sprintf(temp->astnode.constant.number,"%d",(int)constant_eval);
                break;
              default:
                fprintf(stderr,"Pdec: bad vartype!\n");
            }

            free_ast_node($$->astnode.assignment.rhs);
            $$->astnode.assignment.rhs = temp;
                                                      
            if(debug)
              printf("### the constant is '%s'\n",
                temp->astnode.constant.number);

            cur_id = strdup($$->astnode.assignment.lhs->astnode.ident.name);

            if(type_lookup(java_keyword_table,cur_id) ||
               type_lookup(jasmin_keyword_table,cur_id))
                  cur_id[0] = toupper(cur_id[0]);

            type_insert(parameter_table, temp, 0, cur_id);
            free_ast_node($$->astnode.assignment.lhs);
/*
            type_insert(parameter_table, temp, 0,
               $$->astnode.assignment.lhs->astnode.ident.name);
*/

            /*
             *  $$->astnode.typeunit.specification = Parameter; 
             *
             * Attach the Assignment node to a list... Hack.
             *  $$->astnode.typeunit.declist = $1;  
             */
          }
;

External:  EXTERNAL UndeclaredNamelist NL
           {
             $$=addnode(); 
             $2->parent = $$;  /* 9-3-97 - Keith */
             $$->nodetype = Specification;
             $$->token = EXTERNAL;
             $$->astnode.typeunit.declist = switchem($2);
             $$->astnode.typeunit.specification = External;
           }
;

Intrinsic: INTRINSIC UndeclaredNamelist NL
           {
             $$=addnode(); 
             $2->parent = $$;  /* 9-3-97 - Keith */
             $$->nodetype = Specification;
	     $$->token = INTRINSIC;
             $$->astnode.typeunit.declist = switchem($2);
             $$->astnode.typeunit.specification = Intrinsic;
           }
;


%%


/*****************************************************************************
 *                                                                           *
 * yyerror                                                                   *
 *                                                                           *
 * The standard yacc error routine.                                          *
 *                                                                           *
 *****************************************************************************/

void 
yyerror(char *s)
{
  extern Dlist file_stack;
  INCLUDED_FILE *pfile;
  Dlist tmp;

  if(current_file_info)
    printf("%s:%d: %s\n", current_file_info->name, lineno, s);
  else
    printf("line %d: %s\n", lineno, s);

  dl_traverse_b(tmp, file_stack) {
    pfile = (INCLUDED_FILE *)dl_val(tmp);

    printf("\tincluded from: %s:%d\n", pfile->name, pfile->line_num);
  }
}

/*****************************************************************************
 *                                                                           *
 * add_decimal_point                                                         *
 *                                                                           *
 * this is just a hack to compensate for the fact that there's no printf     *
 * specifier that does exactly what we want.  assume the given string        *
 * represents a floating point number.  if there's no decimal point in the   *
 * string, then append ".0" to it.  However, if there's an 'e' in the string *
 * then javac will interpret it as floating point.  The only real problem    *
 * that occurs is when the constant is too big to fit as an integer, but has *
 * no decimal point, so javac flags it as an error (int constant too big).   *
 *                                                                           *
 *****************************************************************************/

void
add_decimal_point(char *str)
{
  BOOL found_dec = FALSE;
  char *p = str;

  while( *p != '\0' ) {
    if( *p == '.' ) {
      found_dec = TRUE;
      break;
    }

    if( *p == 'e' )
      return;
    
    p++;
  }

  if(!found_dec)
    strcat(str, ".0");
}

/*****************************************************************************
 *                                                                           *
 * addnode                                                                   *
 *                                                                           *
 * To keep things simple, there is only one type of parse tree               *
 * node.  If there is any way to ensure that all the pointers                *
 * in this are NULL, it would be a good idea to do that.  I am               *
 * not sure what the default behavior is.                                    *
 *                                                                           *
 *****************************************************************************/

AST * 
addnode() 
{
  return (AST*)f2jcalloc(1,sizeof(AST));
}


/*****************************************************************************
 *                                                                           *
 * switchem                                                                  *
 *                                                                           *
 * Need to turn the linked list around,                                      *
 * so that it can traverse forward instead of in reverse.                    *
 * What I do here is create a doubly linked list.                            *
 * Note that there is no `sentinel' or `head' node                           *
 * in this list.  It is acyclic and terminates in                            *
 * NULL pointers.                                                            *
 *                                                                           *
 *****************************************************************************/

AST * 
switchem(AST * root) 
{
  if(root == NULL)
    return NULL;

  if (root->prevstmt == NULL) 
    return root;

  while (root->prevstmt != NULL) 
  {
    root->prevstmt->nextstmt = root;
    root = root->prevstmt;
  }

  return root;
}

/*****************************************************************************
 *                                                                           *
 * type_hash                                                                 *
 *                                                                           *
 * For now, type_hash takes a tree (linked list) of type                     *
 * declarations from the Decblock rule.  It will need to                     *
 * get those from Intrinsic, External, Parameter, etc.                       *
 *                                                                           *
 *****************************************************************************/

void 
type_hash(AST * types)
{
  HASHNODE *hash_entry;
  AST * temptypes, * tempnames;
  int return_type;
   
   /* Outer for loop traverses typestmts, inner for()
    * loop traverses declists. Code for stuffing symbol table is
    * is in inner for() loop.   
    */
  for (temptypes = types; temptypes; temptypes = temptypes->nextstmt)
  {
      /* Long assignment, set up the for() loop here instead of
         the expression list.  */
    tempnames = temptypes->astnode.typeunit.declist;

      /* Need to set the return value here before entering
         the next for() loop.  */
    return_type = temptypes->astnode.typeunit.returns;

    if(debug)
      printf("type_hash(): type dec is %s\n", print_nodetype(temptypes));

    /* skip parameter statements and data statements */
    if(( (temptypes->nodetype == Specification) &&
         (temptypes->astnode.typeunit.specification == Parameter)) 
        || (temptypes->nodetype == DataList))
      continue;

    for (; tempnames; tempnames = tempnames->nextstmt)
    {
      int i;

      /* ignore parameter assignment stmts */
      if((tempnames->nodetype == Assignment) ||
         (tempnames->nodetype == DataStmt))
        continue;
        
      /* Stuff names and return types into the symbol table. */
      if(debug)
        printf("Type hash: '%s' (%s)\n", tempnames->astnode.ident.name,
          print_nodetype(tempnames));
 
      if(temptypes->nodetype == Dimension) {
        /* looking at a Dimension spec.  check whether the ident is already
         * in the hash table.  if so, we want to assign the array dimensions
         * to that node.  if not, we will create a new node and assign the
         * dimensions to it.
         */
        AST *node;

        hash_entry = type_lookup(type_table, tempnames->astnode.ident.name);
        if(hash_entry)
          node = hash_entry->variable;
        else {
          node = initialize_name(tempnames->astnode.ident.name );
/*
 *        type_insert(type_table, node, 
 *           implicit_table[tempnames->astnode.ident.name[0] - 'a'].type,
 *           tempnames->astnode.ident.name);
 */

          if(debug)
            printf("Type hash (DIM): %s\n", tempnames->astnode.ident.name);
        }

        node->astnode.ident.localvnum = -1;
        node->astnode.ident.arraylist = tempnames->astnode.ident.arraylist;
        node->astnode.ident.dim = tempnames->astnode.ident.dim;
        node->astnode.ident.leaddim = tempnames->astnode.ident.leaddim;
        for(i=0;i<MAX_ARRAY_DIM;i++) {
          node->astnode.ident.startDim[i] = tempnames->astnode.ident.startDim[i];
          node->astnode.ident.endDim[i] = tempnames->astnode.ident.endDim[i];
        }
      }
      else {
        /* check whether there is already an array declaration for this ident.
         * this would be true in case of a normal type declaration with array
         * declarator, in which case we'll do a little extra work here.  but
         * for idents that were previously dimensioned, we need to get this
         * info out of the table.
         */

        hash_entry = type_lookup(array_table,tempnames->astnode.ident.name);
        if(hash_entry) {
          AST *var = hash_entry->variable;
  
          tempnames->astnode.ident.localvnum = -1;
          tempnames->astnode.ident.arraylist = var->astnode.ident.arraylist;
          tempnames->astnode.ident.dim = var->astnode.ident.dim;
          tempnames->astnode.ident.leaddim = var->astnode.ident.leaddim;
          for(i=0;i<MAX_ARRAY_DIM;i++) {
            tempnames->astnode.ident.startDim[i] = var->astnode.ident.startDim[i];
            tempnames->astnode.ident.endDim[i] = var->astnode.ident.endDim[i];
          }
        }

        if((temptypes->token != INTRINSIC) && (temptypes->token != EXTERNAL))
        {
          hash_entry = type_lookup(type_table,tempnames->astnode.ident.name);

          if(hash_entry == NULL) {
            tempnames->vartype = return_type;
            tempnames->astnode.ident.localvnum = -1;

            type_insert(type_table, tempnames, return_type,
               tempnames->astnode.ident.name);

            if(debug)
              printf("Type hash (non-external): %s\n",
                  tempnames->astnode.ident.name);
          }
          else {
            if(debug) {
              printf("type_hash: Entry already exists...");  
              printf("going to override the type.");  
            }
  
            /* tempnames->vartype = hash_entry->variable->vartype; */
            hash_entry->variable->vartype = tempnames->vartype;
          }
        }
      }

      /* Now separate out the EXTERNAL from the INTRINSIC on the
       * fortran side.
       */

      if(temptypes != NULL) {
        AST *newnode;

        /* create a new node to stick into the intrinsic/external table
         * so that the type_table isn't pointing to the same node.
         */
        newnode = addnode();
        strcpy(newnode->astnode.ident.name,tempnames->astnode.ident.name);
        newnode->vartype = return_type;
        newnode->nodetype = Identifier;

        switch (temptypes->token)
        {
          case INTRINSIC:
            type_insert(intrinsic_table, 
                    newnode, return_type, newnode->astnode.ident.name);

            if(debug)
              printf("Type hash (INTRINSIC): %s\n",
                newnode->astnode.ident.name);

            break;
          case EXTERNAL:
            type_insert(external_table,
                    newnode, return_type, newnode->astnode.ident.name);

            if(debug)
              printf("Type hash (EXTERNAL): %s\n",
                newnode->astnode.ident.name);

            break;
          default:
            /* otherwise free the node that we didn't use. */
            free_ast_node(newnode);
            break;  /* ansi thing */

        } /* Close switch().  */
      }
    }  /* Close inner for() loop.  */
  }    /* Close outer for() loop.  */
}      /* Close type_hash().       */


/*****************************************************************************
 *                                                                           *
 * exp_to_double                                                             *
 *                                                                           *
 *  Since jasmin doesn't have any EXPONENTIAL data types, these              *
 * have to be turned into floats.  exp_to_double really just                 *
 * replaces instances of 'd' and 'D' in the exponential number               *
 * with 'e' so that c can convert it on a string scan and                    *
 * string print.  Java does recognize numbers of the                         *
 * form 1.0e+1, so the `d' and `d' need to be replaced with                  *
 * `e'.  For now, leave as double for uniformity with jasmin.                *
 *                                                                           *
 *****************************************************************************/

void 
exp_to_double (char *lexeme, char *temp)
{
  char *cp = lexeme;

  while (*cp)           /* While *cp != '\0'...  */
  {
    if (*cp == 'd' ||   /*  sscanf can recognize 'E'. */
        *cp == 'D')
    {
       *cp = 'e';       /* Replace the 'd' or 'D' with 'e'. */
       break;           /* Should be only one 'd', 'D', etc. */
    }
    cp++;               /* Examine the next character. */
  }

  /* Java should be able to handle exponential notation as part
   * of the float or double constant. 
   */

 strcpy(temp,lexeme);
}  /*  Close exp_to_double().  */


/*****************************************************************************
 *                                                                           *
 * arg_table_load                                                            *
 *                                                                           *
 * Initialize and fill a table with the names of the                         *
 * variables passed in as arguments to the function or                       *
 * subroutine.  This table is later checked when variable                    *
 * types are declared so that variables are not declared                     *
 * twice.                                                                    *  
 *                                                                           *
 *****************************************************************************/

void
arg_table_load(AST * arglist)
{
  AST * temp;

  /* We traverse down `prevstmt' because the arglist is
   * built with right recursion, i.e. in reverse.  This
   * procedure, 'arg_table_load()' is called when the non-
   * terminal `functionargs' is reduced, before the
   * argument list is reversed. Note that a NULL pointer
   * at either end of the list terminates the for() loop. 
   */

   for(temp = arglist; temp; temp = temp->nextstmt)
   {
     type_insert(args_table, temp, 0, temp->astnode.ident.name);
     if(debug)
       printf("#@Arglist var. name: %s\n", temp->astnode.ident.name);
   }
}


/*****************************************************************************
 *                                                                           *
 * lowercase                                                                 *
 *                                                                           *
 * This function takes a string and converts all characters to               *
 * lowercase.                                                                *
 *                                                                           *
 *****************************************************************************/

char * lowercase(char * name)
{
  char *ptr = name;

  while (*name)
  {
    *name = tolower(*name);
     name++;
  }

  return ptr;
}

/*****************************************************************************
 *                                                                           *
 * store_array_var                                                           *
 *                                                                           *
 * We need to make a table of array variables, because                       *
 * fortran accesses arrays by columns instead of rows                        *
 * as C and java does.  During code generation, the array                    *
 * variables are emitted in reverse to get row order.                        *
 *                                                                           *
 *****************************************************************************/

void
store_array_var(AST * var)
{

  if(type_lookup(array_table, var->astnode.ident.name) != NULL)
    fprintf(stderr,"Error: more than one array declarator for array '%s'\n",
       var->astnode.ident.name);
  else
    type_insert(array_table, var, 0, var->astnode.ident.name);

  if(debug)
    printf("Array name: %s\n", var->astnode.ident.name);
}

/*****************************************************************************
 *                                                                           *
 * mypow                                                                     *
 *                                                                           *
 * Double power function.  writing this here so that we                      *
 * dont have to link in the math library.                                    *
 *                                                                           *
 *****************************************************************************/

double
mypow(double x, double y)
{
  double result;
  int i;

  if(y < 0)
  {
    fprintf(stderr,"Warning: got negative exponent in mypow!\n");
    return 0.0;
  }

  if(y == 0)
    return 1.0;

  if(y == 1)
    return x;
  
  result = x;

  for(i=0;i<y-1;i++)
    result *= x;
  
  return result;
}

/*****************************************************************************
 *                                                                           *
 * init_tables                                                               *
 *                                                                           *
 * This function initializes all the symbol tables we'll need during         *
 * parsing and code generation.                                              *
 *                                                                           *
 *****************************************************************************/

void
init_tables()
{
  if(debug)
    printf("Initializing tables.\n");

  initialize_implicit_table(implicit_table);
  array_table     = (SYMTABLE *) new_symtable(211);
  format_table    = (SYMTABLE *) new_symtable(211);
  data_table      = (SYMTABLE *) new_symtable(211);
  save_table      = (SYMTABLE *) new_symtable(211);
  common_table    = (SYMTABLE *) new_symtable(211);
  parameter_table = (SYMTABLE *) new_symtable(211);
  type_table      = (SYMTABLE *) new_symtable(211);
  intrinsic_table = (SYMTABLE *) new_symtable(211);
  external_table  = (SYMTABLE *) new_symtable(211);
  args_table      = (SYMTABLE *) new_symtable(211);
  constants_table = make_dl();
  equivList       = NULL;
  save_all        = FALSE;
}

/*****************************************************************************
 *                                                                           *
 * merge_common_blocks                                                       *
 *                                                                           *
 * In Fortran, different declarations of the same COMMON block may use       *
 * differently named variables.  Since f2j is going to generate only one     *
 * class file to represent the COMMON block, we can only use one of these    *
 * variable names.  What we attempt to do here is take the different names   *
 * and merge them into one name, which we use wherever that common variable  *
 * is used.                                                                  *
 *                                                                           *
 *****************************************************************************/

void
merge_common_blocks(AST *root)
{
  HASHNODE *ht;
  AST *Clist, *temp;
  int count;
  char ** name_array;
  char *comvar = NULL, *var, und_var[80], 
       var_und[80], und_var_und[80], *t;

  for(Clist = root; Clist != NULL; Clist = Clist->nextstmt)
  {
    /* 
     * First check whether this common block is already in
     * the table.
     */

    ht=type_lookup(common_block_table,Clist->astnode.common.name);

    for(temp=Clist->astnode.common.nlist, count = 0; 
              temp!=NULL; temp=temp->nextstmt) 
      count++;

    name_array = (char **) f2jalloc( count * sizeof(name_array) );

    /* foreach COMMON variable */

    for(temp=Clist->astnode.common.nlist, count = 0; 
               temp!=NULL; temp=temp->nextstmt, count++) 
    {
      var = temp->astnode.ident.name;

      /* to merge two names we concatenate the second name
       * to the first name, separated by an underscore.
       */

      if(ht != NULL) {
        comvar = ((char **)ht->variable)[count];
        und_var[0] = '_';
        und_var[1] = 0;
        strcat(und_var,var);
        strcpy(var_und,var);
        strcat(var_und,"_");
        strcpy(und_var_und,und_var);
        strcat(und_var_und,"_");
      }

      if(ht == NULL) {
        name_array[count] = (char *) f2jalloc( strlen(var) + 1 );
        strcpy(name_array[count], var);
      }
      else {
        if(!strcmp(var,comvar) || 
             strstr(comvar,und_var_und) ||
             (((t=strstr(comvar,var_und)) != NULL) && t == comvar) ||
             (((t=strstr(comvar,und_var)) != NULL) && 
               (t+strlen(t) == comvar+strlen(comvar))))
        {
          name_array[count] = (char *) f2jalloc( strlen(comvar) + 1 );
          strcpy(name_array[count], comvar);
        }
        else {
          name_array[count] = (char *) f2jalloc(strlen(temp->astnode.ident.name) 
             + strlen(((char **)ht->variable)[count]) + 2);
  
          strcpy(name_array[count],temp->astnode.ident.name);
          strcat(name_array[count],"_");
          strcat(name_array[count],((char **)ht->variable)[count]);
        }
      }
    }

    type_insert(common_block_table, (AST *)name_array, Float,
         Clist->astnode.common.name);
  }
}

/*****************************************************************************
 *                                                                           *
 * addEquiv                                                                  *
 *                                                                           *
 * Insert the given node (which is itself a list of variables) into a list   *
 * of equivalences.  We end up with a list of lists.                         *
 *                                                                           *
 *****************************************************************************/

void
addEquiv(AST *node)
{
  static int id = 1;

  /* if the list is NULL, create one */

  if(equivList == NULL) {
    equivList = addnode(); 
    equivList->nodetype = Equivalence;
    equivList->token = id++;
    equivList->nextstmt = NULL;
    equivList->prevstmt = NULL;
    equivList->astnode.equiv.clist = node;
  }
  else {
    AST *temp = addnode();

    temp->nodetype = Equivalence;
    temp->token = id++;
    temp->astnode.equiv.clist = node;

    temp->nextstmt = equivList; 
    temp->prevstmt = NULL;

    equivList = temp;
  }
}

/*****************************************************************************
 *                                                                           *
 * eval_const_expr                                                           *
 *                                                                           *
 * This function evaluates a floating-point expression which should consist  *
 * of only parameters and constants.  The floating-point result is returned. *
 *                                                                           *
 *****************************************************************************/

double
eval_const_expr(AST *root)
{
  HASHNODE *p;
  double result1, result2;

  if(root == NULL)
    return 0.0;

  switch (root->nodetype)
  {
    case Identifier:
      if(!strcmp(root->astnode.ident.name,"*"))
        return 0.0;

      p = type_lookup(parameter_table, root->astnode.ident.name);

      if(p)
      {
         if(p->variable->nodetype == Constant) {
           root->vartype = p->variable->vartype;
           return ( atof(p->variable->astnode.constant.number) );
         }
      }

      /* else p==NULL, then the array size is specified with a
       * variable, but we cant find it in the parameter table.
       * it is probably an argument to the function.  do nothing
       * here, just fall through and hit the 'return 0' below.  --keith
       */

      return 0.0;
      
    case Expression:
      if (root->astnode.expression.lhs != NULL)
        eval_const_expr (root->astnode.expression.lhs);

      result2 = eval_const_expr (root->astnode.expression.rhs);

      root->token = root->astnode.expression.rhs->token;

      root->vartype = root->astnode.expression.rhs->vartype;
      strcpy(root->astnode.constant.number,
          root->astnode.expression.rhs->astnode.constant.number);

      return (result2);
    
    case Power:
      result1 = eval_const_expr (root->astnode.expression.lhs);
      result2 = eval_const_expr (root->astnode.expression.rhs);
      root->vartype = MIN(root->astnode.expression.lhs->vartype,
                          root->astnode.expression.rhs->vartype);
      return( mypow(result1,result2) );
  
    case Binaryop:
      result1 = eval_const_expr (root->astnode.expression.lhs);
      result2 = eval_const_expr (root->astnode.expression.rhs);
      root->vartype = MIN(root->astnode.expression.lhs->vartype,
                          root->astnode.expression.rhs->vartype);
      if(root->astnode.expression.optype == '-')
        return (result1 - result2);
      else if(root->astnode.expression.optype == '+')
        return (result1 + result2);
      else if(root->astnode.expression.optype == '*')
        return (result1 * result2);
      else if(root->astnode.expression.optype == '/')
        return (result1 / result2);
      else
        fprintf(stderr,"eval_const_expr: Bad optype!\n");
      return 0.0;
      
    case Unaryop:
      root->vartype = root->astnode.expression.rhs->vartype;
     /*
      result1 = eval_const_expr (root->astnode.expression.rhs);
      if(root->astnode.expression.minus == '-')
        return -result1;
     */
      break;
    case Constant:
      if(debug)
        printf("### its a constant.. %s\n", root->astnode.constant.number);

      if(root->token == STRING) {
        if(!strcmp(root->astnode.ident.name,"*"))
          return 0.0;
        else
          fprintf (stderr, "String in array dec (%s)!\n",
            root->astnode.constant.number);
      }
      else
        return( atof(root->astnode.constant.number) );
      break;
    case ArrayIdxRange:
      /* I dont think it really matters what the type of this node is. --kgs */
      root->vartype = MIN(root->astnode.expression.lhs->vartype,
                          root->astnode.expression.rhs->vartype);
      return(  eval_const_expr(root->astnode.expression.rhs) - 
               eval_const_expr(root->astnode.expression.lhs) );
     
    case Logicalop:
      {
        int lhs=0, rhs;

        root->nodetype = Constant;
        root->vartype = Logical;

        eval_const_expr(root->astnode.expression.lhs);
        eval_const_expr(root->astnode.expression.rhs);

        if(root->token != NOT)
          lhs = root->astnode.expression.lhs->token == TrUE;
        rhs = root->astnode.expression.rhs->token == TrUE;

        switch (root->token) {
          case EQV:
            root->token = (lhs == rhs) ? TrUE : FaLSE;
            break;
          case NEQV:
            root->token = (lhs != rhs) ? TrUE : FaLSE;
            break;
          case AND:
            root->token = (lhs && rhs) ? TrUE : FaLSE;
            break;
          case OR:
            root->token = (lhs || rhs) ? TrUE : FaLSE;
            break;
          case NOT:
            root->token = (! rhs) ? TrUE : FaLSE;
            break;
        }
        strcpy(root->astnode.constant.number,root->token == TrUE ? "true" : "false");
        return (double)root->token;
      }
      
    default:
      fprintf(stderr,"eval_const_expr(): bad nodetype!\n");
      return 0.0;
  }
  return 0.0;
}

void
printbits(char *header, void *var, int datalen)
{
  int i;

  printf("%s: ", header);
  for(i=0;i<datalen;i++) {
      printf("%1x", ((unsigned char *)var)[i] >> 7 );
      printf("%1x", ((unsigned char *)var)[i] >> 6 & 1 );
      printf("%1x", ((unsigned char *)var)[i] >> 5 & 1 );
      printf("%1x", ((unsigned char *)var)[i] >> 4 & 1 );
      printf("%1x", ((unsigned char *)var)[i] >> 3 & 1 );
      printf("%1x", ((unsigned char *)var)[i] >> 2 & 1 );
      printf("%1x", ((unsigned char *)var)[i] >> 1 & 1 );
      printf("%1x", ((unsigned char *)var)[i] & 1 );
  }
  printf("\n");
}

/*****************************************************************************
 *                                                                           *
 * prepend_minus                                                             *
 *                                                                           *
 * This function accepts a string and prepends a '-' in front of it.         *
 * We assume that the string pointer passed in has enough storage space.     *
 *                                                                           *
 *****************************************************************************/

void
prepend_minus(char *num)
{
  char * tempstr;

  if( (tempstr = first_char_is_minus(num)) != NULL) {
    *tempstr = ' ';
    return;
  }

  /* allocate enough for the number, minus sign, and null char */
  tempstr = (char *)f2jalloc(strlen(num) + 5);

  strcpy(tempstr,"-");
  strcat(tempstr,num);
  strcpy(num,tempstr);

  free(tempstr);
}

/*****************************************************************************
 *                                                                           *
 * first_char_is_minus                                                       *
 *                                                                           *
 * Determines whether the number represented by this string is negative.     *
 * If negative, this function returns a pointer to the minus sign.  if non-  *
 * negative, returns NULL.                                                   *
 *                                                                           *
 *****************************************************************************/

char *
first_char_is_minus(char *num)
{
  char *ptr = num;

  while( *ptr ) {
    if( *ptr == '-' )
      return ptr;
    ptr++;
  }

  return NULL;
}

/*****************************************************************************
 *                                                                           *
 * gen_incr_expr                                                             *
 *                                                                           *
 * this function creates an AST sub-tree representing a calculation of the   *
 * increment for this loop.  for null increments, add one.  for non-null     *
 * increments, add the appropriate value.
 *                                                                           *
 *****************************************************************************/

AST *
gen_incr_expr(AST *counter, AST *incr)
{
  AST *plus_node, *const_node, *assign_node, *lhs_copy, *rhs_copy, *incr_copy;

  lhs_copy = addnode();
  memcpy(lhs_copy, counter, sizeof(AST));
  rhs_copy = addnode();
  memcpy(rhs_copy, counter, sizeof(AST));

  if(incr == NULL) {
    const_node = addnode();
    const_node->token = INTEGER;
    const_node->nodetype = Constant;
    strcpy(const_node->astnode.constant.number, "1");
    const_node->vartype = Integer;

    plus_node = addnode();
    plus_node->token = PLUS;
    rhs_copy->parent = plus_node;
    const_node->parent = plus_node;
    plus_node->astnode.expression.lhs = rhs_copy;
    plus_node->astnode.expression.rhs = const_node;
    plus_node->nodetype = Binaryop;
    plus_node->astnode.expression.optype = '+';
  }
  else {
    incr_copy = addnode();
    memcpy(incr_copy, incr, sizeof(AST));

    plus_node = addnode();
    plus_node->token = PLUS;
    rhs_copy->parent = plus_node;
    incr_copy->parent = plus_node;
    plus_node->astnode.expression.lhs = rhs_copy;
    plus_node->astnode.expression.rhs = incr_copy;
    plus_node->nodetype = Binaryop;
    plus_node->astnode.expression.optype = '+';
  }

  assign_node = addnode();
  assign_node->nodetype = Assignment;
  lhs_copy->parent = assign_node;
  plus_node->parent = assign_node;
  assign_node->astnode.assignment.lhs = lhs_copy;
  assign_node->astnode.assignment.rhs = plus_node;

  return assign_node;
}

/*****************************************************************************
 *                                                                           *
 * gen_iter_expr                                                             *
 *                                                                           *
 * this function creates an AST sub-tree representing a calculation of the   *
 * number of iterations of a DO loop:                                        *
 *     (stop-start+incr)/incr                                                *
 * the full expression is MAX(INT((stop-start+incr)/incr),0) but we will     *
 * worry about the rest of it at code generation time.                       *
 *                                                                           *
 *****************************************************************************/

AST *
gen_iter_expr(AST *start, AST *stop, AST *incr)
{
  AST *minus_node, *plus_node, *div_node, *expr_node, *incr_node;
  
  minus_node = addnode();
  minus_node->token = MINUS;
  minus_node->astnode.expression.lhs = stop;
  minus_node->astnode.expression.rhs = start;
  minus_node->nodetype = Binaryop;
  minus_node->astnode.expression.optype = '-';
  
  if(incr == NULL) {
    incr_node = addnode();
    incr_node->token = INTEGER;
    incr_node->nodetype = Constant;
    strcpy(incr_node->astnode.constant.number, "1");
    incr_node->vartype = Integer;
  }
  else 
    incr_node = incr;
  
  plus_node = addnode();
  plus_node->token = PLUS;
  plus_node->astnode.expression.lhs = minus_node;
  plus_node->astnode.expression.rhs = incr_node;
  plus_node->nodetype = Binaryop;
  plus_node->astnode.expression.optype = '+';

  if(incr == NULL)
    return plus_node;
    
  expr_node = addnode();
  expr_node->nodetype = Expression;
  expr_node->astnode.expression.parens = TRUE;
  expr_node->astnode.expression.rhs = plus_node;
  expr_node->astnode.expression.lhs = NULL;

  div_node = addnode();
  div_node->token = DIV;
  div_node->astnode.expression.lhs = expr_node;
  div_node->astnode.expression.rhs = incr_node;
  div_node->nodetype = Binaryop;
  div_node->astnode.expression.optype = '/';

  return div_node;
}

/*****************************************************************************
 *                                                                           *
 * initialize_name                                                           *
 *                                                                           *
 * this function initializes an Identifier node with the given name.         *
 *                                                                           *
 *****************************************************************************/

AST *
initialize_name(char *id)
{
  HASHNODE *hashtemp;
  AST *tmp;

  tmp=addnode();
  tmp->token = NAME;
  tmp->nodetype = Identifier;

  tmp->astnode.ident.needs_declaration = FALSE;

  if(omitWrappers)
    tmp->astnode.ident.passByRef = FALSE;

  if(type_lookup(java_keyword_table,id) ||
     type_lookup(jasmin_keyword_table,id))
        id[0] = toupper(id[0]);

  strcpy(tmp->astnode.ident.name, id);

  if(type_table) {
    hashtemp = type_lookup(type_table, tmp->astnode.ident.name);
    if(hashtemp)
    {
      tmp->vartype = hashtemp->variable->vartype;
      tmp->astnode.ident.len = hashtemp->variable->astnode.ident.len;
    }
    else
    {
      enum returntype ret;
  
printf("cannot find name %s in hash table..",id);
      
      ret = implicit_table[tolower(id[0]) - 'a'].type;
  
printf("going to insert with default implicit type %s\n",
 returnstring[ret]);
  
      type_insert(type_table, tmp, ret, tmp->astnode.ident.name);
    }
  }

  return tmp;
}
             
/*****************************************************************************
 *                                                                           *
 * insert_name                                                               *
 *                                                                           *
 * this function inserts the given node into the symbol table, if it is not  *
 * already there.                                                            *
 *                                                                           *
 *****************************************************************************/

void
insert_name(SYMTABLE * tt, AST *node, enum returntype ret)
{
  HASHNODE *hash_entry;
  
  hash_entry = type_lookup(tt,node->astnode.ident.name);

  if(hash_entry == NULL)
    node->vartype = ret;
  else
    node->vartype = hash_entry->variable->vartype;

  type_insert(tt, node, node->vartype, node->astnode.ident.name);
}


/*****************************************************************************
 *                                                                           *
 * initialize_implicit_table                                                 *
 *                                                                           *
 * this function the implicit table, which indicates the implicit typing for *
 * the current program unit (i.e. which letters correspond to which data     *
 * type).       .                                                            *
 *                                                                           *
 *****************************************************************************/

void
initialize_implicit_table(ITAB_ENTRY *itab)
{
  int i;

  /* first initialize everything to double */
  for(i = 0; i < 26; i++) {
    itab[i].type = Double;
    itab[i].declared = FALSE;
  }

  /* then change 'i' through 'n' to Integer */
  for(i = 'i' - 'a'; i <= 'n' - 'a'; i++)
    itab[i].type = Integer;
}
