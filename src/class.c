
/*****************************************************************************
 * class.c                                                                   *
 *                                                                           *
 * This file contains routines for writing the class file structure to disk. *
 *                                                                           *
 *****************************************************************************/

#include<stdio.h>
#include<stdlib.h>
#include<string.h>
#include<ctype.h>
#include"class.h"
#include"constant_pool.h"
#include"f2jparse.tab.h"


/*****************************************************************************
 * write_class                                                               *
 *                                                                           *
 * Given a pointer to a classfile structure, this function writes the class  *
 * file to disk.                                                             *
 *                                                                           *
 *****************************************************************************/

void
write_class(struct ClassFile *class)
{
  FILE *cfp;

  cfp = open_output_classfile(class);

  write_u4(class->magic, cfp);
  write_u2(class->minor_version, cfp);
  write_u2(class->major_version, cfp);
  write_u2(class->constant_pool_count, cfp);
  write_constant_pool(class, cfp);
  write_u2(class->access_flags, cfp);
  write_u2(class->this_class, cfp);
  write_u2(class->super_class, cfp);
  write_u2(class->interfaces_count, cfp);
  write_interfaces(class,cfp);
  write_u2(class->fields_count, cfp);
  write_fields(class,cfp);
  write_u2(class->methods_count, cfp);
  write_methods(class,cfp);
  write_u2(class->attributes_count, cfp);
  write_attributes(class->attributes,class->constant_pool,cfp);

  fclose(cfp);
}

/*****************************************************************************
 * write_constant_pool                                                       *
 *                                                                           *
 * This function writes the all the constants to disk.  this could be more   *
 * efficient if we could assume that there was no padding in the structures. *
 * then it would just be a matter of writing out however many bytes is       *
 * allocated.  but i'm not really sure how different compilers might pad     *
 * structures, so i'm going to play it safe here and just write each item    *
 * individually.  --kgs 4/25/00                                              *
 *                                                                           *
 *****************************************************************************/

void
write_constant_pool(struct ClassFile *class, FILE *out)
{
  CPNODE * tmpconst;
  Dlist tmpPtr;

  dl_traverse(tmpPtr,class->constant_pool) {
    tmpconst = (CPNODE *) tmpPtr->val;

    write_u1(tmpconst->val->tag, out);

    switch(tmpconst->val->tag) {
      case CONSTANT_Utf8:
        write_u2(tmpconst->val->cpnode.Utf8.length,out);
        fwrite(tmpconst->val->cpnode.Utf8.bytes,
           tmpconst->val->cpnode.Utf8.length,1,out);
        break;
      case CONSTANT_Integer:
        fwrite(&(tmpconst->val->cpnode.Integer.bytes),
           sizeof(tmpconst->val->cpnode.Integer.bytes),1,out);
        break;
      case CONSTANT_Float:
        fwrite(&(tmpconst->val->cpnode.Float.bytes),
           sizeof(tmpconst->val->cpnode.Float.bytes),1,out);
        break;
      case CONSTANT_Long:
        fwrite(&(tmpconst->val->cpnode.Long.high_bytes),
           sizeof(tmpconst->val->cpnode.Long.high_bytes),1,out);
        fwrite(&(tmpconst->val->cpnode.Long.low_bytes),
           sizeof(tmpconst->val->cpnode.Long.low_bytes),1,out);
        break;
      case CONSTANT_Double:
        fwrite(&(tmpconst->val->cpnode.Double.high_bytes),
           sizeof(tmpconst->val->cpnode.Double.high_bytes),1,out);
        fwrite(&(tmpconst->val->cpnode.Double.low_bytes),
           sizeof(tmpconst->val->cpnode.Double.low_bytes),1,out);
        break;
      case CONSTANT_Class:
        write_u2(tmpconst->val->cpnode.Class.name_index,out);
        break;
      case CONSTANT_String:
        write_u2(tmpconst->val->cpnode.String.string_index, out);
        break;
      case CONSTANT_Fieldref:
      case CONSTANT_Methodref:
      case CONSTANT_InterfaceMethodref:
        write_u2(tmpconst->val->cpnode.Methodref.class_index,out);
        write_u2(tmpconst->val->cpnode.Methodref.name_and_type_index,out);
        break;
      case CONSTANT_NameAndType:
        write_u2(tmpconst->val->cpnode.NameAndType.name_index,out);
        write_u2(tmpconst->val->cpnode.NameAndType.descriptor_index,out);
        break;
      default:
        fprintf(stderr,"WARNING: unknown tag in write_constant_pool()\n");
        break;  /* ANSI requirement */
    }
  }
}

