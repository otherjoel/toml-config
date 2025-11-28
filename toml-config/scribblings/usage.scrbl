#lang scribble/manual

@(require racket/format
          scribble/example
          "doc-util.rkt"
          (for-label racket/base
                     racket/contract
                     toml/config
                     toml))

@title{Basic usage}

With this package installed, you can add @code{#lang toml/config} to the top of any TOML file to
make it a Racket module that parses its contents into a hash table.

Open DrRacket and create a new file with these contents:

@(define-values (example-display e1)
   @toml-example[#:filename "example.toml.rkt"]|{
# This is a TOML document
title = "TOML Example"

[database]
enabled = true
ports = [ 8000, 8001, 8002 ]
data = [ ["delta", "phi"], [3.14] ]
temp_targets = { cpu = 79.5, case = 72.0 }

}|)

@example-display

A @code{#lang toml/config} module parses its contents to a hash table and binds it to a
@racket[toml] identifier. To see this, press the @onscreen{▶️ Run} button in DrRacket and then
evaluate @racket[toml] as an expression in the REPL:

@examples[#:eval e1 #:label #f
          toml
          ]

Since @racket[toml] is a normal hash table, you can access its values using the normal functions:

@examples[#:eval e1 #:label #f
          (hash-ref toml 'title)
          ]

You can also use @racket[toml-ref] for easy access to values inside nested hash tables:

@examples[#:eval e1 #:label #f
          (toml-ref toml 'database.temp_targets.cpu)
          ]

@section{Importing data from TOML modules}

A @code{#lang toml/config} module @racket[provide]s its @racket[toml] binding. With the above TOML
file saved as @filepath{example.toml.rkt} you can create the following file in the same folder:

@racketmod[#:file "prog.rkt" racket/base

           (require toml/config "example.toml.rkt")
           ]

Running this file in DrRacket, you can use the imported @racket[toml] binding:

@examples[#:eval e1 #:label #f
          (toml-ref toml 'database.ports)
          ]

@section{Custom TOML @hash-lang[]s}

The functionality shown so far isn’t much more useful than simply running @racket[parse-toml] on a
normal @filepath{.toml} file, except that the files are nicer to edit in DrRacket.

What’s more interesting is using this library for quick customized @hash-lang[]s that validate their
contents.

@inline-note{You can create a new @hash-lang[] by putting a @racket[reader] submodule in a module file.
When a Racket file starts with @tt{#lang foo/bar}, Racket loads the @racket[reader] submodule from
@filepath{foo/bar.rkt} to parse the file. See @secref["hash-lang syntax" #:doc '(lib
"scribblings/guide/guide.scrbl")] for more info.}

As an example, below is the source for @filepath{config/demo.rkt}, which this package installs along
with its docs:

@racketmod[#:file "demo.rkt" racket/base

           (module reader toml/config/custom
             #:schema ([title string? required]
                       [port (integer-in 1 65535) (optional 8080)]))
           ]

Now a TOML module can use this custom @hash-lang[]:

@codeblock|{
#lang toml/config/demo

title = "My data"
}|

Examining the file’s @racket[toml] binding:

@(define e2 (make-base-eval))
@(e2 '(define toml (hasheq 'title "My data" 'port 8080)))
@examples[#:eval e2 #:label #f toml]

Note that the resulting hash table has a key for @racket['port] even though it wasn’t present in the
TOML source. This is because the schema in @filepath{demo.rkt} specified @tt{port} as @tt{optional}
and gave it a default value.

Changing the file so that the required @tt{title} key is no longer present:

@codeblock[#:keep-lang-line? #f]|{
#lang toml/config
BLOOP = "My data"
}|

Results in a compile-time error:

@(require toml/config/demo)
@errorblock*[
 (with-handlers
     ([exn:fail? (λ (e) (exn-message e))])
   (demo-schema (hasheq 'BLOOP "My data")))]

