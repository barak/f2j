/*
 * $Source$
 * $Revision$
 * $Date$
 * $Author$
 */

extern int
  lineno,                  /* current line number                            */
  statementno,             /* current statement number                       */
  func_stmt_num,           /* current statement number within this function  */
  ignored_formatting,      /* number of format statements ignored            */
  bad_format_count;        /* number of invalid format stmts encountered     */

extern FILE 
  *ifp,                    /* input file pointer                             */
  *vcgfp,                  /* VCG output file pointer                        */
  *indexfp;                /* method and descriptor index for all prog units */

extern char 
  *inputfilename,          /* name of the input file                         */
  *package_name,           /* what to name the package, e.g. org.netlib.blas */
  *output_dir,             /* path to which f2java should store class files  */
  *comment_buffer[],       /* holds comments found between continued stmts   */
  line_buffer[];           /* copy of the fortran line                       */

extern BOOL 
  gendebug,                /* flag for debugging output from code generator  */
  lexdebug,                /* flag for debugging output from lexical analyzer*/
  optdebug,                /* flag for debugging output from 'optimizer'     */
  symdebug,                /* flag for debugging output from symbol table    */
  checkdebug,              /* flag for debugging output from type checker    */
  debug,                   /* flag for debugging output from parser          */
  vcg_debug,               /* flag for debugging output from VCG emitter     */
  strictFp,                /* should we declare generated code as strictfp   */
  strictMath,              /* should we use Java's strict fp math mode       */
  omitWrappers,            /* should we try to optimize use of wrappers      */
  genInterfaces,           /* should we generate simplified interfaces       */
  genJavadoc,              /* should we generate javadoc-compatible comments */
  noOffset,                /* should we generate offset args in interfaces   */
  f2j_arrays_static,       /* force all arrays to be declared static         */
  save_all_override;       /* force all variables to be declared static      */

extern SYMTABLE 
  *type_table,             /* General symbol table                           */
  *external_table,         /* external functions                             */
  *intrinsic_table,        /* intrinsic functions                            */
  *args_table,             /* arguments to the current unit                  */
  *array_table,            /* array variables                                */
  *format_table,           /* format statements                              */
  *data_table,             /* variables contained in DATA statements         */
  *save_table,             /* variables contained in SAVE statements         */
  *common_table,           /* variables contained in COMMON statements       */
  *parameter_table,        /* PARAMETER variables                            */
  *function_table,         /* table of functions                             */
  *stmt_func_table,        /* table of 'statement function' declarations     */
  *java_keyword_table,     /* table of Java reserved words                   */
  *common_block_table,     /* COMMON blocks                                  */
  *global_func_table,      /* Global function table                          */
  *global_common_table,    /* Global COMMON table                            */
  *generic_table;          /* table of the generic intrinsic functions       */

extern Dlist
  constants_table,         /* constants (for bytecode constant pool gen.)    */
  include_paths,           /* list of paths to search for included files     */
  descriptor_table;        /* list of method descriptors from *.f2j files    */

extern INCLUDED_FILE
  *current_file_info;      /* lexer information about the current file       */

#ifdef _WIN32
#define FILE_DELIM "\\"
#define PATH_DELIM ";"
#else
#define FILE_DELIM "/"
#define PATH_DELIM ":"
#endif
