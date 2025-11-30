#lang racket/base
;; Improved color lexer for TOML syntax
;; Provides syntax highlighting for #lang toml/config files in DrRacket
;; Uses mode tracking to distinguish keys (left of =) from values (right of =)

(provide toml-color-lexer)

(require brag/support
         br-parser-tools/lex
         (prefix-in : br-parser-tools/lex-sre)
         racket/list)

;; Token types recognized by DrRacket's syntax colorer:
;; 'comment          - for comments (# to end of line)
;; 'string           - for string literals ("..." and '...')
;; 'constant         - for constants (numbers, booleans, dates)
;; 'parenthesis      - for brackets and braces (can specify matching)
;; 'symbol           - for keys (identifiers on left side of =)
;; 'hash-colon-keyword - for section header names (more emphasis)
;; 'other            - for operators like = and ,
;; 'white-space      - for whitespace
;; 'no-color         - no special coloring
;; 'error            - for errors (unclosed strings, etc.)

;; Mode values for tracking parser state:
;; 'start        - at start of line or after newline (expecting key or section header)
;; 'key          - after seeing a key, expecting = (top-level or array context)
;; 'value        - inside a value context (right side of = at top level, or in array)
;; 'section      - inside a section header [...]
;; 'inline-key   - expecting a key inside an inline table { }
;; 'inline-value - expecting a value inside an inline table (after = in inline table)

;; ============================================================================
;; Lexer Abbreviations
;; ============================================================================

;; Basic character classes
(define-lex-abbrev digit (:/ "09"))
(define-lex-abbrev hex-digit (:or digit (:/ "af") (:/ "AF")))
(define-lex-abbrev octal-digit (:/ "07"))
(define-lex-abbrev binary-digit (:or "0" "1"))

;; Bare key characters (alphanumeric, underscore, hyphen)
(define-lex-abbrev bare-key-char (:or (:/ "az" "AZ" "09") "_" "-"))
(define-lex-abbrev bare-key (:+ bare-key-char))

