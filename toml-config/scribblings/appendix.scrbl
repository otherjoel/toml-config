#lang scribble/manual

@(require racket/file
          racket/runtime-path
          scribble/examples
          (for-syntax racket/base
                      toml
                      toml/config
                      toml/config/demo
                      toml/config/schema))

@title[#:style 'quiet]{Appendix}

@section{Complete TOML Syntax demo}

Below is a @hash-lang[] @racketmodname[toml/config] module which makes comprehensive use of all forms
of TOML syntax, followed by the a readout of the resulting hash table bound to @racket[toml].

@codeblock{
@(file->string (collection-file-path "toml-syntax-coverage.rkt" "toml" "scribblings"))
}

@(define tsc-ev (make-base-eval))
@(tsc-ev '(require gregor toml/scribblings/toml-syntax-coverage))
@examples[#:eval tsc-ev toml]

@section{Demo language}

@defmodule[toml/config/demo]

This is a DSL installed alongside these docs for demonstration purposes. Its definition is shown
below:

@racketmod[#:file "toml/config/demo.rkt"
racket/base

(module reader toml/config/custom
 #:schema ([title string? required]
           [port (integer-in 1 65535) (optional 8080)]))
]
