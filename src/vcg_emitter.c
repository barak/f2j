/*  vcg_emiiter.c
   Emits a graph representing the syntax tree for the
   fortran program.  The file is compatible with the
   VCG tool (Visualization of Compiler Graphs).
 */

#include<stdio.h>
#include<string.h>
#include<ctype.h>
#include"f2j.h"
#include"f2jparse.tab.h"

char *strdup(const char *);

char *progname;
char *returnname;
char temp_buf[200];

void emit_vcg(AST *,int);
void vcg_elseif_emit(AST *,int);
void vcg_else_emit(AST *,int);

extern char *returnstring[];

int node_num = 1;

int vcg_debug = 0;

void start_vcg(AST *root)
{
  /* print header information */

  fprintf(vcgfp,"graph: { title: \"SYNTAXTREE\"\n");

  fprintf(vcgfp,"x: 30\n");
  fprintf(vcgfp,"y: 30\n");
  fprintf(vcgfp,"width:  850\n");
  fprintf(vcgfp,"height: 800\n");
  fprintf(vcgfp,"color: lightcyan\n");

  fprintf(vcgfp,"stretch: 4\n");
  fprintf(vcgfp,"shrink: 10\n");
  fprintf(vcgfp,"layout_upfactor: 10\n");
  fprintf(vcgfp,"manhatten_edges: yes\n");
  fprintf(vcgfp,"smanhatten_edges: yes\n");
  fprintf(vcgfp,"layoutalgorithm: tree\n\n");

  fprintf(vcgfp,"node: {color: black textcolor: white title:\"0\"\n");
  fprintf(vcgfp,"label: \"Nothing should hang here\"\n");
  fprintf(vcgfp,"}\n\n");

  emit_vcg(root, 0);

  fprintf(vcgfp,"}\n");
}
  
void print_vcg_node(int num, char *label)
{
  if(vcg_debug)
    printf("creating node \"%s\"\n",label);

  fprintf(vcgfp,
    "node: {color: black textcolor: white title:\"%d\"\n",num);

  fprintf(vcgfp,
    "label: \"%s\"\n",label);

  fprintf(vcgfp,
    "}\n\n");

  node_num++;
}

void print_vcg_typenode(int num, char *label)
{
  if(vcg_debug)
    printf("creating typenode \"%s\"\n",label);

  fprintf(vcgfp, "node: { title: \"%d\"\n",num);
  fprintf(vcgfp, " label: \"%s\"\n",label);
  fprintf(vcgfp, "}\n\n");

  node_num++;
}

void print_vcg_edge(int source, int dest)
{
  fprintf(vcgfp,
    "edge: { thickness: 6 color: red sourcename: \"%d\" targetname: \"%d\"}\n\n",
    source, dest);
}

void print_vcg_nearedge(int source, int dest)
{
  fprintf(vcgfp,"nearedge: { sourcename: \"%d\" targetname: \"%d\"\n",
      source, dest);
  fprintf(vcgfp,"color: blue thickness: 6\n}\n\n");
}

