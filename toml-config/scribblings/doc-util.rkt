#lang racket/base

(require racket/string
         racket/format
         racket/list
         racket/runtime-path
         scribble/core
         scribble/decode
         scribble/manual
         scribble/example
         scribble/html-properties
         toml)

(provide toml-example
         errorblock
         errorblock*
         inline-note)

(define-runtime-path add-css "doc-aux.css")

;; Create a TOML example display and evaluator
(define (toml-example #:filename [filename "example.toml.rkt"]
                      #:lang [lang "toml/config"]
                      . content-parts)
  (define toml-content (apply string-append content-parts))

  ;; Create the display element
  (define display-elem
    (filebox filename
             (codeblock (format "#lang ~a\n\n" lang) toml-content)))

  ;; Create fresh evaluator with toml bound to parsed content
  (define e (make-base-eval))
  (e '(require toml/config))
  (e `(define toml ,(parse-toml toml-content)))

  (values display-elem e))

;; For use directly with @-reader that auto-splits newlines into separate list elems
(define (convert-newlines args)
  (map (λ (arg) (if (equal? arg "\n") (linebreak) arg)) args))

(define (errorblock . args)
  (nested (racketerror (element 'tt (convert-newlines args)))))

;; If you are giving one big string
(define (convert-newlines* str)
  (add-between (string-split str "\n") (linebreak)))

(define (errorblock* str)
  (nested (racketerror (element 'tt (convert-newlines* str)))))

(define (inline-note #:type [type 'note] . elems)
  (compound-paragraph
   (style "inline-note" (list (css-style-addition add-css)
                          (attributes `((class . ,(format "refcontent ~a" type))))
                          (alt-tag "aside")))
   (decode-flow elems)))