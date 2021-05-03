#lang racket/base

(require syntax/parse/define
         fancy-app
         racket/function
         (for-syntax racket/base
                     syntax/parse))

(require "private/util.rkt")

(provide on-clause
         (for-syntax subject))

(begin-for-syntax
  (define (repeat n v)
    (if (= 0 n)
        null
        (cons v (repeat (sub1 n) v))))

  (define-syntax-class subject
    #:attributes (args arity)
    (pattern
     (arg:expr ...)
     #:with args #'(arg ...)
     #:attr arity (length (syntax->list #'args)))))

(define-syntax-parser conjux-clause
  [(_ (~datum _) arity:number) #'true.]
  [(_ onex:expr arity:number) #`(on-clause onex arity)])

(define-syntax-parser disjux-clause
  [(_ (~datum _) arity:number) #'false.]
  [(_ onex:expr arity:number) #`(on-clause onex arity)])

(define-syntax-parser on-clause
  [(_ ((~datum one-of?) v:expr ...) arity:number)
   #'(compose
      ->boolean
      (curryr member (list v ...)))]
  [(_ ((~datum all) onex:expr) arity:number)
   #'(give (curry andmap (on-clause onex arity)))]
  [(_ ((~datum any) onex:expr) arity:number)
   #'(give (curry ormap (on-clause onex arity)))]
  [(_ ((~datum none) onex:expr) arity:number)
   #'(on-clause (not (any onex)) arity)]
  [(_ ((~datum and) onex:expr ...) arity:number)
   #'(conjoin (on-clause onex arity) ...)]
  [(_ ((~datum or) onex:expr ...) arity:number)
   #'(disjoin (on-clause onex arity) ...)]
  [(_ ((~datum not) onex:expr) arity:number)
   #'(negate (on-clause onex arity))]
  [(_ ((~datum and%) onex:expr ...) arity:number)
   #'(conjux (conjux-clause onex arity) ...)]
  [(_ ((~datum or%) onex:expr ...) arity:number)
   #'(disjux (disjux-clause onex arity) ...)]
  [(_ ((~datum with-key) f:expr onex:expr) arity:number)
   #'(compose
      (curry apply (on-clause onex arity))
      (give (curry map (on-clause f arity))))]
  [(_ ((~datum ..) onex:expr ...) arity:number)
   #'(compose (on-clause onex arity) ...)]
  [(_ ((~datum compose) onex:expr ...) arity:number)
   #'(on-clause (.. onex ...) arity)]
  [(_ ((~datum ~>) onex:expr ...) arity:number)
   (datum->syntax
    this-syntax
    (cons 'on-clause
          (list (cons '..
                      (reverse (syntax->list #'(onex ...))))
                #'arity)))]
  [(_ ((~datum thread) onex:expr ...) arity:number)
   #'(on-clause (~> onex ...) arity)]
  [(_ ((~datum ><) onex:expr) arity:number)
   #'(curry map-values (on-clause onex arity))]
  [(_ ((~datum amp) onex:expr) arity:number)
   #'(on-clause (>< onex) arity)]
  [(_ ((~datum ==) onex:expr ...) arity:number)
   #'(relay (on-clause onex arity) ...)]
  [(_ ((~datum relay) onex:expr ...) arity:number)
   #'(on-clause (== onex ...) arity)]
  [(_ ((~datum -<) onex:expr ...) arity:number)
   #'(λ args (values (apply (on-clause onex arity) args) ...))]
  [(_ ((~datum tee) onex:expr ...) arity:number)
   #'(on-clause (-< onex ...) arity)]
  [(_ ((~datum splitter) n:number) arity:number)
   (datum->syntax
    this-syntax
    (cons 'on-clause
          (list (cons '-<
                      (repeat (syntax->datum #'n)
                              #'identity))
                #'arity)))]
  ;; "prarg" = "pre-supplied argument"
  [(_ (onex prarg-pre ... (~datum __) prarg-post ...) arity:number)
   #`((on-clause onex arity) prarg-pre ... #,@(repeat (syntax->datum #'arity) #'_) prarg-post ...)]
  [(_ (onex prarg-pre ... (~datum _) prarg-post ...) arity:number)
   #'((on-clause onex arity) prarg-pre ... _ prarg-post ...)]
  [(_ (onex prarg ...) arity:number)
   #'(curryr (on-clause onex arity) prarg ...)]
  [(_ onex:expr arity:number) #'onex])