void
emit_vcg (AST * root, int parent)
{
  int my_node = node_num;
  void vcg_typedec_emit (AST *, int);
  void vcg_spec_emit (AST *, int);
  void vcg_assign_emit (AST *, int);
  void vcg_call_emit (AST *, int);
  void vcg_forloop_emit (AST *, int);
  void vcg_blockif_emit (AST *, int);
  void vcg_logicalif_emit (AST *, int);
  void vcg_label_emit (AST *, int);

    switch (root->nodetype)
      {
      case 0:
	  fprintf(stderr,"Bad node in emit_vcg()\n");
	  emit_vcg (root->nextstmt,node_num);
      case Progunit:
          if(vcg_debug)
            printf("case Source\n");
          print_vcg_node(node_num,"Progunit");

          if(vcg_debug)
            printf("case Source: Going to emit PROGTYPE\n");
	  emit_vcg (root->astnode.source.progtype, my_node);

          if(vcg_debug)
            printf("case Source: Going to emit TYPEDECS\n");
	  emit_vcg (root->astnode.source.typedecs, my_node);

          if(vcg_debug)
            printf("case Source: Going to emit STATEMENTS\n");
	  emit_vcg (root->astnode.source.statements, my_node);

	  break;
      case Subroutine:
          if(vcg_debug)
            printf("case Subroutine\n");

          print_vcg_node(node_num,"Subroutine");
          print_vcg_edge(parent, my_node);

	  returnname = NULL;	/* Subroutines return void. */
	  break;
      case Function:
          if(vcg_debug)
            printf("case Function\n");

	  sprintf (temp_buf,"Function: %s\n", 
             root->astnode.source.name->astnode.ident.name);
          print_vcg_node(node_num,temp_buf);
          print_vcg_edge(parent, my_node);
	  returnname = root->astnode.source.name->astnode.ident.name;
	  break;
      case Typedec:
          if(vcg_debug)
            printf("case Typedec\n");

	  vcg_typedec_emit (root, parent);
	  if (root->nextstmt != NULL)	/* End of typestmt list. */
	      emit_vcg (root->nextstmt, my_node);
	  break;
      case Specification:
          if(vcg_debug)
            printf("case Specification\n");

	  vcg_spec_emit (root, parent);
	  if (root->nextstmt != NULL)	/* End of typestmt list. */
	      emit_vcg (root->nextstmt, my_node);
	  break;
      case Statement:
          if(vcg_debug)
            printf("case Statement\n");

          print_vcg_node(node_num,"Statement");
          print_vcg_edge(parent, my_node);
	  if (root->nextstmt != NULL)	/* End of typestmt list. */
	      emit_vcg (root->nextstmt, my_node);
	  break;

      case Assignment:
          print_vcg_node(node_num,"Assignment");
          print_vcg_edge(parent, my_node);
	  vcg_assign_emit (root, my_node);
	  if (root->nextstmt != NULL)
	      emit_vcg (root->nextstmt, my_node);
	  break;
      case Call:
	  vcg_call_emit (root, parent);
	  if (root->nextstmt != NULL)	/* End of typestmt list. */
	      emit_vcg (root->nextstmt, my_node);
	  break;
      case Forloop:
          print_vcg_node(node_num,"For loop");
          print_vcg_edge(parent, my_node);
	  vcg_forloop_emit (root, my_node);
	  if (root->nextstmt != NULL)	/* End of typestmt list. */
	      emit_vcg (root->nextstmt, my_node);
	  break;

      case Blockif:
          print_vcg_node(node_num,"Block if");
          print_vcg_edge(parent, my_node);
	  vcg_blockif_emit (root, my_node);
	  if (root->nextstmt != NULL)	/* End of typestmt list. */
	      emit_vcg (root->nextstmt, my_node);
	  break;
      case Elseif:
          print_vcg_node(node_num,"Else if");
          print_vcg_edge(parent, my_node);
	  vcg_elseif_emit (root, my_node);
	  if (root->nextstmt != NULL)	/* End of typestmt list. */
	      emit_vcg (root->nextstmt, my_node);
	  break;
      case Else:
          print_vcg_node(node_num,"Else");
          print_vcg_edge(parent, my_node);
	  vcg_else_emit (root, my_node);
	  if (root->nextstmt != NULL)	/* End of typestmt list. */
	      emit_vcg (root->nextstmt, my_node);
	  break;
      case Logicalif:
          print_vcg_node(node_num,"Logical If");
          print_vcg_edge(parent, my_node);
	  vcg_logicalif_emit (root, my_node);
	  if (root->nextstmt != NULL)	/* End of typestmt list. */
	      emit_vcg (root->nextstmt, my_node);
	  break;
      case Return:
	  if (returnname != NULL)
	      sprintf (temp_buf, "Return (%s)", returnname);
	  else
	      sprintf (temp_buf, "Return");

          print_vcg_node(node_num,temp_buf);
          print_vcg_edge(parent, my_node);

	  if (root->nextstmt != NULL)	/* End of typestmt list. */
	      emit_vcg (root->nextstmt, my_node);
	  break;
      case Goto:
          sprintf (temp_buf,"Goto (%d)", root->astnode.go_to.label);
          print_vcg_node(node_num,temp_buf);
          print_vcg_edge(parent, my_node);

	  if (root->nextstmt != NULL)
	    emit_vcg (root->nextstmt, my_node);
	  break;

      case Label:
	  vcg_label_emit (root, parent);
	  if (root->nextstmt != NULL)	/* End of typestmt list. */
	      emit_vcg (root->nextstmt, my_node);
	  break;
      case End:
          print_vcg_node(node_num,"End");
          print_vcg_edge(parent, my_node);
          /* end of the program */
	  break;
      case Unimplemented:
          print_vcg_node(node_num,"UNIMPLEMENTED");
          print_vcg_edge(parent, my_node);

	  if (root->nextstmt != NULL)
	      emit_vcg (root->nextstmt, my_node);
	  break;
      case Constant:
          sprintf(temp_buf,"Constant(%s)",
             root->astnode.constant.number);

          print_vcg_node(node_num,temp_buf);
          print_vcg_edge(parent, my_node);
      default:
	  fprintf (stderr,"vcg_emitter: Default case reached!\n");
      }				/* switch on nodetype.  */
}

