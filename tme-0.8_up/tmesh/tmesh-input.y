%{
/* $Id: tmesh-input.y,v 1.4 2006/11/15 23:11:31 fredette Exp $ */

/* tmesh/tmesh-input.y - the tme shell scanner and parser: */

/*
 * Copyright (c) 2003 Matt Fredette
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *      This product includes software developed by Matt Fredette.
 * 4. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
 * ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#include <tme/common.h>
_TME_RCSID("$Id: tmesh-input.y,v 1.4 2006/11/15 23:11:31 fredette Exp $");

/* includes: */
#include <tme/threads.h>
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include "tmesh-impl.h"

/* macros: */

/* internal token numbers: */
#define TMESH_TOKEN_UNDEF		(-1)
#define TMESH_TOKEN_EOF			(0)

/* internal character numbers: */
#define TMESH_C_EOF_SEMICOLON		(TMESH_C_YIELD - 1)
#define TMESH_C_UNDEF			(TMESH_C_EOF_SEMICOLON - 2)

#define YYSTYPE struct tmesh_parser_value
#define YYDEBUG 1
#define YYMAXDEPTH 10000

//brad
#define YYLTYPE_IS_TRIVIAL 0
#define YYENABLE_NLS 0

/* types: */

/* globals: */
static tme_mutex_t _tmesh_input_mutex;
static struct tmesh *_tmesh_input;
static char **_tmesh_output;
static int _tmesh_input_yielding;
static YYSTYPE *_tmesh_input_parsed;

/* prototypes: */
static int yylex _TME_P((void));
static void yyerror _TME_P((char *));
static void _tmesh_scanner_in_args _TME_P((void));
static void _tmesh_parser_argv_arg _TME_P((struct tmesh_parser_argv *, char *, int));

%}

/* the tokens: */
%token TMESH_TOKEN_SOURCE
%token TMESH_TOKEN_MKDIR
%token TMESH_TOKEN_RMDIR
%token TMESH_TOKEN_CD
%token TMESH_TOKEN_PWD
%token TMESH_TOKEN_LS
%token TMESH_TOKEN_CONNECT
%token TMESH_TOKEN_RM
%token TMESH_TOKEN_MV
%token TMESH_TOKEN_COMMAND
%token TMESH_TOKEN_LOG
%token TMESH_TOKEN_ALIAS
%token TMESH_TOKEN_AT
%token TMESH_TOKEN_PATHNAME
%token TMESH_TOKEN_ARG
%token TMESH_TOKEN_OPTS

%%

/* a tmesh command: */
command:	command_source	{ *_tmesh_input_parsed = $1; YYACCEPT; }
		| command_mkdir	{ *_tmesh_input_parsed = $1; YYACCEPT; }
		| command_rmdir	{ *_tmesh_input_parsed = $1; YYACCEPT; }
		| command_cd	{ *_tmesh_input_parsed = $1; YYACCEPT; }
		| command_pwd	{ *_tmesh_input_parsed = $1; YYACCEPT; }
		| command_ls	{ *_tmesh_input_parsed = $1; YYACCEPT; }
		| command_connect { *_tmesh_input_parsed = $1; YYACCEPT; }
		| command_rm	{ *_tmesh_input_parsed = $1; YYACCEPT; }
		| command_mv	{ *_tmesh_input_parsed = $1; YYACCEPT; }
		| command_command { *_tmesh_input_parsed = $1; YYACCEPT; }
		| command_log	{ *_tmesh_input_parsed = $1; YYACCEPT; }
		| command_alias	{ *_tmesh_input_parsed = $1; YYACCEPT; }
		| error	';'	{ YYABORT; }
		| ';'
{ _tmesh_input_parsed->tmesh_parser_value_token = TMESH_TOKEN_UNDEF; YYACCEPT; }
		;

/* the 'source' command: */
command_source: TMESH_TOKEN_SOURCE pathname ';'
{ $$ = $2; $$.tmesh_parser_value_token = $1.tmesh_parser_value_token; }