;; Whitespace (not including newlines - they're significant for mode tracking)
(define-lex-abbrev ws (:+ (:or " " "\t")))

;; Newlines (including Windows CRLF)
(define-lex-abbrev newline (:or "\n" "\r\n" "\r"))

;; Integer patterns
(define-lex-abbrev dec-int (:seq (:? (:or "+" "-")) 
                                 (:or "0" 
                                      (:seq (:/ "19") (:* (:or digit "_"))))))
(define-lex-abbrev hex-int (:seq "0x" hex-digit (:* (:or hex-digit "_"))))
(define-lex-abbrev oct-int (:seq "0o" octal-digit (:* (:or octal-digit "_"))))
(define-lex-abbrev bin-int (:seq "0b" binary-digit (:* (:or binary-digit "_"))))

;; Float patterns  
(define-lex-abbrev float-int-part (:seq (:? (:or "+" "-"))
                                        (:or "0" (:seq (:/ "19") (:* (:or digit "_"))))))
(define-lex-abbrev frac (:seq "." (:+ (:or digit "_"))))
(define-lex-abbrev exp (:seq (:or "e" "E") (:? (:or "+" "-")) (:+ (:or digit "_"))))
(define-lex-abbrev float-val (:or (:seq float-int-part (:or frac (:seq frac exp) exp))
                                  (:seq (:? (:or "+" "-")) (:or "inf" "nan"))))

;; Date/time patterns (simplified - just enough for coloring)
(define-lex-abbrev date-fullyear (:= 4 digit))
(define-lex-abbrev date-month (:= 2 digit))
(define-lex-abbrev date-mday (:= 2 digit))
(define-lex-abbrev time-hour (:= 2 digit))
(define-lex-abbrev time-minute (:= 2 digit))
(define-lex-abbrev time-second (:= 2 digit))
(define-lex-abbrev time-secfrac (:seq "." (:+ digit)))

(define-lex-abbrev full-date (:seq date-fullyear "-" date-month "-" date-mday))
(define-lex-abbrev partial-time (:seq time-hour ":" time-minute ":" time-second (:? time-secfrac)))
(define-lex-abbrev time-offset (:or "Z" "z" (:seq (:or "+" "-") time-hour ":" time-minute)))
(define-lex-abbrev full-time (:seq partial-time (:? time-offset)))
(define-lex-abbrev datetime (:or (:seq full-date (:or "T" "t" " ") full-time)
                                 (:seq full-date (:or "T" "t" " ") partial-time)
                                 full-date
                                 partial-time))

;;------------------------------------------------
;; Combined Lexer Abbreviations  

;; All number formats combined - lexer picks longest match
(define-lex-abbrev number-literal
  (:or hex-int oct-int bin-int float-val dec-int))

;; All string formats combined - lexer picks longest match,
;; so """...""" beats "..." automatically
(define-lex-abbrev basic-string
  (:or (from/to "\"\"\"" "\"\"\"")                          ; multi-line basic
       (:seq "\"" (:* (:or (:~ "\"" "\\") 
                           (:seq "\\" any-char))) "\"")))   ; single-line basic

(define-lex-abbrev literal-string  
  (:or (from/to "'''" "'''")                                ; multi-line literal
       (:seq "'" (:* (:~ "'")) "'")))                       ; single-line literal

;;================================================
;; Helper functions

(define (pos p)
  (position-offset p))

(define (->value-mode mode)
  (case mode
    [(section inline-value) mode]
    [else 'value]))

(define (->numeric-mode mode)
  (if (eq? mode 'inline-value) 'inline-value 'value))

;;================================================


;;================================================
;; Main Color Lexer  

;; DrRacket color lexer interface:
;; Takes: (port offset mode) where mode tracks parser state across calls
;; Returns: (values lexeme type paren start end backup new-mode)
;;
;; The 7-value interface allows:
;; - backup: tells DrRacket how far back to re-lex on edits (0 = just this token)
;; - new-mode: state to pass to next lexer call (our key/value tracking)

(define (toml-color-lexer port offset mode)
  (define current-mode (or mode 'start))
  (define-values (lexeme type paren start-pos end-pos new-mode)
    ((make-toml-lexer current-mode) port))
  (values lexeme type paren start-pos end-pos 0 new-mode))

;; Factory function that creates a lexer configured for the current mode
;; This pattern lets us make decisions based on mode while staying within
;; the lexer DSL
(define (make-toml-lexer mode)
  (lexer
   ;; === End of file ===
   [(eof) 
    (values lexeme 'eof #f #f #f mode)]
   
   ;; === Comments - # to end of line ===
   ;; High priority - comments can appear almost anywhere
   [(from/stop-before "#" "\n")
    (values lexeme 'comment #f (pos start-pos) (pos end-pos) mode)]
   
   ;; === Newlines reset to start-of-line mode ===
   [newline
    (values lexeme 'white-space #f (pos start-pos) (pos end-pos) 'start)]
   
   ;; === Whitespace preserves current mode ===
   [ws
    (values lexeme 'white-space #f (pos start-pos) (pos end-pos) mode)]
   
   ;; === Array of tables [[name]] - must come before single [ ===
   ["[["
    (values lexeme 'parenthesis '|(| (pos start-pos) (pos end-pos) 'section)]
   
   ["]]"
    (values lexeme 'parenthesis '|)| (pos start-pos) (pos end-pos) 'start)]
   
   ;; === Section header or array start [ ===
   ;; Context-dependent: at line start = section header, otherwise = array
   ["["
    (cond
      [(memq mode '(start key))
       ;; Beginning a section header like [section.name]
       (values lexeme 'parenthesis '|(| (pos start-pos) (pos end-pos) 'section)]
      [else
       ;; Beginning an array value like [1, 2, 3]
       (values lexeme 'parenthesis '|[| (pos start-pos) (pos end-pos) 'value)])]
   
   ;; === Array/section end ] ===
   ["]"
    (cond
      [(eq? mode 'section)
       ;; Ending a section header - go back to start mode
       (values lexeme 'parenthesis '|)| (pos start-pos) (pos end-pos) 'start)]
      [else
       ;; Ending an array - stay in value mode
       (values lexeme 'parenthesis '|]| (pos start-pos) (pos end-pos) mode)])]
   
   ;; === Inline table { } ===
   ["{"
    ;; Inline tables contain key-value pairs, so switch to inline-key mode
    (values lexeme 'parenthesis '|{| (pos start-pos) (pos end-pos) 'inline-key)]
   
   ["}"
    ;; End of inline table returns to value mode (it's a value itself)
    (values lexeme 'parenthesis '|}| (pos start-pos) (pos end-pos) 'value)]
   
   ;; === Equals sign - the key/value separator ===
   ["="
    ;; If we're in inline-key mode, stay in inline context
    (values lexeme 'other #f (pos start-pos) (pos end-pos) 
            (if (eq? mode 'inline-key) 'inline-value 'value))]
   
   ;; === Comma separator ===
   ;; In inline tables (inline-value mode): next element is a key
   ;; In arrays (value mode): next element is a value
   [","
    (values lexeme 'other #f (pos start-pos) (pos end-pos) 
            (if (eq? mode 'inline-value) 'inline-key 'value))]
   
   ;; === Dot for dotted keys/sections ===
   ["."
    (values lexeme 'other #f (pos start-pos) (pos end-pos) mode)]
   
   ;; === All string literals (basic and literal, single and multi-line) ===
   ;; In key/section context, treat as key identifier rather than string value
   [basic-string
    (values lexeme 
            (case mode
              [(start key inline-key) 'symbol]
              [(section) 'hash-colon-keyword]
              [else 'string])
            #f (pos start-pos) (pos end-pos) 
            (if (eq? mode 'start) 'key (->value-mode mode)))]
   
   [literal-string
    (values lexeme 
            (case mode
              [(start key inline-key) 'symbol]
              [(section) 'hash-colon-keyword]
              [else 'string])
            #f (pos start-pos) (pos end-pos) 
            (if (eq? mode 'start) 'key (->value-mode mode)))]
   
   ;; === Unclosed strings - color as error ===
   [(:seq "\"" (:* (:or (:~ "\"" "\\" "\n") (:seq "\\" any-char))))
    (values lexeme 'error #f (pos start-pos) (pos end-pos) mode)]
   
   [(:seq "'" (:* (:~ "'" "\n")))
    (values lexeme 'error #f (pos start-pos) (pos end-pos) mode)]
   
   ;; === Booleans (true/false) ===
   ;; In value context: constant; in key context: could be a bare key
   ;; Mode transition same as bare-key since booleans can be valid key names
   [(:or "true" "false")
    (values lexeme 
            (case mode
              [(value inline-value) 'constant]
              [(section) 'hash-colon-keyword]
              [else 'symbol])
            #f (pos start-pos) (pos end-pos)
            (if (eq? mode 'start) 'key mode))]
   
   ;; === DateTime values ===
   ;; Must be checked before bare keys since they start with digits
   ;; But in key context, treat as a key (e.g., 1979-05-27 = "value")
   [datetime
    (values lexeme 
            (if (memq mode '(start key inline-key)) 'symbol 'constant)
            #f (pos start-pos) (pos end-pos) 
            (if (eq? mode 'start) 'key (->value-mode mode)))]
   
   ;; === All numeric literals (int, float, hex, octal, binary) ===
   ;; In key context, treat as a key (e.g., 123e45 = "value")
   [number-literal
    (values lexeme 
            (if (memq mode '(start key inline-key)) 'symbol 'constant)
            #f (pos start-pos) (pos end-pos) 
            (if (eq? mode 'start) 'key (->numeric-mode mode)))]
   
   ;; === Bare keys / identifiers ===
   ;; Mode-tracking provides context-appropriate coloring:
   ;; - Key position (start, key, inline-key): 'symbol
   ;; - Section header: 'hash-colon-keyword  
   ;; - Value context: 'constant (fallback, shouldn't occur in valid TOML)
   [bare-key
    (values lexeme
            (case mode
              [(start key inline-key) 'symbol]
              [(section) 'hash-colon-keyword]
              [else 'constant])
            #f (pos start-pos) (pos end-pos)
            (if (eq? mode 'start) 'key mode))]
   
   ;; === Catch-all for any other character ===
   ;; Prevents lexer from raising errors on unexpected input
   [any-char
    (values lexeme 'no-color #f (pos start-pos) (pos end-pos) mode)]))
