/*
 * $Source$
 * $Revision$
 * $Date$
 * $Author$
 */


/*****************************************************************************
 * symtab.c                                                                  *
 *                                                                           *
 * Contains routines for creating and manipulating symbol tables.            *
 *                                                                           *
 *****************************************************************************/

#include<stdio.h>
#include<stdlib.h>
#include "f2j.h"
#include "symtab.h"

/*****************************************************************************
 * Globals and Function prototypes:                                          *
 *****************************************************************************/

#define symdebug FALSE          /* set TRUE for debugging output             */

/*  define which of three possible hashing functions to use.                 */

#define HASH(x) hash(x)

unsigned long ElfHash (const unsigned char *);
unsigned int  HashPJW (const char *);
unsigned int  hash (const char *);

char *strdup(char *);

/*****************************************************************************
 *                                                                           *
 * new_symtable                                                              *
 *                                                                           *
 * Create a new symbol table with the given number of entries.  Return a     *
 * pointer to the table.                                                     *
 *                                                                           *
 *****************************************************************************/

SYMTABLE *
new_symtable (int numentries)
{
  SYMTABLE *newtable;
  newtable = (SYMTABLE *) f2jalloc (sizeof (SYMTABLE));

  newtable->num_entries = numentries;
  newtable->num_items = 0;
  newtable->entry = (HASHNODE **) f2jcalloc (numentries, sizeof (HASHNODE *));

  return (newtable);
}				/*  Close new_symtable().  */

/*****************************************************************************
 *                                                                           *
 * type_insert                                                               *
 *                                                                           *
 * Insert a node into the given table.                                       *
 *                                                                           *
 * now accepts entire symbol table as argument instead of just one entry.    *
 * this allows removing a lot of redundant code throughout the parser...     *
 * e.g. computing the hash index.  kgs 3/30/00                               *
 *                                                                           *
 *****************************************************************************/

void
type_insert (SYMTABLE * table, AST * node_val, int returntype, char *tag)
{
  HASHNODE *newnode;
  int idx;

  idx = HASH(tag) % table->num_entries;

  newnode = (HASHNODE *) f2jalloc (sizeof (HASHNODE));

  newnode->ident = tag;
  newnode->type = returntype;
  newnode->variable = node_val;

  /* Initialize to zero; assign number after all types
   * are declared.  
   */
  newnode->localvarnum = -1;

  newnode->next = table->entry[idx];
  table->entry[idx] = newnode;  

  table->num_items++;
}


/*****************************************************************************
 *                                                                           *
 * type_lookup                                                               *
 *                                                                           *
 *  This is a specific lookup routine to match an id with                    *
 * its associated type.  I will need others for matching                     *
 * externals, intrinsics, etc.                                               *
 *                                                                           *
 *****************************************************************************/

HASHNODE *
type_lookup (SYMTABLE * table, char *id)
{
  int index;
  HASHNODE *hash_entry;

  if((table == NULL) || (id == NULL)) {
    return NULL;
  }

  index = HASH (id) % table->num_entries;

  hash_entry = search_hashlist (table->entry[index], id);
  if (hash_entry == NULL)
  {
    if(symdebug)printf ("Not in table.\n"); 
      return NULL;
  }
  else   /*  Attempt to return the value pointed to by "type". */
  {
    if(symdebug)printf("In table.\n");
      return (hash_entry);
  }
}

/*****************************************************************************
 *                                                                           *
 * format_lookup                                                             *
 *                                                                           *
 * Look for a FORMAT statement in the given table.                           *
 *                                                                           *
 *****************************************************************************/

HASHNODE * format_lookup(SYMTABLE *table, char *label)
{
  /* why does this function exist?? kgs */

  return type_lookup(table,label);
}

/*****************************************************************************
 *                                                                           *
 * search_hashlist                                                           *
 *                                                                           *
 * If there is an entry corresponding to the given id in this list, return   *
 * a pointer to it.  otherwise return NULL.                                  *
 *                                                                           *
 *****************************************************************************/

HASHNODE *
search_hashlist (HASHNODE * list, char *id)
{

  if(id == NULL)
    return NULL;

  for (; list; list = list->next)
  {
    if(list->ident == NULL)
      continue;
    if (!strcmp (list->ident, id))
      return (list);
  }

  return NULL;		/*  Not in list. */
}


/*****************************************************************************
 *                                                                           *
 * hash                                                                      *
 *                                                                           *
 *  Simple hash function: just add the ascii integer                         *
 *  values of each character in the string.                                  *
 *                                                                           *
 *  Added error check for null string and made some                          *
 *  other minor changes.  12/5/97  --Keith                                   *
 *                                                                           *
 *****************************************************************************/

unsigned int
hash (const char *str)
{
    int sum = 0;

    if(str == NULL)
      return 0;

    while(*str)
      sum += *str++;

    return sum;
}

/*****************************************************************************
 *                                                                           *
 * ElfHash                                                                   *
 *                                                                           *
 *  The published hash algorithm used in the UNIX ELF format                 *
 *  for object files. Accepts a pointer to a string to be hashed             *
 *  and returns an unsigned long.                                            *
 *                                                                           *
 *****************************************************************************/

unsigned long ElfHash ( const unsigned char *name )
{
  unsigned long   h = 0, g;
  while ( *name )
  {
    h = ( h << 4 ) + *name++;
    if ( (g = h & 0xF0000000) )
      h ^= g >> 24;
    h &= ~g;
  }
  return h;
}

/*****************************************************************************
 * HashPJW                                                                   *
 *                                                                           *
 *  An adaptation of Peter Weinberger's (PJW) generic hashing                *
 *  algorithm based on Allen Holub's version. Accepts a pointer              *
 *  to a datum to be hashed and returns an unsigned integer.                 *
 *                                                                           *
 *****************************************************************************/
#include <limits.h>
#define BITS_IN_int     ( sizeof(int) * CHAR_BIT )
#define THREE_QUARTERS  ((int) ((BITS_IN_int * 3) / 4))
#define ONE_EIGHTH      ((int) (BITS_IN_int / 8))
#define HIGH_BITS       ( ~((unsigned int)(~0) >> ONE_EIGHTH ))

unsigned int HashPJW ( const char * datum )
{
    unsigned int hash_value, i;
    for ( hash_value = 0; *datum; ++datum )
    {
        hash_value = ( hash_value << ONE_EIGHTH ) + *datum;
        if (( i = hash_value & HIGH_BITS ) != 0 )
            hash_value =
                ( hash_value ^ ( i >> THREE_QUARTERS )) &
                        ~HIGH_BITS;
    }
    return ( hash_value );
}

/*****************************************************************************
 *                                                                           *
 * enumerate_symtable                                                        *
 *                                                                           *
 * Create a doubly linked list containing all entries in the given           *
 * symbol table.                                                             *
 *                                                                           *
 *****************************************************************************/

Dlist
enumerate_symtable(SYMTABLE *table)
{
  Dlist newList = make_dl();
  HASHNODE *tmp;
  int i;

  for(i=0;i<table->num_entries;i++)
    for(tmp = table->entry[i]; tmp != NULL; tmp = tmp->next)
      dl_insert_b(newList,tmp->variable);

  return newList;
}