/* the 'mkdir' command: */
command_mkdir:	TMESH_TOKEN_MKDIR pathname ';'
{ $$ = $2; $$.tmesh_parser_value_token = $1.tmesh_parser_value_token; }
		;

/* the 'rmdir' command: */
command_rmdir:	TMESH_TOKEN_RMDIR pathname ';'
{ $$ = $2; $$.tmesh_parser_value_token = $1.tmesh_parser_value_token; }
		;

/* the 'cd' command: */
command_cd:	TMESH_TOKEN_CD pathname ';'
{ $$ = $2; $$.tmesh_parser_value_token = $1.tmesh_parser_value_token; }
		;

/* the 'pwd' command: */
command_pwd:	TMESH_TOKEN_PWD ';'

/* the 'ls' command: */
command_ls:	TMESH_TOKEN_LS opts_opt pathname_opt ';'
{
  $$ = $2;
  $$.tmesh_parser_value_strings[1] = $3.tmesh_parser_value_strings[0];
  $$.tmesh_parser_value_token = $1.tmesh_parser_value_token;
}
		;

/* the 'connect' command: */
command_connect:	TMESH_TOKEN_CONNECT connection ';'
{ $$ = $2; $$.tmesh_parser_value_token = $1.tmesh_parser_value_token; }
command_connect:	connection ';'
{ $$ = $1; $$.tmesh_parser_value_token = TMESH_TOKEN_CONNECT; }
		;

/* the 'rm' command: */
command_rm:	TMESH_TOKEN_RM pathname ';'
{ $$ = $2; $$.tmesh_parser_value_token = $1.tmesh_parser_value_token; }
		;

/* the 'mv' command: */
command_mv:	TMESH_TOKEN_MV pathname pathname ';'
{
  $$ = $2;
  $$.tmesh_parser_value_strings[1] = $3.tmesh_parser_value_strings[0];
  $$.tmesh_parser_value_token = $1.tmesh_parser_value_token;
}
		;

/* the 'command' command: */
command_command: TMESH_TOKEN_COMMAND pathname_args ';'
{ $$ = $2; $$.tmesh_parser_value_token = $1.tmesh_parser_value_token; }
		;

/* the 'log' command: */
command_log: TMESH_TOKEN_LOG pathname_args ';'
{ $$ = $2; $$.tmesh_parser_value_token = $1.tmesh_parser_value_token; }
		;

/* the 'alias' command: */
command_alias:	TMESH_TOKEN_ALIAS pathname pathname ';'
{
  $$ = $2;
  $$.tmesh_parser_value_strings[1] = $3.tmesh_parser_value_strings[0];
  $$.tmesh_parser_value_token = $1.tmesh_parser_value_token;
}
		;

/* a pathname: */
pathname:	TMESH_TOKEN_PATHNAME
		;

/* an optional pathname: */
pathname_opt:	TMESH_TOKEN_PATHNAME
		| /* empty */ 
{ $$.tmesh_parser_value_strings[0] = NULL; }
		;

/* a pathname followed by optional arguments: */
pathname_args:	TMESH_TOKEN_PATHNAME
{ 
  _tmesh_parser_argv_arg(&$$.tmesh_parser_value_argvs[0], 
			 $1.tmesh_parser_value_pathname0, 
			 TRUE);
  _tmesh_scanner_in_args();
}
		| pathname_args TMESH_TOKEN_ARG
{
  $$ = $1; 
  _tmesh_parser_argv_arg(&$$.tmesh_parser_value_argvs[0], 
			 $2.tmesh_parser_value_arg, 
			 FALSE);
}
		;

