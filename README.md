# toml-config

Use [TOML](https://toml.io/) files as Racket configuration modules with
compile-time schema validation.

Install with `raco pkg install toml-config` (or `toml-config-lib to omit docs).

**Documentation is at: <https://joeldueck.com/what-about/toml-config>**

## What is this?

This package lets you turn TOML files into Racket modules by adding `#lang
toml/config` at the top. The TOML data is parsed and provided as a hash table
that other modules can require and use.

More importantly, it provides a framework for creating custom configuration
languages with validated schemas. You can define domain-specific `#lang`
dialects that enforce required keys, type constraints, and default
values—catching configuration errors at compile time rather than runtime.

Parsing is all handled by the [`toml`
package](https://docs.racket-lang.org/toml/index.html) written by Greg
Hendershott, Winston Weinert, and Benjamin Yeung.

## Where is this useful?

**Application configuration**: Racket programs can use TOML config files with
validated settings, ensuring configuration mistakes are caught before the
program runs.

**Embedded DSLs**: Library authors can create specialized configuration
languages that use TOML syntax but add their own validation rules, types, and
constraints specific to their domain.

## Documentation

Full documentation: `raco docs toml-config`