/* Emit all the type declarations.  This procedure checks
   whether variables are typed in the argument list, and
   does not redeclare thoose arguments. */
void
vcg_typedec_emit (AST * root, int parent)
{
  AST *temp;
  HASHNODE *hashtemp;
  enum returntype returns;
  int my_node = node_num;
  int name_nodenum = 0;
  int prev_node = 0;
  int vcg_name_emit (AST *, int);

  if(vcg_debug)
    printf("in vcg_typedec_emit\n");

  temp = root->astnode.typeunit.declist;

  /* This may have to be moved into the looop also.  Could be
     why I have had problems with this stuff.  */

  hashtemp = type_lookup (external_table, temp->astnode.ident.name);

  if (hashtemp) {
    if(vcg_debug) {
      printf("returning from vcg_typedec_emit,");
      printf(" found something in hash table\n");
    }
    print_vcg_node(node_num,"External");
    print_vcg_edge(parent, my_node);
    return;
  } 

  returns = root->astnode.typeunit.returns;

  sprintf(temp_buf,"TypeDec (%s)", returnstring[returns]);
  print_vcg_node(node_num,temp_buf);
  print_vcg_edge(parent, my_node);

  prev_node = my_node;

  for (; temp != NULL; temp = temp->nextstmt) {
    if(vcg_debug)
      printf("in the loop\n");
    name_nodenum = vcg_name_emit (temp, parent);
    print_vcg_nearedge(prev_node,name_nodenum);
    prev_node = name_nodenum;
  }
  if(vcg_debug)
    printf("leaving vcg_typdec_emit\n");
}