/* arguments: */
args:		TMESH_TOKEN_ARG
{
  _tmesh_parser_argv_arg(&$$.tmesh_parser_value_argvs[0], 
			 $1.tmesh_parser_value_arg, 
			 TRUE);
}
		| args TMESH_TOKEN_ARG
{ 
  $$ = $1; 
  _tmesh_parser_argv_arg(&$$.tmesh_parser_value_argvs[0], 
			 $2.tmesh_parser_value_arg, 
			 FALSE);
}

/* a colon: */
colon: ':' { _tmesh_scanner_in_args(); } ;

/* an 'at': */
at: TMESH_TOKEN_AT { _tmesh_scanner_in_args(); } ;

/* a connection specification: */
connection:	pathname_args colon args
{
  if ($1.tmesh_parser_value_argvs[0].tmesh_parser_argv_argc > 1) {
    yyerror(_("expected 'at'"));
    YYERROR;
  }
  $$.tmesh_parser_value_argvs[0] = $1.tmesh_parser_value_argvs[0];
  $$.tmesh_parser_value_argvs[1].tmesh_parser_argv_argv = NULL;
  $$.tmesh_parser_value_argvs[2] = $3.tmesh_parser_value_argvs[0];
}
		| pathname_args at args colon args
{
  $$.tmesh_parser_value_argvs[0] = $1.tmesh_parser_value_argvs[0];
  $$.tmesh_parser_value_argvs[1] = $3.tmesh_parser_value_argvs[0];
  $$.tmesh_parser_value_argvs[2] = $5.tmesh_parser_value_argvs[0];
}
		| pathname_args at args
{
  $$.tmesh_parser_value_argvs[0] = $1.tmesh_parser_value_argvs[0];
  $$.tmesh_parser_value_argvs[1] = $3.tmesh_parser_value_argvs[0];
  $$.tmesh_parser_value_argvs[2].tmesh_parser_argv_argv = NULL;
}
		;

/* options: */
opts_opt:	TMESH_TOKEN_OPTS
		| /* empty */
{ $$.tmesh_parser_value_strings[0] = NULL; }
		;

%%

/* this adds a new argument to an argument vector: */
static void
_tmesh_parser_argv_arg(struct tmesh_parser_argv *argv, char *arg, int new)
{

  /* if we're starting a new argv, allocate the initial vector, else
     make sure the argv has enough room for the new argument and a
     trailing NULL that _tmesh_command_connect will add later: */
  if (new) {
    argv->tmesh_parser_argv_size = 8;
    argv->tmesh_parser_argv_argv = 
      _tmesh_gc_new(_tmesh_input,
		    char *, 
		    argv->tmesh_parser_argv_size);
    argv->tmesh_parser_argv_argc = 0;
  }
  else if ((argv->tmesh_parser_argv_argc + 1)
	   >= argv->tmesh_parser_argv_size) {
    argv->tmesh_parser_argv_size +=
      (2
       + (argv->tmesh_parser_argv_size >> 1));
    argv->tmesh_parser_argv_argv = 
      _tmesh_gc_renew(_tmesh_input,
		      char *, 
		      argv->tmesh_parser_argv_argv,
		      argv->tmesh_parser_argv_size);
  }

  /* put in the new argument: */
  argv->tmesh_parser_argv_argv[argv->tmesh_parser_argv_argc++] = arg;
}

/* this is called by the parser when it encounters an error: */
static void
yyerror(char *msg)
{
  tme_output_append(_tmesh_output, "%s", msg);
  _tmesh_input->tmesh_scanner.tmesh_scanner_in_args = FALSE;
}

/* this is called by the parser when args can be expected: */
static void
_tmesh_scanner_in_args(void)
{
  _tmesh_input->tmesh_scanner.tmesh_scanner_in_args = TRUE;
}

