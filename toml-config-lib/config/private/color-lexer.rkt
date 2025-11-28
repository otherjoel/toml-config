#lang racket/base

;; Rudimentary color lexer for TOML syntax
;; Provides enough syntax highlighting for #lang toml/config files in DrRacket that they don't look like ass

(provide toml-color-lexer)

;; Token types recognized by DrRacket's syntax colorer
;; 'comment
;; 'string
;; 'constant
;; 'parenthesis
;; 'symbol
;; 'other
;; 'sexp-comment
;; 'white-space
;; 'no-color
;; 'hash-colon-keyword

(require brag/support
         br-parser-tools/lex)

(define-lex-abbrev key-name (:+ (:or (:/ "az" "AZ" "09") "_" "-" " " ".")))
(define-lex-abbrev key (:seq "\n" (:* whitespace)
                                  "[" (:? "\"") key-name (:? "\"") "]"
                                  (:* (:- whitespace "\n")) "\n"))

(define toml-color-lexer
  (lexer
   [(eof) (values lexeme 'eof #f #f #f)]
   [key
    (values lexeme 'symbol #f (pos lexeme-start) (pos lexeme-end))]
   [(from/stop-before "#" "\n")
    (values lexeme 'comment #f (pos lexeme-start) (pos lexeme-end))]
   [(:or "[" "]" "{" "}")
    (values lexeme 'parenthesis (if (member lexeme '("{" "[")) '|(| '|)|) (pos lexeme-start) (pos lexeme-end))]
   [(:or "=" ",")
    (values lexeme 'other #f (pos lexeme-start) (pos lexeme-end))]
   [any-char
    (values lexeme 'constant #f
            (pos lexeme-start) (pos lexeme-end))]))