/*****************************************************************************
 * write_interfaces                                                          *
 *                                                                           *
 * This function writes the all the interfaces to disk.                      *
 * Currently f2java generated classes do not implement any interfaces, so    *
 * this function will go unimplemented until we actually need it.            *
 *                                                                           *
 *****************************************************************************/

void
write_interfaces(struct ClassFile *class, FILE *out)
{

  /* intentionally empty */

}

/*****************************************************************************
 * write_fields                                                              *
 *                                                                           *
 * This function writes the all the fields to disk.                          *
 *                                                                           *
 *****************************************************************************/

void
write_fields(struct ClassFile *class, FILE *out)
{
  struct field_info *tmpfield;
  Dlist tmpPtr;

  dl_traverse(tmpPtr,class->fields) {
    tmpfield = (struct field_info *) tmpPtr->val;

    write_u2(tmpfield->access_flags,out);
    write_u2(tmpfield->name_index,out);
    write_u2(tmpfield->descriptor_index,out);

    /* we do not expect there to be any field attributes, so check the 
     * count and issue a warning message if count > 0
     */
  
    if(tmpfield->attributes_count > 0) {
      fprintf(stderr,"WARNING: not expecting attributes on a field!\n");
      tmpfield->attributes_count = 0;
    }

    write_u2(tmpfield->attributes_count,out);

    /* here is where we'd write the attributes themselves, if f2j should
     * ever need to use them.
     *
     * write_field_attributes(tmpfield,out);
     */
  }
}

/*****************************************************************************
 * write_methods                                                             *
 *                                                                           *
 * This function writes the all the methods to disk.                         *
 *                                                                           *
 *****************************************************************************/

void
write_methods(struct ClassFile *class, FILE *out)
{
  struct method_info *tmpmeth;
  Dlist tmpPtr;

  dl_traverse(tmpPtr,class->methods) {
    tmpmeth = (struct method_info *) tmpPtr->val;

    write_u2(tmpmeth->access_flags,out);
    write_u2(tmpmeth->name_index,out);
    write_u2(tmpmeth->descriptor_index,out);
    write_u2(tmpmeth->attributes_count,out);

    write_attributes(tmpmeth->attributes,class->constant_pool,out);
  }
}

/*****************************************************************************
 * write_attributes                                                          *
 *                                                                           *
 * This function writes the all the attributes to disk.                      *
 * we dont need to support all attributes since f2j will only use a few.     *
 *                                                                           *
 *****************************************************************************/