/* this matches a collected token: */
static int
_tmesh_scanner_token(struct tmesh_scanner *scanner)
{
  int token;
  char *string;
  int keep_string;

  /* if we have no collected token, return no token: */
  if (scanner->tmesh_scanner_token_string_size == 0
      || scanner->tmesh_scanner_token_string_len == 0) {
    return (TMESH_TOKEN_UNDEF);
  }

  /* get the collected token: */
  string = scanner->tmesh_scanner_token_string;
  string[scanner->tmesh_scanner_token_string_len] = '\0';

  /* assume we won't need to keep this string: */
  keep_string = FALSE;

  /* the reserved word "at" is always recognized, since it can
     terminate a list of arguments: */
  if (!strcmp(string, "at")) {
    token = TMESH_TOKEN_AT;
    scanner->tmesh_scanner_in_args = FALSE;
  }
  
  /* if we're in arguments, every other collected token is an argument: */
  else if (scanner->tmesh_scanner_in_args) {
    token = TMESH_TOKEN_ARG;
    keep_string = TRUE;
  }

  /* otherwise, if we're not in arguments, every other collected token
     is either a reserved word, options, or a pathname: */
  else {
    if (!strcmp(string, "source")) {
      token = TMESH_TOKEN_SOURCE;
    }  
    else if (!strcmp(string, "cd")) {
      token = TMESH_TOKEN_CD;
    }  
    else if (!strcmp(string, "pwd")) {
      token = TMESH_TOKEN_CD;
    }  
    else if (!strcmp(string, "ls")) {
      token = TMESH_TOKEN_LS;
    }  
    else if (!strcmp(string, "rm")) {
      token = TMESH_TOKEN_RM;
    }  
    else if (!strcmp(string, "connect")) {
      token = TMESH_TOKEN_CONNECT;
    }  
    else if (!strcmp(string, "mkdir")) {
      token = TMESH_TOKEN_MKDIR;
    }  
    else if (!strcmp(string, "rmdir")) {
      token = TMESH_TOKEN_RMDIR;
    }  
    else if (!strcmp(string, "mv")) {
      token = TMESH_TOKEN_MV;
    }
    else if (!strcmp(string, "command")) {
      token = TMESH_TOKEN_COMMAND;
    }  
    else if (!strcmp(string, "log")) {
      token = TMESH_TOKEN_LOG;
    }  
    else if (!strcmp(string, "alias")) {
      token = TMESH_TOKEN_ALIAS;
    }  
    else if (string[0] == '-') {
      token = TMESH_TOKEN_OPTS;
      keep_string = TRUE;
    }
    else {
      token = TMESH_TOKEN_PATHNAME;
      keep_string = TRUE;
    }
  }

  /* if we need to keep this string, put it in yylval, else recycle it: */
  yylval.tmesh_parser_value_token = token;
  if (keep_string) {
    yylval.tmesh_parser_value_strings[0] = string;
    scanner->tmesh_scanner_token_string_size = 0;
  }
  else {
    yylval.tmesh_parser_value_strings[0] = NULL;
    scanner->tmesh_scanner_token_string_len = 0;
  }

  return (token);
}

