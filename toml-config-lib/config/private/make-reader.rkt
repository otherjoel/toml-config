#lang racket/base

(require racket/port
         racket/string
         syntax/strip-context
         toml
         gregor
         gregor/time
         toml/config/private/validate)

(provide make-toml-syntax-reader get-info)

;;; Convert parsed TOML data to syntax that constructs it at runtime
(define (toml-data->stx v)
  (cond
    [(date? v)
     #`(date #,(->year v) #,(->month v) #,(->day v))]
    [(time? v)
     #`(time #,(->hours v) #,(->minutes v) #,(->seconds v) #,(->nanoseconds v))]
    [(datetime? v)
     #`(datetime #,(->year v) #,(->month v) #,(->day v)
                 #,(->hours v) #,(->minutes v) #,(->seconds v) #,(->nanoseconds v))]
    [(moment? v)
     #`(moment #,(->year v) #,(->month v) #,(->day v)
               #,(->hours v) #,(->minutes v) #,(->seconds v) #,(->nanoseconds v)
               #:tz #,(->timezone v))]
    [(hash? v)
     #`(hasheq #,@(apply append
                    (for/list ([(k val) (in-hash v)])
                      (list #`'#,k (toml-data->stx val)))))]
    [(list? v)
     #`(list #,@(for/list ([item (in-list v)])
                  (toml-data->stx item)))]
    ;; Primitives: strings, numbers, booleans, symbols
    [else #`#,v]))

;;; Reader Helper

(define (make-toml-syntax-reader validator)
  (lambda (src in)
    (port-count-lines! in)
    (define toml-str (string-trim (string-replace (port->string in) "\u00A0" "")))
    (define toml-data
      (with-handlers ([exn:fail? (λ (e)
                                   (raise-syntax-error 'toml/config
                                     (format "TOML parse error: ~a" (exn-message e))))])
        (parse-toml toml-str)))

    (define validated-data
      (with-handlers ([exn:fail:toml:validation?
                       (λ (e)
                         (raise-syntax-error 'toml/config
                           (format "Validation error: ~a" (exn-message e))))])
        (validator toml-data)))
    (strip-context
      #`(module parsed-toml racket/base
         (require toml/config gregor gregor/time)
         (provide toml)
         (define toml #,(toml-data->stx validated-data))))))

;;; Runtime

(define (get-info in mod line col pos)
  (lambda (key default)
    (case key
      [(color-lexer)
       (dynamic-require 'toml/config/private/color-lexer 'toml-color-lexer)]
      [else default])))