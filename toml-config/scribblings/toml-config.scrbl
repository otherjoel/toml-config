#lang scribble/manual

@(require (for-label racket/base
                     racket/contract
                     toml))

@title[#:style 'toc]{TOML Config: Configuration Languages for Racket}
@author{Joel Dueck}

@hyperlink["https://toml.io/en/"]{TOML} (Tom’s Obvious Minimal Language) is a configuration file
format that’s easy to read due to obvious semantics.

Racket has a spec-compliant TOML parser in @racketmodlink[toml]{the @racketmodfont{toml} package}.
This package builds on that functionality to provide a @hash-lang[] for TOML documents, and
facilities for building your own custom @hash-lang[]s for TOML documents that validate their
contents against an expected schema. This can be useful to authors of Racket frameworks, when they
want users to be able to supply configuration data in a friendly syntax, that can also validate
itself at compile time.

Bug reports and contributions are welcome at
@hyperlink["https://github.com/otherjoel/toml-config"]{the GitHub repo}.

@local-table-of-contents[]

@include-section["usage.scrbl"]
@include-section["reference.scrbl"]