/* our scanner: */
int
yylex(void)
{
  struct tmesh_scanner *scanner;
  struct tmesh_io_stack *stack;
  struct tmesh_io *source;
  int token, c;
  
  /* recover our scanner state: */
  scanner = &_tmesh_input->tmesh_scanner;
  stack = _tmesh_input->tmesh_io_stack;
  source = &stack->tmesh_io_stack_io;

  /* bump the input line: */
  source->tmesh_io_input_line += scanner->tmesh_scanner_next_line;
  scanner->tmesh_scanner_next_line = 0;

  /* if we previously scanned the next token to return, return it
     and clear it, unless it's EOF, which sticks: */
  token = scanner->tmesh_scanner_token_next;
  if (token != TMESH_TOKEN_UNDEF) {
    if (token != TMESH_TOKEN_EOF) {
      scanner->tmesh_scanner_token_next = TMESH_TOKEN_UNDEF;
    }
    return (token);
  }

  /* loop forever: */
  for (;;) {

    /* get the next character: */
    c = scanner->tmesh_scanner_c_next;
    if (c == TMESH_C_UNDEF) {
      c = (*source->tmesh_io_getc)(source);
    }
    scanner->tmesh_scanner_c_next = TMESH_C_UNDEF;

    /* if this is an EOF: */
    if (c == TMESH_C_EOF) {

      /* turn c into the EOF semicolon: */
      c = TMESH_C_EOF_SEMICOLON;

      /* if we have collected a token, save the EOF semicolon and return the token: */
      token = _tmesh_scanner_token(scanner);
      if (token != TMESH_TOKEN_UNDEF) {
	scanner->tmesh_scanner_c_next = c;
	return (token);
      }
    }

    /* if this is an EOF semicolon: */
    if (c == TMESH_C_EOF_SEMICOLON) {

      /* quoted strings and comments (and commands, for that matter) cannot cross EOF boundaries: */
      scanner->tmesh_scanner_in_quotes = FALSE;
      scanner->tmesh_scanner_in_comment = FALSE;

      /* close the now-finished source: */
      (*source->tmesh_io_close)(source, 
				(stack->tmesh_io_stack_next != NULL
				 ? &stack->tmesh_io_stack_next->tmesh_io_stack_io
				 : NULL));

      /* pop the io stack: */
      _tmesh_input->tmesh_io_stack = stack->tmesh_io_stack_next;
      tme_free(source->tmesh_io_name);
      tme_free(stack);
      
      /* if we have emptied the source stack, we are really at EOF,
	 and the next time we're called we will return that: */
      stack = _tmesh_input->tmesh_io_stack;
      source = &stack->tmesh_io_stack_io;
      if (stack == NULL) {
	scanner->tmesh_scanner_token_next = TMESH_TOKEN_EOF;
	return (TMESH_TOKEN_EOF);
      }

      /* return the EOF semicolon: */
      return (';');
    }

    /* if this is a yield: */
    if (c == TMESH_C_YIELD) {

      /* we are yielding: */
      _tmesh_input_yielding = TRUE;

      /* return an EOF token: */
      return (TMESH_TOKEN_EOF);
    }    

    /* if we're in a comment: */
    if (scanner->tmesh_scanner_in_comment) {
      if (c != '\n') {
	continue;
      }
      scanner->tmesh_scanner_in_comment = FALSE;
    }

    /* if this is quotation marks: */
    if (c == '"') {
      scanner->tmesh_scanner_in_quotes = !scanner->tmesh_scanner_in_quotes;
      continue;
    }

    /* other than quotation marks, every character either delimits
       tokens or is collected into the current token: */
    if (

	/* any character inside quotes is collected: */
	scanner->tmesh_scanner_in_quotes

	/* any alphanumeric character is collected: */
	|| isalnum(c)

	/* any period, slash, hyphen, and underscore character is collected: */
	|| c == '.'
	|| c == '/'
	|| c == '-'
	|| c == '_'
	) {

      /* allocate or grow the token buffer as needed.  we always
	 make sure there's room for this new character, and a trailing
	 NUL that _tmesh_scanner_token may add: */
      if (scanner->tmesh_scanner_token_string_size == 0) {
	scanner->tmesh_scanner_token_string_len = 0;
	scanner->tmesh_scanner_token_string_size = 8;
	scanner->tmesh_scanner_token_string = 
	  _tmesh_gc_new(_tmesh_input,
			char, 
			scanner->tmesh_scanner_token_string_size);
      }
      else if ((scanner->tmesh_scanner_token_string_len + 1)
	       >= scanner->tmesh_scanner_token_string_size) {
	scanner->tmesh_scanner_token_string_size +=
	  (2
	   + (scanner->tmesh_scanner_token_string_size >> 1));
	scanner->tmesh_scanner_token_string = 
	  _tmesh_gc_renew(_tmesh_input,
			  char, 
			  scanner->tmesh_scanner_token_string,
			  scanner->tmesh_scanner_token_string_size);
      }

      /* collect the character into the buffer: */
      scanner->tmesh_scanner_token_string[scanner->tmesh_scanner_token_string_len++] = c;
    }

    /* delimit this token: */
    else {

      /* if we have collected a token, save the delimiter and return the token: */
      token = _tmesh_scanner_token(scanner);
      if (token != TMESH_TOKEN_UNDEF) {
	scanner->tmesh_scanner_c_next = c;
	return (token);
      }

      /* a carriage return or a newline becomes a semicolon, and
	 a pound sign begins a comment: */
      if (c == '\n') {
	c = ';';
	scanner->tmesh_scanner_next_line = 1;
      }
      else if (c == '\r') {
	c = ';';
      }
      else if (c == '#') {
	scanner->tmesh_scanner_in_comment = TRUE;
	scanner->tmesh_scanner_in_args = FALSE;
	continue;
      }

      /* return a non-whitespace delimiter as a token, and this resets
         the args state: */
      if (!isspace(c)) {
	scanner->tmesh_scanner_in_args = FALSE;
	return (c);
      }
    }
  }
  /* NOTREACHED */
}

