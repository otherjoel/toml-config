#lang racket/base

(require racket/contract
         racket/match
         racket/string
         syntax/parse/define
         (for-syntax racket/base))

(provide define-toml-schema
         validation-error
         (struct-out exn:fail:toml:validation)
         readable-datum?)

;;; Error Reporting

(struct exn:fail:toml:validation exn:fail (key-path expected actual)
  #:transparent)

(define (format-value v)
  (cond
    [(string? v) (format "\"~a\"" v)]
    [(symbol? v) (symbol->string v)]
    [(list? v)
     ;; Special formatting for common contract forms
     (match v
       [(list 'integer-in min max) (format "integer between ~a and ~a" min max)]
       [(list 'listof type) (format "list of ~a values" (format-value type))]
       [(list type '...) (format "~a..." (format-value type))]
       [_ (format "~s" v)])]
    [(hash? v) "<table>"]
    [else (format "~a" v)]))

(define (validation-error key-path message [expected #f] [actual #f])
  (define path-str (if (null? key-path)
                       "config"
                       (string-join (map symbol->string key-path) ".")))

  (define detailed-msg
    (cond
      ;; Both expected and actual provided
      [(and expected actual)
       (format "~a: ~a\n  expected: ~a\n  actual: ~a"
               path-str message
               (format-value expected)
               (format-value actual))]
      ;; Only expected provided
      [expected
       (format "~a: ~a (expected: ~a)"
               path-str message
               (format-value expected))]
      ;; Only actual provided
      [actual
       (format "~a: ~a (got: ~a)"
               path-str message
               (format-value actual))]
      ;; Neither provided
      [else
       (format "~a: ~a" path-str message)]))

  (raise (exn:fail:toml:validation detailed-msg (current-continuation-marks)
                                   key-path expected actual)))

;;; Sentinel value for "no default provided"

(define undefined-default (string->uninterned-symbol "undefined-default"))

(define (readable-datum? v)
  (and (string? v)
       (with-handlers ([exn:fail:read? (λ (_) #f)])
         (define in (open-input-string v))
         (define datum (read in))
         (cond
           [(eof-object? datum) #f]  ; Empty or whitespace-only string
           [else
            (define leftover (read in))
            (if (eof-object? leftover)
                (box datum)  ; Wrap in box to distinguish from validation failure
                #f)]))))

;;; Type Checking

(define (make-type-checker spec spec-name)
  (define checker
    (cond
      [(flat-contract? spec)
       (contract-first-order spec)]
      [(procedure? spec)
       spec]
      [else
       (error 'make-type-checker "Invalid type spec: ~v" spec)]))
  (cons checker spec-name))

;;; Runtime Validation (pure - no mutation)

(define (get-type-name value)
  (cond
    [(string? value) "string"]
    [(integer? value) "integer"]
    [(real? value) "number"]
    [(boolean? value) "boolean"]
    [(list? value) "array"]
    [(hash? value) "table"]
    [else "unknown"]))

(define (format-checker-name checker)
  (define name (object-name checker))
  (cond
    [(not name) "custom predicate"]
    [(symbol? name) (symbol->string name)]
    [(string? name)
     ;; Clean up contract names - extract meaningful part
     (cond
       [(regexp-match #rx"integer-in" name) "integer in valid range"]
       [(regexp-match #rx"listof" name) "list of valid elements"]
       [(regexp-match #rx"and\\.rkt" name) "valid value"]
       [else name])]
    [else (format "~a" name)]))

(define (make-suggestion expected-name actual-value)
  (match expected-name
    [(list 'integer-in min max)
     (format "\n  → Use an integer between ~a and ~a" min max)]
    [(list 'listof _)
     "\n  → Ensure all list elements are the correct type"]
    ['string?
     (if (number? actual-value)
         "\n  → Use quotes around the value to make it a string?"
         "")]
    ['integer?
     (if (string? actual-value)
         "\n  → Remove quotes to make it a number?"
         "")]
    [_ ""]))

;; validate-field now returns the (possibly transformed) value
;; Returns #f if the key is not present, or a (cons key value) pair if present
(define (validate-field toml-data key-path type-checkers required? key)
  (define has-key? (hash-has-key? toml-data key))
  (define full-path (append key-path (list key)))

  (when (and required? (not has-key?))
    (validation-error full-path
                     (format "required key is missing\n  → Add '~a = <value>' to the configuration"
                             key)))

  (if has-key?
      ;; Run through checkers sequentially, threading transformed values
      (let loop ([value (hash-ref toml-data key)]
                 [checkers type-checkers])
        (if (null? checkers)
            (cons key value)  ; Return the final (possibly transformed) value
            (let* ([checker-pair (car checkers)]
                   [checker (car checker-pair)]
                   [type-name (cdr checker-pair)]
                   [result (checker value)])
              (cond
                [(eq? result #f)
                 ;; Validation failed
                 (define actual-type (get-type-name value))
                 (define suggestion (make-suggestion type-name value))
                 (validation-error full-path
                                  (format "type mismatch (got ~a)~a" actual-type suggestion)
                                  type-name
                                  value)]
                [(eq? result #t)
                 ;; Validation passed, value unchanged
                 (loop value (cdr checkers))]
                [(box? result)
                 ;; Transformation with boxed value (to handle #f as a valid datum)
                 (loop (unbox result) (cdr checkers))]
                [else
                 ;; Transformation: use result as new value
                 (loop result (cdr checkers))]))))
      #f))

;; validate-table returns #f if not present, or (cons key validated-table) if present
(define (validate-table toml-data key-path key required? sub-specs)
  (define has-key? (hash-has-key? toml-data key))
  (define full-path (append key-path (list key)))

  (when (and required? (not has-key?))
    (validation-error full-path "required table is missing"))

  (if has-key?
      (let ([value (hash-ref toml-data key)])
        (unless (hash? value)
          (validation-error full-path "must be a table" 'table value))
        (cons key (run-validations value full-path sub-specs)))
      #f))

;; validate-array-of-tables returns #f if not present, or (cons key validated-array) if present
(define (validate-array-of-tables toml-data key-path key required? sub-specs)
  (define has-key? (hash-has-key? toml-data key))
  (define full-path (append key-path (list key)))

  (when (and required? (not has-key?))
    (validation-error full-path "required array is missing"))

  (if has-key?
      (let ([value (hash-ref toml-data key)])
        (unless (list? value)
          (validation-error full-path "must be an array" 'array value))

        ;; Validate each element in the array, collecting transformed results
        (cons key
              (for/list ([element value]
                         [index (in-naturals)])
                (unless (hash? element)
                  (validation-error (append full-path (list (string->symbol (format "[~a]" index))))
                                   "array element must be a table"
                                   'table
                                   element))
                (run-validations element
                                (append full-path (list (string->symbol (format "[~a]" index))))
                                sub-specs))))
      #f))

;; run-validations now returns a hash with all transformed values applied
(define (run-validations toml-data key-path compiled-specs)
  (for/fold ([result toml-data])
            ([spec compiled-specs])
    (define update-pair
      (match spec
        [(list 'field key type-checkers required? _default)
         (validate-field result key-path type-checkers required? key)]
        [(list 'table key required? sub-specs)
         (validate-table result key-path key required? sub-specs)]
        [(list 'array-of-tables key required? sub-specs)
         (validate-array-of-tables result key-path key required? sub-specs)]))
    (if update-pair
        (hash-set result (car update-pair) (cdr update-pair))
        result)))

;;; Apply Defaults (pure - returns new hash)

(define (apply-field-default toml-data key default)
  (if (and (not (eq? default undefined-default))
           (not (hash-has-key? toml-data key)))
      (hash-set toml-data key default)
      toml-data))

(define (apply-table-defaults toml-data key sub-specs)
  (if (hash-has-key? toml-data key)
      (hash-set toml-data key
                (apply-defaults (hash-ref toml-data key) sub-specs))
      toml-data))

(define (apply-array-of-tables-defaults toml-data key sub-specs)
  (if (hash-has-key? toml-data key)
      (hash-set toml-data key
                (map (lambda (element)
                       (apply-defaults element sub-specs))
                     (hash-ref toml-data key)))
      toml-data))

(define (apply-defaults toml-data compiled-specs)
  (for/fold ([result toml-data])
            ([spec compiled-specs])
    (match spec
      [(list 'field key _type-checkers _required? default)
       (apply-field-default result key default)]
      [(list 'table key _required? sub-specs)
       (apply-table-defaults result key sub-specs)]
      [(list 'array-of-tables key _required? sub-specs)
       (apply-array-of-tables-defaults result key sub-specs)])))

(define (validate-and-apply-defaults toml-data compiled-specs)
  (define validated (run-validations toml-data '() compiled-specs))
  (apply-defaults validated compiled-specs))

;;; Compile-Time Schema Processing

(begin-for-syntax
  (define (compile-field-spec field-spec-stx)
    (syntax-parse field-spec-stx
      ;; Table with explicit required/optional
      [(key:id ((~literal table) sub-spec ...) (~literal required))
       #`(list 'table 'key #t (list #,@(map compile-field-spec (syntax->list #'(sub-spec ...)))))]

      [(key:id ((~literal table) sub-spec ...) (~literal optional))
       #`(list 'table 'key #f (list #,@(map compile-field-spec (syntax->list #'(sub-spec ...)))))]

      ;; Table without required/optional (defaults to required for backwards compatibility)
      [(key:id ((~literal table) sub-spec ...))
       #`(list 'table 'key #t (list #,@(map compile-field-spec (syntax->list #'(sub-spec ...)))))]

      ;; Array-of-tables with required/optional
      [(key:id ((~literal array-of) (~literal table) sub-spec ...) (~literal required))
       #`(list 'array-of-tables 'key #t (list #,@(map compile-field-spec (syntax->list #'(sub-spec ...)))))]

      [(key:id ((~literal array-of) (~literal table) sub-spec ...) (~literal optional))
       #`(list 'array-of-tables 'key #f (list #,@(map compile-field-spec (syntax->list #'(sub-spec ...)))))]

      ;; Regular fields
      [(key:id type-spec:expr ... (~literal required))
       #`(list 'field 'key (list #,@(map (lambda (ts)
                                            #`(make-type-checker #,ts '#,(syntax->datum ts)))
                                          (syntax->list #'(type-spec ...)))) #t undefined-default)]

      [(key:id type-spec:expr ... (~literal optional))
       #`(list 'field 'key (list #,@(map (lambda (ts)
                                            #`(make-type-checker #,ts '#,(syntax->datum ts)))
                                          (syntax->list #'(type-spec ...)))) #f undefined-default)]

      [(key:id type-spec:expr ... ((~literal optional) default:expr))
       #`(list 'field 'key (list #,@(map (lambda (ts)
                                            #`(make-type-checker #,ts '#,(syntax->datum ts)))
                                          (syntax->list #'(type-spec ...)))) #f default)]

      [else
       (error 'compile-field-spec "Invalid field spec: ~v" (syntax->datum field-spec-stx))]))

  (define (compile-schema field-specs-stx)
    (map compile-field-spec (syntax->list field-specs-stx))))

;;; Macro

(define-syntax (define-toml-schema stx)
  (syntax-parse stx
    [(_ name:id field-spec:expr ...)
     (define compiled-specs (compile-schema #'(field-spec ...)))
     #`(define name
         (lambda (toml-data)
           (validate-and-apply-defaults toml-data (list #,@compiled-specs))))]))