int
vcg_name_emit (AST * root, int parent)
{
  AST *temp;
  HASHNODE *hashtemp;
  char *javaname, * tempname;
  extern METHODTAB intrinsic_toks[];
  extern SYMTABLE *array_table;
  int my_node = node_num;
  int temp_num;
  void vcg_call_emit (AST *, int);
  char *methodscan (METHODTAB *, char *);
  void vcg_expr_emit (AST *, int);

  if(vcg_debug)
    printf("in vcg_name_emit\n");

  sprintf(temp_buf,"Name (%s)",root->astnode.ident.name);
  print_vcg_node(my_node,temp_buf);

  /*  Check to see whether name is in external table.  Names are
     loaded into the external table from the parser.   */

  hashtemp = type_lookup (external_table, root->astnode.ident.name);

  /* If the name is in the external table, then check to see if
     is an intrinsic function instead.  */

  if (hashtemp != NULL) {
    javaname = (char *) methodscan (intrinsic_toks, root->astnode.ident.name);

    /*  This block of code is only called if the identifier
        absolutely does not have an entry in any table,
        and corresponds to a method invocation of
        something in the blas or lapack packages.  */

    if (javaname == NULL) {
      if (root->astnode.ident.arraylist != NULL) {
        vcg_call_emit (root, my_node);
        return my_node;
      }
      return my_node;
    }

    if (root->astnode.ident.arraylist != NULL) {
      if (!strcmp (root->astnode.ident.name, "LSAME")) {
        temp = root->astnode.ident.arraylist;
        temp_num = vcg_name_emit (temp->nextstmt, my_node);
        print_vcg_edge(my_node,temp_num);
        return my_node;
       }
    }
  }

  tempname = strdup(root->astnode.ident.name);
  uppercase(tempname);

  if(vcg_debug)
    printf ("Tempname  %s\n", tempname);

  javaname = (char *) methodscan (intrinsic_toks, tempname);
	  
  if (javaname != NULL) {
    if (!strcmp (root->astnode.ident.name, "MAX")) {
      temp = root->astnode.ident.arraylist;

      vcg_expr_emit (temp, my_node);
      vcg_expr_emit (temp->nextstmt, my_node);
      return my_node;
    }

    if (!strcmp (root->astnode.ident.name, "MIN")) {
      temp = root->astnode.ident.arraylist;
      vcg_expr_emit (temp, my_node);
      vcg_expr_emit (temp->nextstmt, my_node);
      return my_node;
    }

    if (!strcmp (root->astnode.ident.name, "ABS")) {
      temp = root->astnode.ident.arraylist;
      vcg_expr_emit (temp, my_node);
      return my_node;
    }

    if (!strcmp (tempname, "DABS")) {
      temp = root->astnode.ident.arraylist;
      vcg_expr_emit (temp, my_node);
      return my_node;
    }

    if (!strcmp (tempname, "DSQRT")) {
      temp = root->astnode.ident.arraylist;
      vcg_expr_emit (temp, my_node);
      return my_node;
    }
  }

  hashtemp = type_lookup (array_table, root->astnode.ident.name);

  switch (root->token)
  {
    case STRING:
      /*fprintf (javafp, "\"%s\"", root->astnode.ident.name); */
      break;

    case CHAR:
      /*fprintf (javafp, "\"%s\"", root->astnode.ident.name); */
      break;

    case NAME:

    default:
      /* At some point in here I will have to switch on the
         token type check whether it is a variable or
         string or character literal. Also have to look up whether
         name is intrinsic or external.  */

      if (root->astnode.ident.arraylist == NULL) {
        /* null */   ;
        /* fprintf (javafp, "%s", root->astnode.ident.name); */
      }
      else if (hashtemp != NULL) {
        if(vcg_debug)
          printf ("Array... %s\n", root->astnode.ident.name);

        temp = root->astnode.ident.arraylist;

        /* Now, what needs to happen here is the context of the
           array needs to be determined.  If the array is being
           passed as a parameter to a method, then the array index
           needs to be passed separately and the array passed as
           itself.  If not, then an array value is being set,
           so dereference with index arithmetic.  */

        /*fprintf (javafp, "["); */

        vcg_expr_emit (temp, my_node);

        if (hashtemp->variable->astnode.ident.leaddim[0] != '*' &&
                 temp->nextstmt != NULL) {
          temp = temp->nextstmt;

          /*fprintf (javafp, "+"); */

          vcg_expr_emit (temp, my_node);

          /*
            fprintf (javafp, "*"); 
            fprintf(javafp,  "%s", hashtemp->variable->astnode.ident.leaddim);
          */
        }
        /*fprintf(javafp, "]"); */
      }
      else {
        /*fprintf (javafp, "%s", root->astnode.ident.name); */
        temp = root->astnode.ident.arraylist;

        for (; temp != NULL; temp = temp->nextstmt) {
          /*fprintf (javafp, "["); */

          if (*temp->astnode.ident.name != '*')
            vcg_expr_emit (temp, my_node);

          /*fprintf (javafp, "]"); */
        }
      }
    break;
  }
  return my_node;
}