/* this is called to parse input: */
int
_tmesh_yyparse(struct tmesh *tmesh, struct tmesh_parser_value *value, char **_output, int *_yield)
{
  struct tmesh_scanner *scanner;
  int rc;
  int command;

  /* initialize the scanner: */
  scanner = &tmesh->tmesh_scanner;
  scanner->tmesh_scanner_token_next = TMESH_TOKEN_UNDEF;
  scanner->tmesh_scanner_c_next = TMESH_C_UNDEF;
  scanner->tmesh_scanner_in_comment = FALSE;
  scanner->tmesh_scanner_in_quotes = FALSE;
  scanner->tmesh_scanner_in_args = FALSE;
  scanner->tmesh_scanner_token_string_size = 0;

  /* lock the input mutex: */
  tme_mutex_lock(&_tmesh_input_mutex);

  /* set this tmesh for input: */
  _tmesh_input = tmesh;
  _tmesh_output = _output;
  
  /* assume that we will not have to yield: */
  _tmesh_input_yielding = FALSE;

  /* call the parser: */
  _tmesh_input_parsed = value;
  rc = (yyparse()
	? EINVAL
	: TME_OK);

  /* tell our caller if we're yielding: */
  *_yield = _tmesh_input_yielding;

  /* unlock the input mutex: */
  tme_mutex_unlock(&_tmesh_input_mutex);

  /* if the parse was successful, map the command token number to a command number: */
  if (rc == TME_OK && !*_yield) {
    switch (value->tmesh_parser_value_token) {
    default: assert(FALSE);
    case TMESH_TOKEN_UNDEF:	command = TMESH_COMMAND_NOP; break;
    case TMESH_TOKEN_SOURCE:	command = TMESH_COMMAND_SOURCE; break;
    case TMESH_TOKEN_MKDIR:	command = TMESH_COMMAND_MKDIR; break;
    case TMESH_TOKEN_RMDIR:	command = TMESH_COMMAND_RMDIR; break;
    case TMESH_TOKEN_CD:	command = TMESH_COMMAND_CD; break;
    case TMESH_TOKEN_PWD:	command = TMESH_COMMAND_PWD; break;
    case TMESH_TOKEN_LS:	command = TMESH_COMMAND_LS; break;
    case TMESH_TOKEN_CONNECT:	command = TMESH_COMMAND_CONNECT; break;
    case TMESH_TOKEN_RM:	command = TMESH_COMMAND_RM; break;
    case TMESH_TOKEN_COMMAND:	command = TMESH_COMMAND_COMMAND; break;
    case TMESH_TOKEN_LOG:	command = TMESH_COMMAND_LOG; break;
    case TMESH_TOKEN_ALIAS:	command = TMESH_COMMAND_ALIAS; break;
    }
    value->tmesh_parser_value_command = command;
  }

  /* done: */
  return (rc);
}
