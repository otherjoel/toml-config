#lang racket/base

(require rackunit
         racket/contract
         racket/list
         toml/config/schema
         toml/config/reader
         toml/config)

;;; Basic Schema Validation Tests

(define-toml-schema simple-schema
  [title string? required]
  [version string? required])

(test-case "simple-schema: valid data"
  (define data (hasheq 'title "Test" 'version "1.0"))
  (check-not-exn (lambda () (simple-schema data))))

(test-case "simple-schema: missing required field"
  (define data (hasheq 'title "Test"))
  (check-exn exn:fail:toml:validation?
             (lambda () (simple-schema data))))

(test-case "simple-schema: wrong type"
  (define data (hasheq 'title 123 'version "1.0"))
  (check-exn exn:fail:toml:validation?
             (lambda () (simple-schema data))))

;;; Optional Fields with Defaults

(define-toml-schema with-defaults-schema
  [title string? required]
  [port integer? (optional 8080)])

(test-case "with-defaults: default applied when missing"
  (define data (hasheq 'title "Test"))
  (define result (with-defaults-schema data))
  (check-equal? (hash-ref result 'port) 8080))

(test-case "with-defaults: explicit value preserved"
  (define data (hasheq 'title "Test" 'port 3000))
  (define result (with-defaults-schema data))
  (check-equal? (hash-ref result 'port) 3000))

(test-case "with-defaults: wrong type for optional field"
  (define data (hasheq 'title "Test" 'port "not-a-number"))
  (check-exn exn:fail:toml:validation?
             (lambda () (with-defaults-schema data))))

;;; Optional Fields without Defaults

(define-toml-schema with-optional-schema
  [title string? required]
  [description string? optional])

(test-case "with-optional: missing optional field is OK"
  (define data (hasheq 'title "Test"))
  (check-not-exn (lambda () (with-optional-schema data))))

(test-case "with-optional: present optional field validated"
  (define data (hasheq 'title "Test" 'description 123))
  (check-exn exn:fail:toml:validation?
             (lambda () (with-optional-schema data))))

;;; Multiple Type Predicates

(define (port-range? n)
  (and (>= n 1) (<= n 65535)))

(define-toml-schema multi-validator-schema
  [port integer? port-range? required])

(test-case "multi-validator: all predicates pass"
  (define data (hasheq 'port 8080))
  (check-not-exn (lambda () (multi-validator-schema data))))

(test-case "multi-validator: first predicate fails"
  (define data (hasheq 'port "8080"))
  (check-exn exn:fail:toml:validation?
             (lambda () (multi-validator-schema data))))

(test-case "multi-validator: second predicate fails"
  (define data (hasheq 'port 99999))
  (check-exn exn:fail:toml:validation?
             (lambda () (multi-validator-schema data))))

;;; Contracts as Type Specs

(define-toml-schema contract-schema
  [port (integer-in 1 65535) required]
  [tags (listof string?) optional])

(test-case "contract: integer-in passes"
  (define data (hasheq 'port 8080))
  (check-not-exn (lambda () (contract-schema data))))

(test-case "contract: integer-in fails (out of range)"
  (define data (hasheq 'port 99999))
  (check-exn exn:fail:toml:validation?
             (lambda () (contract-schema data))))

(test-case "contract: integer-in fails (wrong type)"
  (define data (hasheq 'port "8080"))
  (check-exn exn:fail:toml:validation?
             (lambda () (contract-schema data))))

(test-case "contract: listof passes"
  (define data (hasheq 'port 8080 'tags '("web" "api")))
  (check-not-exn (lambda () (contract-schema data))))

(test-case "contract: listof fails"
  (define data (hasheq 'port 8080 'tags '("web" 123)))
  (check-exn exn:fail:toml:validation?
             (lambda () (contract-schema data))))

(test-case "contract: listof fails (not a list)"
  (define data (hasheq 'port 8080 'tags "not-a-list"))
  (check-exn exn:fail:toml:validation?
             (lambda () (contract-schema data))))

;;; Nested Tables

(define-toml-schema nested-schema
  [title string? required]
  [database (table
              [host string? required]
              [port integer? required])])

(test-case "nested: valid nested table"
  (define data (hasheq 'title "App"
                       'database (hasheq 'host "localhost" 'port 5432)))
  (check-not-exn (lambda () (nested-schema data))))

(test-case "nested: missing nested table"
  (define data (hasheq 'title "App"))
  (check-exn exn:fail:toml:validation?
             (lambda () (nested-schema data))))

(test-case "nested: nested table is not a hash"
  (define data (hasheq 'title "App" 'database "not-a-table"))
  (check-exn exn:fail:toml:validation?
             (lambda () (nested-schema data))))

(test-case "nested: missing field in nested table"
  (define data (hasheq 'title "App"
                       'database (hasheq 'host "localhost")))
  (check-exn exn:fail:toml:validation?
             (lambda () (nested-schema data))))

(test-case "nested: wrong type in nested table field"
  (define data (hasheq 'title "App"
                       'database (hasheq 'host "localhost" 'port "not-a-number")))
  (check-exn exn:fail:toml:validation?
             (lambda () (nested-schema data))))

;;; Optional Tables

(define-toml-schema optional-table-schema
  [title string? required]
  [database (table
              [host string? required]
              [port integer? required])
            optional])

(test-case "optional-table: valid with table present"
  (define data (hasheq 'title "App"
                       'database (hasheq 'host "localhost" 'port 5432)))
  (check-not-exn (lambda () (optional-table-schema data))))

(test-case "optional-table: valid with table missing"
  (define data (hasheq 'title "App"))
  (check-not-exn (lambda () (optional-table-schema data))))

(test-case "optional-table: validates when present"
  (define data (hasheq 'title "App"
                       'database (hasheq 'host "localhost")))
  (check-exn exn:fail:toml:validation?
             (lambda () (optional-table-schema data))))

(test-case "optional-table: wrong type rejected"
  (define data (hasheq 'title "App" 'database "not-a-table"))
  (check-exn exn:fail:toml:validation?
             (lambda () (optional-table-schema data))))

;;; Elaborate schemas

(define-toml-schema elaborate-schema
    [name string? required]
    [age (integer-in 0 150) required]
    [email string? optional]
    [admin boolean? (optional #f)]
    [settings (table
                [theme string? required]
                [notifications boolean? (optional #t)])])

(test-case "elaborate: all optional values appplied"
  (define data (hasheq 'name "Alice"
                       'age 30
                       'settings (hasheq 'theme "red")))
  (check-equal? (elaborate-schema data)
                (hasheq 'name "Alice"
                       'age 30
                       'admin #f
                       'settings (hasheq 'theme "red" 'notifications #t))))

(test-case "elaborate: age out of range fails"
  (define data (hasheq 'name "Alice"
                       'age 200
                       'settings (hasheq 'theme "red")))
  (check-exn exn:fail:toml:validation?
             (lambda () (elaborate-schema data))))

(test-case "elaborate: missing nested table fails"
  (define data (hasheq 'name "Alice"
                       'age 30))
  (check-exn exn:fail:toml:validation?
             (lambda () (elaborate-schema data))))

(test-case "elaborate: wrong type in nested table field fails"
  (define data (hasheq 'name "Alice"
                       'age 30
                       'settings (hasheq 'theme 123)))
  (check-exn exn:fail:toml:validation?
             (lambda () (elaborate-schema data))))

(test-case "elaborate: wrong type for optional field with default fails"
  (define data (hasheq 'name "Alice"
                       'age 30
                       'admin "not-a-boolean"
                       'settings (hasheq 'theme "red")))
  (check-exn exn:fail:toml:validation?
             (lambda () (elaborate-schema data))))

;;; Procedural Validation

(define simple-proc-validator
  (lambda (toml-data)
    (unless (hash-has-key? toml-data 'title)
      (validation-error '() "missing title field"))
    (unless (string? (hash-ref toml-data 'title))
      (validation-error '(title) "must be a string"))))

(test-case "procedural: valid data"
  (define data (hasheq 'title "Test"))
  (check-not-exn (lambda () (simple-proc-validator data))))

(test-case "procedural: validation fails"
  (define data (hasheq 'title 123))
  (check-exn exn:fail:toml:validation?
             (lambda () (simple-proc-validator data))))

;;; Arrays of Tables

(define-toml-schema products-schema
  [products (array-of table
              [name string? required]
              [sku integer? required]
              [color string? optional])
            required])

(test-case "array-of-tables: valid array with all fields"
  (define data (hasheq 'products
                       (list (hasheq 'name "Hammer" 'sku 738594937 'color "red")
                             (hasheq 'name "Nail" 'sku 284758393 'color "gray"))))
  (check-not-exn (lambda () (products-schema data))))

(test-case "array-of-tables: valid array with optional field missing"
  (define data (hasheq 'products
                       (list (hasheq 'name "Hammer" 'sku 738594937)
                             (hasheq 'name "Nail" 'sku 284758393))))
  (check-not-exn (lambda () (products-schema data))))

(test-case "array-of-tables: valid empty array"
  (define data (hasheq 'products '()))
  (check-not-exn (lambda () (products-schema data))))

(test-case "array-of-tables: missing required array"
  (define data (hasheq))
  (check-exn exn:fail:toml:validation?
             (lambda () (products-schema data))))

(test-case "array-of-tables: not a list"
  (define data (hasheq 'products "not-a-list"))
  (check-exn exn:fail:toml:validation?
             (lambda () (products-schema data))))

(test-case "array-of-tables: element not a table"
  (define data (hasheq 'products
                       (list (hasheq 'name "Hammer" 'sku 738594937)
                             "not-a-table")))
  (check-exn exn:fail:toml:validation?
             (lambda () (products-schema data))))

(test-case "array-of-tables: missing required field in element"
  (define data (hasheq 'products
                       (list (hasheq 'name "Hammer" 'sku 738594937)
                             (hasheq 'name "Nail"))))
  (check-exn exn:fail:toml:validation?
             (lambda () (products-schema data))))

(test-case "array-of-tables: wrong type in element field"
  (define data (hasheq 'products
                       (list (hasheq 'name "Hammer" 'sku 738594937)
                             (hasheq 'name 123 'sku 284758393))))
  (check-exn exn:fail:toml:validation?
             (lambda () (products-schema data))))

;;; Arrays of Tables with Defaults

(define-toml-schema products-with-defaults-schema
  [products (array-of table
              [name string? required]
              [sku integer? required]
              [color string? (optional "black")]
              [quantity integer? (optional 1)])
            optional])

(test-case "array-of-tables-defaults: defaults applied to elements"
  (define data (hasheq 'products
                       (list (hasheq 'name "Hammer" 'sku 738594937)
                             (hasheq 'name "Nail" 'sku 284758393 'color "gray"))))
  (define result (products-with-defaults-schema data))
  (check-equal? (toml-ref result 'products 0 'color) "black")
  (check-equal? (toml-ref result 'products 0 'quantity) 1)
  (check-equal? (toml-ref result 'products 1 'color) "gray")
  (check-equal? (toml-ref result 'products 1 'quantity) 1))

(test-case "array-of-tables-defaults: optional array missing is OK"
  (define data (hasheq))
  (check-not-exn (lambda () (products-with-defaults-schema data))))

;;; Nested Arrays of Tables

(define-toml-schema fruits-schema
  [fruits (array-of table
            [name string? required]
            [physical (table
                        [color string? required]
                        [shape string? required])]
            [varieties (array-of table
                         [name string? required])
                       optional])
          required])

(test-case "nested-array-of-tables: valid nested structure"
  (define data (hasheq 'fruits
                       (list (hasheq 'name "apple"
                                     'physical (hasheq 'color "red" 'shape "round")
                                     'varieties (list (hasheq 'name "red delicious")
                                                     (hasheq 'name "granny smith")))
                             (hasheq 'name "banana"
                                     'physical (hasheq 'color "yellow" 'shape "curved")
                                     'varieties (list (hasheq 'name "plantain"))))))
  (check-not-exn (lambda () (fruits-schema data))))

(test-case "nested-array-of-tables: valid without optional nested array"
  (define data (hasheq 'fruits
                       (list (hasheq 'name "apple"
                                     'physical (hasheq 'color "red" 'shape "round")))))
  (check-not-exn (lambda () (fruits-schema data))))

(test-case "nested-array-of-tables: missing required field in nested table"
  (define data (hasheq 'fruits
                       (list (hasheq 'name "apple"
                                     'physical (hasheq 'color "red")))))
  (check-exn exn:fail:toml:validation?
             (lambda () (fruits-schema data))))

(test-case "nested-array-of-tables: wrong type in nested array element"
  (define data (hasheq 'fruits
                       (list (hasheq 'name "apple"
                                     'physical (hasheq 'color "red" 'shape "round")
                                     'varieties (list (hasheq 'name 123))))))
  (check-exn exn:fail:toml:validation?
             (lambda () (fruits-schema data))))

(test-case "nested-array-of-tables: nested array not a list"
  (define data (hasheq 'fruits
                       (list (hasheq 'name "apple"
                                     'physical (hasheq 'color "red" 'shape "round")
                                     'varieties "not-a-list"))))
  (check-exn exn:fail:toml:validation?
             (lambda () (fruits-schema data))))

(test-case "nested-array-of-tables: missing required field in array element"
  (define data (hasheq 'fruits
                       (list (hasheq 'name "apple"
                                     'physical (hasheq 'color "red" 'shape "round")
                                     'varieties (list (hasheq 'name "red delicious")
                                                     (hasheq))))))
  (check-exn exn:fail:toml:validation?
             (lambda () (fruits-schema data))))

(test-case "nested-array-of-tables: element in nested array not a table"
  (define data (hasheq 'fruits
                       (list (hasheq 'name "apple"
                                     'physical (hasheq 'color "red" 'shape "round")
                                     'varieties (list "not-a-table")))))
  (check-exn exn:fail:toml:validation?
             (lambda () (fruits-schema data))))

;;; Arrays of Tables with Multiple Validators

(define (valid-sku? n)
  (and (>= n 100000) (<= n 999999999)))

(define-toml-schema products-multi-validator-schema
  [products (array-of table
              [name string? required]
              [sku integer? valid-sku? required])
            required])

(test-case "array-of-tables-multi: all validators pass"
  (define data (hasheq 'products
                       (list (hasheq 'name "Hammer" 'sku 738594937))))
  (check-not-exn (lambda () (products-multi-validator-schema data))))

(test-case "array-of-tables-multi: second validator fails in element"
  (define data (hasheq 'products
                       (list (hasheq 'name "Hammer" 'sku 123))))
  (check-exn exn:fail:toml:validation?
             (lambda () (products-multi-validator-schema data))))

;;; Arrays of Tables with Contracts

(define-toml-schema products-contract-schema
  [products (array-of table
              [name string? required]
              [sku (integer-in 100000 999999999) required]
              [tags (listof string?) optional])
            required])

(test-case "array-of-tables-contract: integer-in passes"
  (define data (hasheq 'products
                       (list (hasheq 'name "Hammer" 'sku 738594937))))
  (check-not-exn (lambda () (products-contract-schema data))))

(test-case "array-of-tables-contract: integer-in fails in element"
  (define data (hasheq 'products
                       (list (hasheq 'name "Hammer" 'sku 123))))
  (check-exn exn:fail:toml:validation?
             (lambda () (products-contract-schema data))))

(test-case "array-of-tables-contract: listof passes in element"
  (define data (hasheq 'products
                       (list (hasheq 'name "Hammer" 'sku 738594937 'tags '("tool" "hardware")))))
  (check-not-exn (lambda () (products-contract-schema data))))

(test-case "array-of-tables-contract: listof fails in element"
  (define data (hasheq 'products
                       (list (hasheq 'name "Hammer" 'sku 738594937 'tags '("tool" 123)))))
  (check-exn exn:fail:toml:validation?
             (lambda () (products-contract-schema data))))

;;; make-toml-syntax-reader

(test-case "make-toml-syntax-reader: requires procedure"
  (check-exn exn:fail?
             (lambda () (make-toml-syntax-reader "not-a-proc"))))

(test-case "make-toml-syntax-reader: returns procedure"
  (define reader (make-toml-syntax-reader simple-proc-validator))
  (check-pred procedure? reader))

;;; Transformer Predicates

;; readable-datum? basic behavior tests
(test-case "readable-datum?: valid s-expression"
  (check-equal? (unbox (readable-datum? "(+ 1 2)")) '(+ 1 2)))

(test-case "readable-datum?: valid symbol"
  (check-equal? (unbox (readable-datum? "hello")) 'hello))

(test-case "readable-datum?: valid number"
  (check-equal? (unbox (readable-datum? "42")) 42))

(test-case "readable-datum?: valid list"
  (check-equal? (unbox (readable-datum? "(list 1 2 3)")) '(list 1 2 3)))

(test-case "readable-datum?: valid quoted data"
  (check-equal? (unbox (readable-datum? "'(a b c)")) ''(a b c)))

(test-case "readable-datum?: valid hash"
  (check-equal? (unbox (readable-datum? "#hash((a . 1))")) #hash((a . 1))))

(test-case "readable-datum?: valid vector"
  (check-equal? (unbox (readable-datum? "#(1 2 3)")) #(1 2 3)))

;; Boolean edge cases - these are critical
(test-case "readable-datum?: #f is valid datum (returns boxed #f)"
  (define result (readable-datum? "#f"))
  (check-pred box? result)
  (check-equal? (unbox result) #f))

(test-case "readable-datum?: #t is valid datum"
  (define result (readable-datum? "#t"))
  (check-pred box? result)
  (check-equal? (unbox result) #t))

(test-case "readable-datum?: #true is valid datum"
  (check-equal? (unbox (readable-datum? "#true")) #t))

(test-case "readable-datum?: #false is valid datum"
  (check-equal? (unbox (readable-datum? "#false")) #f))

;; Failure cases
(test-case "readable-datum?: non-string returns #f"
  (check-false (readable-datum? 123)))

(test-case "readable-datum?: incomplete expression returns #f"
  (check-false (readable-datum? "(incomplete")))

(test-case "readable-datum?: extra content returns #f"
  (check-false (readable-datum? "42 extra")))

(test-case "readable-datum?: empty string returns #f"
  (check-false (readable-datum? "")))

(test-case "readable-datum?: whitespace only returns #f"
  (check-false (readable-datum? "   ")))

(test-case "readable-datum?: unbalanced parens returns #f"
  (check-false (readable-datum? "(()")))

;;; Transformer Predicates in Schemas

(define-toml-schema transform-schema
  [expr string? readable-datum? required]
  [name string? required])

(test-case "transform-schema: transforms string to datum"
  (define data (hasheq 'expr "(lambda (x) x)" 'name "identity"))
  (define result (transform-schema data))
  (check-equal? (hash-ref result 'expr) '(lambda (x) x))
  (check-equal? (hash-ref result 'name) "identity"))

(test-case "transform-schema: #f datum is correctly transformed"
  (define data (hasheq 'expr "#f" 'name "false-value"))
  (define result (transform-schema data))
  (check-equal? (hash-ref result 'expr) #f))

(test-case "transform-schema: #t datum is correctly transformed"
  (define data (hasheq 'expr "#t" 'name "true-value"))
  (define result (transform-schema data))
  (check-equal? (hash-ref result 'expr) #t))

(test-case "transform-schema: fails on non-string"
  (define data (hasheq 'expr 123 'name "test"))
  (check-exn exn:fail:toml:validation?
             (lambda () (transform-schema data))))

(test-case "transform-schema: fails on unreadable string"
  (define data (hasheq 'expr "(incomplete" 'name "test"))
  (check-exn exn:fail:toml:validation?
             (lambda () (transform-schema data))))

;;; Chained transformers

(define (double-if-number v)
  (if (number? v) (* v 2) #f))

(define-toml-schema chain-transform-schema
  [value string? readable-datum? double-if-number required])

(test-case "chain-transform: string -> datum -> doubled number"
  (define data (hasheq 'value "21"))
  (define result (chain-transform-schema data))
  (check-equal? (hash-ref result 'value) 42))

(test-case "chain-transform: fails if datum is not a number"
  (define data (hasheq 'value "'symbol"))
  (check-exn exn:fail:toml:validation?
             (lambda () (chain-transform-schema data))))

;;; Transformers in nested tables

(define-toml-schema nested-transform-schema
  [config (table
            [filter-expr string? readable-datum? required]
            [name string? required])])

(test-case "nested-transform: transforms in nested table"
  (define data (hasheq 'config (hasheq 'filter-expr "(> x 10)" 'name "threshold")))
  (define result (nested-transform-schema data))
  (check-equal? (toml-ref result 'config.filter-expr) '(> x 10)))

;;; Transformers in arrays of tables

(define-toml-schema array-transform-schema
  [items (array-of table
           [code string? readable-datum? required]
           [label string? required])
         required])

(test-case "array-transform: transforms in array elements"
  (define data (hasheq 'items
                       (list (hasheq 'code "(+ 1 2)" 'label "add")
                             (hasheq 'code "(* 3 4)" 'label "mul"))))
  (define result (array-transform-schema data))
  (check-equal? (toml-ref result 'items 0 'code) '(+ 1 2))
  (check-equal? (toml-ref result 'items 1 'code) '(* 3 4)))

;;; Non-transforming predicates still work (return #t)

(define-toml-schema mixed-schema
  [port integer? (lambda (n) (and (>= n 1) (<= n 65535))) required]
  [expr string? readable-datum? required])

(test-case "mixed-schema: non-transformer predicate preserves value"
  (define data (hasheq 'port 8080 'expr "(list 1 2)"))
  (define result (mixed-schema data))
  (check-equal? (hash-ref result 'port) 8080)
  (check-equal? (hash-ref result 'expr) '(list 1 2)))
