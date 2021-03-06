
/* *************
   *** JAVAB ***
   ****************************************************
   *** Copyright (c) 1997                           ***
   *** Aart J.C. Bik             Indiana University *** 
   *** All Rights Reserved                          ***
   ****************************************************
   *** Please refer to the LICENSE file distributed ***
   *** with this software for further details on    ***
   *** the licensing terms and conditions.          ***
   ***                                              ***
   *** Please, report all bugs, comments, etc.      ***
   *** to: ajcbik@extreme.indiana.edu               ***
   ****************************************************
   *** dump.c : output to class file
   ***
   ***
   *** Your courtesy in mentioning the use of this bytecode tool
   *** in any scientific work that presents results obtained
   *** by using (extensions or modifications of) the tool
   *** is highly appreciated.
   ***
   *** */

/* ********************************************************
   *** INCLUDE FILES and DEFINITIONS                    ***
   ********************************************************  */

#include <stdarg.h>
#include "class.h"

/* ********************************************************
   *** EXTERNAL VARIABLES                               ***
   ******************************************************** */

/* PRIVATE
   ******* */

static FILE *dumpfile;

/* ********************************************************
   *** PRIVATE FUNCTIONS                                ***
   ******************************************************** */

/* write u1_int, u2_int, and u4_int routines
   **************************************** */

static void write_u1(u1_int u) {
  fputc(u, dumpfile);
}

static void write_u2(u2_int u) {
  u1_int u1 = HIGB_U2(u);
  u1_int u2 = LOWB_U2(u);

  fputc(u1, dumpfile);
  fputc(u2, dumpfile);
}

static void write_u4(u4_int u) {
  u1_int u1 = HIGB_U4(u); 
  u1_int u2 = LOWB_U4(u);
  u1_int u3 = HIGB_U2(u);
  u1_int u4 = LOWB_U2(u);

  fputc(u1, dumpfile);
  fputc(u2, dumpfile);
  fputc(u3, dumpfile);
  fputc(u4, dumpfile);
}

/* **********************************************************
   *** Output of the different components of a class file ***
   ********************************************************** */

/* output of attribute information
   ******************************* */

static void dump_attributes(u2_int cnt, attribute_ptr *a) {
  
  u4_int i, j; /* wide counters */

  write_u2(cnt);

  if (cnt != 0u) {

    if (! a)
      javab_out(-1, "lost attributes in dump_attributes()");

    for (i = 0u; i < cnt; i++) {

      if ((! a[i]) || (! a[i] -> info))
        javab_out(-1, "lost attribute entry in dump_attributes()");
      else {  
    
         u2_int  ind  = a[i] -> attribute_name_index;
         u4_int  len  = a[i] -> attribute_length;
         u1_int *info = a[i] -> info;

         write_u2(ind);
         write_u4(len);

         for (j = 0u; j < len; j++) 
           write_u1(info[j]);
      }
    }
  }
}

/* output of constant pool information 
   *********************************** */

static void dump_constant_pool(void) {

  u4_int i, j; /* wide counters */

  write_u2(constant_pool_count);

  if ((constant_pool_count == 0u) || (! constant_pool))
    javab_out(-1, "lost constant pool in dump_cpool()");

  for (i = 1u; i < constant_pool_count; i++) {

    constant_ptr ce = constant_pool[i];
  
    if (! ce)
      javab_out(-1, "lost pool entry in dump_cpool()");

    write_u1(ce -> tag);

    switch(ce -> tag) {

      case CONSTANT_Class:
      case CONSTANT_String:

	  write_u2(ce -> u.indices.index1);
	  break;

      case CONSTANT_Fieldref:
      case CONSTANT_Methodref:
      case CONSTANT_InterfaceMethodref:
      case CONSTANT_NameAndType:

	  write_u2(ce -> u.indices.index1);
	  write_u2(ce -> u.indices.index2);
	  break;

      case CONSTANT_Integer:
      case CONSTANT_Float:

	  write_u4(ce -> u.data.val1);
	  break;

      case CONSTANT_Long:
      case CONSTANT_Double:

	  write_u4(ce -> u.data.val1);
	  write_u4(ce -> u.data.val2);

	  i++;  /* invalid next entry */

	  break;

      case CONSTANT_Utf8:

	{ u2_int  l = ce -> u.utf8.l;
	  u1_int *s = ce -> u.utf8.s;

	  if (! s)
	    javab_out(-1, "lost UTF8 string in dump_cpool()");

          write_u2(l);

	  for (j = 0u; j < l; j++)
	    write_u1(s[j]);
        }
	break;

      default:
	 javab_out(-1, "invalid constant pool entry in dump_cpool()");
    }
  }
}

/* output of interface information
   ******************************* */

static void dump_interfaces(void) {

  u4_int i; /* wide counter */

  write_u2(interfaces_count);

  if (interfaces_count != 0u) {

    if (! interfaces)
      javab_out(-1, "lost interfaces in dump_interfaces()");

    for (i = 0u; i < interfaces_count; i++) 
      write_u2(interfaces[i]);
  }
}

/* output of field information
   *************************** */

static void dump_fields(void) {

  u4_int i; /* wide counter */

  write_u2(fields_count);

  if (fields_count != 0u) {
  
    if (! fields)
      javab_out(-1, "lost fields in dump_fields()");

    for (i = 0u; i < fields_count; i++) {
	  
      if (! fields[i])
        javab_out(-1, "lost field entry in dump_fields()");
    
      write_u2(fields[i] -> access_flags);
      write_u2(fields[i] -> name_index);
      write_u2(fields[i] -> descr_index);

      dump_attributes(fields[i] -> attributes_count,
		      fields[i] -> attributes);
    }
  }
}

/* output of method information
   **************************** */

static void dump_methods(void) {

  u4_int i; /* wide counter */

  write_u2(methods_count);

  if (methods_count != 0u) {
  
    if (! methods)
      javab_out(-1, "lost methods in dump_methods()");

    for (i = 0u; i < methods_count; i++) {
    
      if (! methods[i])
        javab_out(-1, "lost method entry in dump_methods()");
    
      write_u2(methods[i] -> access_flags);
      write_u2(methods[i] -> name_index);
      write_u2(methods[i] -> descr_index);

      dump_attributes(methods[i] -> attributes_count,
		      methods[i] -> attributes);
    }
  }
}

/* output of complete class file structure
   *************************************** */

static void dump_class(void) {

  write_u4(magic);               /* magic    */

  write_u2(minor_version);       /* versions */
  write_u2(major_version);

  dump_constant_pool();

  write_u2(access_flags);        /* class info */
  write_u2(this_class);
  write_u2(super_class);

  dump_interfaces();
  dump_fields();
  dump_methods();
  dump_attributes(attributes_count, attributes);
}

/* ********************************************************
   *** PUBLIC FUNCTIONS                                 ***
   ******************************************************** */

void dump_classfile(FILE *f) {
  dumpfile = (f) ? f : stdout;
  dump_class();
}