void
vcg_expr_emit (AST * root, int parent)
{
   int my_node = node_num;
   int temp_num;

    switch (root->nodetype)
      {
      case Identifier:
          print_vcg_node(my_node,"Ident");
          print_vcg_edge(parent,my_node);
	  temp_num = vcg_name_emit (root, my_node);
          print_vcg_edge(my_node,temp_num);
	  break;
      case Expression:
	  if (root->astnode.expression.lhs != NULL)
	      vcg_expr_emit (root->astnode.expression.lhs, parent);
	  vcg_expr_emit (root->astnode.expression.rhs, parent);
	  break;
      case Power:
          print_vcg_node(my_node,"pow()");
          print_vcg_edge(parent,my_node);

	  vcg_expr_emit (root->astnode.expression.lhs, my_node);
	  vcg_expr_emit (root->astnode.expression.rhs, my_node);
	  break;
      case Binaryop:
          sprintf(temp_buf,"%c", root->astnode.expression.optype);
          print_vcg_node(my_node,temp_buf);
          print_vcg_edge(parent,my_node);

	  vcg_expr_emit (root->astnode.expression.lhs, my_node);
	  vcg_expr_emit (root->astnode.expression.rhs, my_node);
	  break;
      case Unaryop:
          sprintf(temp_buf,"%c", root->astnode.expression.minus);
          print_vcg_node(my_node,temp_buf);
          print_vcg_edge(parent,my_node);

	  vcg_expr_emit (root->astnode.expression.rhs, my_node);
	  break;
      case Constant:
          sprintf(temp_buf,"Constant(%s)",
             root->astnode.constant.number);

          print_vcg_node(node_num,temp_buf);
          print_vcg_edge(parent, my_node);
	  break;
      case Logicalop:
          if(root->token == AND)
            print_vcg_node(my_node,"AND");
          else if(root->token == OR)
            print_vcg_node(my_node,"OR");
           
	  if (root->astnode.expression.lhs == NULL)
            print_vcg_node(my_node,"NOT");

          print_vcg_edge(parent,my_node);

	  if (root->astnode.expression.lhs != NULL)
	    vcg_expr_emit (root->astnode.expression.lhs, my_node);

	  vcg_expr_emit (root->astnode.expression.rhs, my_node);
	  break;
      case Relationalop:
	  switch (root->token)
	    {
	    case rel_eq:
                print_vcg_node(my_node,"==");
		break;
	    case rel_ne:
                print_vcg_node(my_node,"!=");
		break;
	    case rel_lt:
                print_vcg_node(my_node,"<");
		break;
	    case rel_le:
                print_vcg_node(my_node,"<=");
		break;
	    case rel_gt:
                print_vcg_node(my_node,">");
		break;
	    case rel_ge:
                print_vcg_node(my_node,">=");
		break;
	    default:
                print_vcg_node(my_node,"Unknown RelationalOp");
             }
          print_vcg_edge(parent,my_node);

	  vcg_expr_emit (root->astnode.expression.lhs, my_node);
	  vcg_expr_emit (root->astnode.expression.rhs, my_node);
	  break;
      default:
          fprintf(stderr,"vcg_emitter: Bad node in vcg_expr_emit\n");
      }
}

void
vcg_forloop_emit (AST * root, int parent)
{
  void vcg_assign_emit (AST *, int);
  void vcg_expr_emit (AST *, int);

  vcg_assign_emit (root->astnode.forloop.start, parent);
  vcg_expr_emit (root->astnode.forloop.stop, parent);

  if (root->astnode.forloop.incr != NULL) {
    vcg_expr_emit (root->astnode.forloop.incr, parent);
  }

/*  emit_vcg (root->astnode.forloop.stmts, parent); */
}

void
vcg_logicalif_emit (AST * root, int parent)
{
  void vcg_expr_emit (AST *, int);

  if (root->astnode.logicalif.conds != NULL)
    vcg_expr_emit (root->astnode.logicalif.conds, parent);

  emit_vcg (root->astnode.logicalif.stmts,parent);
}

void
vcg_label_emit (AST * root, int parent)
{
  int my_node = node_num;

  sprintf(temp_buf,"Label (%d)",root->astnode.label.number);

  print_vcg_node(node_num,temp_buf);
  print_vcg_edge(parent, my_node);

  if (root->astnode.label.stmt != NULL)
    emit_vcg (root->astnode.label.stmt,my_node);
}

