#lang scribble/manual

@(require (for-label (only-in gregor date-provider? ->day)
                     racket/base
                     racket/contract
                     racket/list
                     racket/string
                     toml/config
                     toml/config/schema
                     toml/config/reader
                     toml)
          scribble/example
          "doc-util.rkt")

@title{Module Reference}

@section{Basic TOML DSL}

@defmodulelang[toml/config]

A @hash-lang[] for parsing TOML files into Racket modules. Files using @code{#lang toml/config} are
parsed as TOML and provide the result as a hash table.

@defthing[toml hash?]{

The parsed TOML data, represented as an immutable hash table with symbol keys. Tables become nested
hash tables, and all TOML data types are converted to their Racket equivalents.

}

@defproc[(toml-ref [data hash?]
                    [path-component (or/c symbol? exact-nonnegative-integer?)] ...
                    [#:default default any/c (λ () (error ...))])
         any/c]{

Variadic convenience function for accessing nested TOML values using a path of keys and array indices.

Path components can be:
@itemlist[#:style 'compact
@item{Symbols (possibly dotted): traverse into hash tables}
@item{Exact non-negative integers: index into lists}
]

If any key in the path is missing or an array index is out of bounds, @racket[default] is returned
(or called if it's a procedure).

@racketblock[
(code:comment "Dotted key notation")
(toml-ref data 'database.host)
(code:comment "equivalent to:")
(hash-ref (hash-ref data 'database) 'host)

(code:comment "Array indexing")
(toml-ref data 'database.replicas 0 'host)
(code:comment "equivalent to:")
(hash-ref (first (hash-ref (hash-ref data 'database) 'replicas)) 'host)

(code:comment "With defaults")
(toml-ref data 'missing.key #:default "fallback")
(code:comment "=> \"fallback\"")
(toml-ref data 'replicas 99 'host #:default "n/a")
(code:comment "=> \"n/a\"")
]
}

@section{Custom TOML DSLs}

@defmodule[toml/config/custom]

A module language for quickly creating custom TOML-based @hash-lang[]s with validation.

When you use @hash-lang[] @racketmodname[toml/config/custom] as a module language (in a
@racket[reader] submodule), it provides a @racket[#%module-begin] that handles all the reader
plumbing for you.  You just specify an optional schema, and it generates a @racket[read-syntax]
macro and provides the @racket[get-info] function automatically.

The module language also provides common predicates and contracts that are useful in schemas:
everything from @racketmodname[racket/base], @racketmodname[racket/contract/base], and
@racket[non-empty-string?].

@subsection{Basic usage (no validation)}

The simplest custom reader just parses TOML without any validation:

@racketmod[#:file "myapp/config.rkt"
racket/base

(module reader toml/config/custom)]

Now TOML files can use @racketmodfont{#lang myapp/config} (assuming this module is present in a
package that uses the @tt{myapp} collection) and they'll get the same behavior as @code{#lang
toml/config}.

@subsection{With a schema}

To add validation that takes place at compile time, use the @racket[#:schema] keyword inside the
@tt{reader} submodule, followed by field specifications:

@racketmod[#:file "myapp/config.rkt"
racket/base

(module reader toml/config/custom
 #:schema ([title string? required]
           [port (integer-in 1 65535) (optional 8080)]
           [database (table
                       [host string? required]
                       [port integer? required])]))]

See @racket[define-toml-schema] for info on the field-spec syntax. 

By default, the schema expression
inside a @hash-lang[] @racketmodname[toml/config/custom] module has access to bindings from
@racketmodname[racket/base], @racketmodname[racket/contract/base] and to @racket[non-empty-string?]
from @racketmodname[racket/string].

@inline-note{This validation does not install any contracts at module boundaries; it simply checks
the supplied TOML data once, at compile time.}

@subsection{Using additional bindings in the schema}

You can add @racket[require] and/or @racket[define] statements in front of the @racket[#:schema]
keyword. This allows you to use custom predicates/contracts in your schema expression.

For example:

@racketmod[#:file "myapp/example.rkt"
racket/base

(module reader toml/config/custom
  (require gregor)
  (define (even-day? v) (and (date-provider? v) (even? (->day v))))
  #:schema [(birthdate even-day? required)])]

@inline-note{Note that @racket[parse-toml] parses dates and times into their equivalent
@racketmodname[gregor] values, but @racketmodname[gregor] bindings aren’t available by default in
@racketmodname[toml/config/custom]. Use @racket[require] as shown above to use
@racketmodname[gregor] predicates in your schema.}

You can also use @racket[module*] with @racket[(require (submod ".."))] to bring parent bindings
into scope:

@racketmod[#:file "myapp/example.rkt"
racket/base

(define (valid-port? n)
 (and (integer? n) (>= n 1024) (<= n 65535)))

(provide valid-port?)

(module* reader toml/config/custom
 (require (submod ".."))
 #:schema ([title string? required]
           [port integer? valid-port? (optional 8080)]))]

@section{Low-level APIs}

Most people won’t need more than @racketmodname[toml/config/custom] to implement their own TOML
DSLs.  But if you want more control over the reader implementation, or if you're not using
@racketmodname[toml/config/custom] as a module language, you can use these lower-level functions
directly.

Here's an example using @racket[module+] to create a reader submodule that accesses custom
predicates from the parent module:

@racketmod[#:file "myapp/config.rkt"
racket/base

(define (valid-title? s)
 (and (string? s)
      (> (string-length s) 0)
      (<= (string-length s) 50)))

(define (valid-port? n)
 (and (integer? n)
      (>= n 1024)
      (<= n 65535)))

(module+ reader
 (require toml/config/schema
          toml/config/reader)
 (provide read-syntax get-info)

 (define-toml-schema compiled-schema
   [title string? valid-title? required]
   [port integer? valid-port? (optional 8080)])

 (define read-syntax
   (make-toml-syntax-reader compiled-schema)))]

Note that when using the low-level APIs, you need to @racket[provide] both @racket[read-syntax]
and @racket[get-info] yourself (whereas @racketmodname[toml/config/custom] does this automatically).

@subsection{Validation}

@defmodule[toml/config/schema]

This module provides the framework for validating hash tables against a schema, with friendly error
messages. A schema can make use of simple predicates or flat contracts, but no contracts are
actually installed.

A @deftech{validator} is a function that takes a hash table (such as parsed TOML data) and either
returns a value (typically a hash table, but not required) or raises an exception if validation
fails. Validators created with @racket[define-toml-schema] also apply default values to the data
before returning it.

@(define s-ev (make-base-eval))

@defform[#:literals (required optional table array-of)
         (define-toml-schema id field-spec ...)
         #:grammar ([field-spec [key type-check ... req-or-opt]
                                [key (table field-spec ...) maybe-req-or-opt]
                                [key (array-of table field-spec ...) req-or-opt]]
                    [req-or-opt required
                                optional
                                (optional default-expr)]
                    [maybe-req-or-opt (code:line)
                                      required
                                      optional])]{

Creates a @tech{validator} function bound to @racket[id].

Each named @racket[key] is followed by one or more @racket[type-check] predicates (or flat
contracts) that are applied to the value supplied for the key.

Ending a field-spec with @racket[required] causes an exception to be thrown if the key is not
present. Ending with @racket[optional] allows the key to be absent; use @racket[(optional
default-expr)] to give the key a default value when not supplied. Note that the default value is not
checked against the @racket[type-check] expressions.

A @racket[table] field-spec validates a nested table with its own field specs. It can be followed by
@racket[required] or @racket[optional]; if neither is specified, @racket[required] is assumed. When
a table is optional and missing, its field validations are skipped.

An @racket[array-of table] field-spec validates an array of tables (TOML’s @tt{[[name]]} syntax).
Each element in the array is validated against the nested field specs. Defaults are applied to each
array element individually.

Type checks can be any predicate (e.g. @racket[string?], @racket[integer?]) or flat contract (e.g.
@racket[(integer-in 1 100)], @racket[(listof string?)], @racket[(or/c "ascending" "descending")]).

The resulting validator checks that all @racket[required] keys are present, validates types for all
present keys, applies default values for missing optional keys and returns the (possibly modified)
hash table.

@(s-ev '(require toml toml/config/schema racket/contract racket/list racket/string))
@examples[#:eval s-ev
(define-toml-schema my-schema
  [name string? required]
  [age (integer-in 0 150) required]
  [email string? optional]
  [admin boolean? (optional #f)]
  [settings (table
              [theme string? required]
              [notifications boolean? (optional #t)])])

(define toml-1
  (string-append*
    (add-between  
     '("name = \"Alice\""
       "age = 30"
       "[settings]")
      "\n")))

(eval:error (my-schema (parse-toml toml-1)))

(define toml-2
  (string-append*
    (add-between  
     '("name = \"Alice\""
       "age = 30"
       "[settings]"
       "theme = \"red\"")
      "\n")))

(my-schema (parse-toml toml-2))]

Arrays of tables are validated with @racket[array-of]:

@examples[#:eval s-ev
(define-toml-schema products-schema
  [products (array-of table
              [name string? required]
              [sku integer? required]
              [color string? (optional "black")])
            required])

(define products-toml
  (string-append*
   (add-between
    '("[[products]]"
      "name = \"Hammer\""
      "sku = 738594937"
      "color = \"red\""
      ""
      "[[products]]"
      "name = \"Nail\""
      "sku = 284758393")
     "\n")))

(products-schema (parse-toml products-toml))]

Arrays of tables can be nested:

@examples[#:eval s-ev
(define-toml-schema fruits-schema
  [fruits (array-of table
            [name string? required]
            [varieties (array-of table
                         [name string? required])
                       optional])
          required])

(define fruits-toml
  (string-append*
   (add-between
    '("[[fruits]]"
      "name = \"apple\""
      ""
      "[[fruits.varieties]]"
      "name = \"red delicious\""
      ""
      "[[fruits.varieties]]"
      "name = \"granny smith\""
      ""
      "[[fruits]]"
      "name = \"banana\"")
     "\n")))

(fruits-schema (parse-toml fruits-toml))]

}

@defstruct*[exn:fail:toml:validation
            ([message string?]
             [continuation-marks continuation-mark-set?]
             [key-path (listof symbol?)]
             [expected any/c]
             [actual any/c])
            #:extra-constructor-name make-exn:fail:toml:validation]{
Exception raised when TOML validation fails.

The @racket[key-path] field contains the path to the problematic key as a list of symbols
(e.g., @racket['(database host)] for @tt{database.host}).

The @racket[expected] and @racket[actual] fields contain the expected type/value and the actual
value that failed validation.
}

@subsection{Syntax reader}

@defmodule[toml/config/reader]

@defproc[(make-toml-syntax-reader [validator (-> hash? any/c)])
         (-> any/c input-port? syntax?)]{
Creates a @racket[read-syntax] function for a TOML reader.

The @racket[validator] is a @tech{validator} function (typically created with
@racket[define-toml-schema], but can be any function that takes a hash table). It's called on the
parsed TOML data before the module is created.

The returned function handles:
@itemlist[#:style 'compact
  @item{Reading the entire input port as a string}
  @item{Parsing the TOML using @racket[parse-toml]}
  @item{Running the validator, converting any parse and validation errors to syntax errors}
  @item{Generating a module that provides a @racket[toml] binding}
]

@racketblock[
(define-toml-schema my-schema
  [title string? required])

(define read-syntax
  (make-toml-syntax-reader my-schema))
]
}

@defproc[(get-info [in input-port?]
                   [mod-path module-path?]
                   [line (or/c #f exact-positive-integer?)]
                   [col (or/c #f exact-nonnegative-integer?)]
                   [pos (or/c #f exact-positive-integer?)])
         (-> any/c any/c any/c)]{

Returns a function that provides metadata about the TOML language to DrRacket and other tools.
Currently supports @racket['color-lexer] for TOML syntax highlighting in DrRacket.

This function is automatically provided by @racketmodname[toml/config/custom], but if you're
implementing a reader using the low-level APIs with a manual @racket[reader] submodule, you need to
@racket[provide] it yourself. This will ensure DrRacket applies sensible syntax coloring for your 
custom TOML @hash-lang[]s.


See @secref["language-get-info" #:doc '(lib "scribblings/guide/guide.scrbl")] for more information
about @racket[get-info] and reader extensions.
}