void
write_attributes(Dlist attr_list, Dlist const_pool, FILE *out)
{
  struct attribute_info *tmpattr;
  char *attr_name;
  Dlist tmpPtr;
  CPNODE *c;

  if((attr_list == NULL) || (const_pool == NULL))
    return;

  dl_traverse(tmpPtr,attr_list) {
    tmpattr = (struct attribute_info *) tmpPtr->val;

    c = cp_entry_by_index(const_pool, tmpattr->attribute_name_index);
 
    if(c==NULL) {
      fprintf(stderr,"WARNING: write_attributes() can't find attribute name\n");
      continue;
    } 
      
    attr_name = null_term(c->val->cpnode.Utf8.bytes, c->val->cpnode.Utf8.length);

    write_u2(tmpattr->attribute_name_index,out);
    write_u4(tmpattr->attribute_length,out);

    if(!strcmp(attr_name,"SourceFile")) {
      write_u2(tmpattr->attr.SourceFile->sourcefile_index,out);
    } 
    else if(!strcmp(attr_name,"Code")) {
      write_u2(tmpattr->attr.Code->max_stack,out);
      write_u2(tmpattr->attr.Code->max_locals,out); 
      write_u4(tmpattr->attr.Code->code_length,out);
      fwrite(tmpattr->attr.Code->code, tmpattr->attr.Code->code_length, 1, out);
      write_u2(tmpattr->attr.Code->exception_table_length,out);
      if(tmpattr->attr.Code->exception_table_length > 0)
        fprintf(stderr,"WARNING: dont know how to write exception table yet.\n");
      write_u2(tmpattr->attr.Code->attributes_count,out);
      if(tmpattr->attr.Code->attributes_count > 0)
        write_attributes(tmpattr->attr.Code->attributes, const_pool, out);
    } 
    else {
      fprintf(stderr,"WARNING: write_attributes() unsupported attribute!\n");
    }
  }
}

/*****************************************************************************
 * open_output_classfile                                                     *
 *                                                                           *
 * This function opens the file to which we write the bytecode.              *
 * We derive the name of the class by looking at the "this_class" entry      *
 * in the classfile structure.                                               *
 *                                                                           *
 *****************************************************************************/

FILE *
open_output_classfile(struct ClassFile *class)
{
  char *filename;
  FILE *newfp;
  CPNODE *c;
  
  if(class == NULL)
    return NULL;

  c = cp_entry_by_index(class->constant_pool, class->this_class);
  c = cp_entry_by_index(class->constant_pool, c->val->cpnode.Class.name_index);

  if(c==NULL) {
    fprintf(stderr,"Error opening class file.\n");
    exit(1);
  }

  /* malloc enough characters in the filename for:
   *  - the class name
   *  - plus 6 chars for ".class"
   *  - plus 1 char for the null terminator
   */

  filename = (char *)f2jalloc(c->val->cpnode.Utf8.length +  7);
  strncpy(filename, (char *)c->val->cpnode.Utf8.bytes, c->val->cpnode.Utf8.length);
  filename[c->val->cpnode.Utf8.length] = '\0';
  strcat(filename,".class");

  if( (newfp = fopen(filename,"wb")) == NULL ) {
    fprintf(stderr,"Cannot open output file '%s'\n",filename);
    perror("Reason");
    exit(1);
  }

  return newfp;
}

/*****************************************************************************
 * write_u1                                                                  *
 *                                                                           *
 * Writes an unsigned byte to the specified file pointer.  there are no      *
 * issues with endianness here, but this function is included for            *
 * consistency.                                                              *
 *                                                                           *
 *****************************************************************************/

void
write_u1(u1 num, FILE *out)
{
  fwrite(&num, sizeof(num), 1, out);
}

/*****************************************************************************
 * write_u2                                                                  *
 *                                                                           *
 * Writes an unsigned short to the specified file pointer, changing          *
 * endianness if necessary.                                                  *
 *                                                                           *
 *****************************************************************************/

void
write_u2(u2 num, FILE *out)
{
  u2 u2BigEndian(u2);

  num = u2BigEndian(num);
  fwrite(&num, sizeof(num), 1, out);
}

/*****************************************************************************
 * write_u4                                                                  *
 *                                                                           *
 * Writes an unsigned int to the specified file pointer, changing endianness *
 * if necessary.                                                             *
 *                                                                           *
 *****************************************************************************/

void
write_u4(u4 num, FILE *out)
{
  u4 u4BigEndian(u4);

  num = u4BigEndian(num);
  fwrite(&num, sizeof(num), 1, out);
}