void
vcg_blockif_emit (AST * root, int parent)
{
  void vcg_expr_emit (AST *, int);

  if (root->astnode.blockif.conds != NULL)
    vcg_expr_emit (root->astnode.blockif.conds, parent);

  emit_vcg (root->astnode.blockif.stmts,parent);

  if (root->astnode.blockif.elseifstmts != NULL)
    emit_vcg (root->astnode.blockif.elseifstmts,parent);

  if (root->astnode.blockif.elsestmts != NULL)
    emit_vcg (root->astnode.blockif.elsestmts,parent);
}

void
vcg_elseif_emit (AST * root, int parent)
{
  void vcg_expr_emit (AST *, int);

  if (root->astnode.blockif.conds != NULL)
    vcg_expr_emit (root->astnode.blockif.conds, parent);

  emit_vcg (root->astnode.blockif.stmts,parent);
}

void
vcg_else_emit (AST * root, int parent)
{
  emit_vcg (root->astnode.blockif.stmts,parent);
}

/* This procedure implements Lapack and Blas type methods.
   They are translated to static method invocations.
   This is not a portable solution, it is specific to
   the Blas and Lapack. */
void
vcg_call_emit (AST * root, int parent)
{
    AST *temp;
    char *tempname;
    int my_node = node_num;
    void vcg_expr_emit (AST *, int);
    char * lowercase ( char * );

    assert (root != NULL);

    lowercase (root->astnode.ident.name);
    tempname = strdup (root->astnode.ident.name);
    *tempname = toupper (*tempname);

    sprintf(temp_buf,"Call (%s)",root->astnode.ident.name);
    print_vcg_node(node_num,temp_buf);
    print_vcg_edge(parent, my_node);

    /* Assume all methods that are invoked are static.  */
    /* fprintf (javafp, "%s.%s", tempname, root->astnode.ident.name); */

    assert (root->astnode.ident.arraylist != NULL);

    temp = root->astnode.ident.arraylist;

    /* fprintf (javafp, "("); */

    while (temp->nextstmt != NULL) {
      vcg_expr_emit (temp, parent);
      /* fprintf (javafp, ","); */
      temp = temp->nextstmt;
    }

    vcg_expr_emit (temp, parent);
}

void
vcg_spec_emit (AST * root, int parent)
{
    AST *assigntemp;
    int my_node = node_num;
    int temp_num;
    void vcg_assign_emit (AST *, int);

    if(vcg_debug)
      printf("in vcg_spec_emit, my_node = %d, parent = %d\n",
        my_node,parent);

    print_vcg_node(node_num,"Specification");
    print_vcg_edge(parent, my_node);

    /* I am reaching every case in this switch.  */
    switch (root->astnode.typeunit.specification)
      {
	  /* PARAMETER in fortran corresponds to a class
	     constant in java, that has to be declared
	     class wide outside of any method.  This is
	     currently not implemented, but the assignment
	     is made.  */
      case Parameter:
/*	  fprintf (javafp, "// Assignment from Fortran PARAMETER specification.\n"); */
	  assigntemp = root->astnode.typeunit.declist;
	  for (; assigntemp; assigntemp = assigntemp->nextstmt)
	    {
		/*  fprintf (javafp, "public static final "); */
		vcg_assign_emit (assigntemp, parent);
/*		fprintf (javafp, ";\n"); */
	    }
	  break;

	  /*  I am reaching these next two cases. Intrinsic, for
	     example handles stuff like Math.max, etc. */
      case Intrinsic:
	  temp_num = vcg_name_emit (root, parent);
          print_vcg_edge(my_node, temp_num);
	  break;
      case External:
	  /*        printf ("External stmt.\n");   */
	  break;
      case Implicit:
          /* do nothing */
          break;
      }
}

void
vcg_assign_emit (AST * root, int parent)
{
  int temp_num;
  void vcg_expr_emit (AST *, int);

  temp_num = vcg_name_emit (root->astnode.assignment.lhs, parent);
  print_vcg_edge(parent,temp_num);
  vcg_expr_emit (root->astnode.assignment.rhs, parent);
}
