#lang racket/base

(require rackunit
         racket/list
         toml/config/private/color-lexer)

  ;; Helper to lex a string and collect all tokens
  (define (lex-string str)
    (define port (open-input-string str))
    (port-count-lines! port)
    (let loop ([mode #f] [tokens '()])
      (define-values (lex type paren start end backup new-mode)
        (toml-color-lexer port 0 mode))
      (if (eq? type 'eof)
          (reverse tokens)
          (loop new-mode (cons (list lex type paren) tokens)))))
  
  ;; Test basic key = value
  (check-equal? 
   (map second (lex-string "name = \"value\""))
   '(symbol white-space other white-space string))
  
  ;; Test section header
  (check-equal?
   (map second (lex-string "[section]"))
   '(parenthesis hash-colon-keyword parenthesis))
  
  ;; Test dotted section header
  (check-equal?
   (map second (lex-string "[section.subsection]"))
   '(parenthesis hash-colon-keyword other hash-colon-keyword parenthesis))
  
  ;; Test comment
  (check-equal?
   (map second (lex-string "# this is a comment"))
   '(comment))
  
  ;; Test numbers
  (check-equal?
   (map second (lex-string "x = 42"))
   '(symbol white-space other white-space constant))
  
  ;; Test array
  (check-equal?
   (map second (lex-string "arr = [1, 2, 3]"))
   '(symbol white-space other white-space parenthesis constant other white-space 
     constant other white-space constant parenthesis))
  
  ;; Test inline table
  (check-equal?
   (map second (lex-string "tbl = {a = 1, b = 2}"))
   '(symbol white-space other white-space parenthesis symbol white-space other 
     white-space constant other white-space symbol white-space other white-space 
     constant parenthesis))
  
  ;; Test boolean value
  (check-equal?
   (map second (lex-string "flag = true"))
   '(symbol white-space other white-space constant))
  
  ;; Test boolean in inline table (verifies inline-value mode preserved after boolean)
  (check-equal?
   (map second (lex-string "x = {flag = true, other = 1}"))
   '(symbol white-space other white-space parenthesis symbol white-space other 
     white-space constant other white-space symbol white-space other white-space 
     constant parenthesis))
  
  ;; Test multiline structure
  (check-equal?
   (map second (lex-string "[section]\nkey = \"value\""))
   '(parenthesis hash-colon-keyword parenthesis white-space 
     symbol white-space other white-space string))
  
  ;; Test numeric-looking bare key (123e45 = "value")
  (check-equal?
   (map second (lex-string "123e45 = \"value\""))
   '(symbol white-space other white-space string))
  
  ;; Test date-looking bare key
  (check-equal?
   (map second (lex-string "1979-05-27 = \"value\""))
   '(symbol white-space other white-space string))
  
  ;; But numbers in value position are still constants
  (check-equal?
   (map second (lex-string "x = 123e45"))
   '(symbol white-space other white-space constant))
  
  ;; Numeric-looking key in inline table
  (check-equal?
   (map second (lex-string "x = {123 = 456}"))
   '(symbol white-space other white-space parenthesis symbol white-space other 
     white-space constant parenthesis))
  
  ;; Quoted key at top level
  (check-equal?
   (map second (lex-string "\"quoted key\" = \"value\""))
   '(symbol white-space other white-space string))
  
  ;; Quoted table name
  (check-equal?
   (map second (lex-string "[\"quoted table\"]"))
   '(parenthesis hash-colon-keyword parenthesis))
  
  ;; Mixed dotted table name with quoted parts
  (check-equal?
   (map second (lex-string "[bare.\"quoted\".bare]"))
   '(parenthesis hash-colon-keyword other hash-colon-keyword other hash-colon-keyword parenthesis))
  
  ;; Quoted key in inline table
  (check-equal?
   (map second (lex-string "x = {\"a\" = 1}"))
   '(symbol white-space other white-space parenthesis symbol white-space other 
     white-space constant parenthesis))
  
  ;; Literal quoted key (single quotes)
  (check-equal?
   (map second (lex-string "'literal key' = \"value\""))
   '(symbol white-space other white-space string))
  
  ;; Quoted array-of-tables name
  (check-equal?
   (map second (lex-string "[[\"quoted array\"]]"))
   '(parenthesis hash-colon-keyword parenthesis))
  
  ;; Nested arrays with strings - the [[ should NOT trigger section mode
  (check-equal?
   (map second (lex-string "data = [[\"delta\", \"phi\"]]"))
   '(symbol white-space other white-space parenthesis string other white-space string parenthesis))
  
  ;; Multiline array with nested array containing strings
  (check-equal?
   (map second (lex-string "x = [\n    [\"one\", \"two\"],\n]"))
   '(symbol white-space other white-space parenthesis white-space 
     parenthesis string other white-space string parenthesis other white-space parenthesis))
