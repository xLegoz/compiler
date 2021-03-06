#lang racket

(provide
  transitions
  final-states
  finalize-token)

(require
  "../src/assembling/scanner.rkt"
  (only-in "../src/helpers.rkt" chartest))

;; helper functions for finalize-token
(define (list->number lst)
  (string->number (list->string lst)))


(define (list->hexint lst)
  (string->number (list->string lst) 16))

;; scheme supports unbounded integers but MIPS doesn't
(define (check-int-range n)
  (cond
    [(<= -2147483648 n 4294967295) n]
    [else (error 'ERROR "integer out of range: ~a" n)]))

(define (check-hexint-range n)
  (cond
    [(cons? n) n] ; FIXME: what is this case doing?
    [(<= 0 n 4294967295) n]
    [else (error 'ERROR "integer out of range: ~a" n)]))

(define (check-reg-range n)
  (cond
    [(<= 0 n 31) n]
    [else (error 'ERROR "register out of range: ~a" n)]))


(define (one-to-nine? ch)
  (and
    (char<=? #\1 ch)
    (char<=? ch #\9)))

(define (hex-digit? ch)
  (or
    (char-numeric? ch)
    (and (char<=? #\a ch) (char<=? ch #\f))
    (and (char<=? #\A ch) (char<=? ch #\F))))

; transistion table for scanner
(define transitions
  (list
    ; whitespace
    (transition 'start char-whitespace? 'whitespace)

    ; comment
    (transition 'start (chartest #\;) 'comment)
    (transition 'comment (lambda (x) true) 'comment)

    ; .word
    (transition 'start (chartest #\.) 'dot)
    (transition 'dot (chartest #\w) 'dotw)
    (transition 'dotw (chartest #\o) 'dotwo)
    (transition 'dotwo (chartest #\r) 'dotwor)
    (transition 'dotwor (chartest #\d) 'dotword)

    ; ids
    (transition 'start char-alphabetic? 'id)
    (transition 'id char-alphabetic? 'id)
    (transition 'id char-numeric? 'id)
    ; specifically for floating point registers
    (transition 'id (chartest #\.) 'id)

    ; label definition
    (transition 'id (chartest #\:) 'label)

    ; int
    (transition 'start one-to-nine? 'int)
    (transition 'int char-numeric? 'int)
    ; negative int
    (transition 'start (chartest #\-) 'minus)
    (transition 'minus char-numeric? 'int)

    ; hex int
    (transition 'start (chartest #\0) 'zero)
    (transition 'zero (chartest #\x) 'zerox)
    (transition 'zero char-numeric? 'int)
    (transition 'zerox hex-digit? 'hexint)
    (transition 'hexint hex-digit? 'hexint)

    ; syntax tokens
    (transition 'start (chartest #\,) 'comma)
    (transition 'start (chartest #\() 'lparen)
    (transition 'start (chartest #\)) 'rparen)
    ; registers
    (transition 'start (chartest #\$) 'dollar)
    (transition 'dollar char-numeric? 'register)
    (transition 'register char-numeric? 'register)
))

; list of valid final satesfinal state table
(define final-states
  (list
    'register
    'int
    'id
    'label
    'comma
    'lparen
    'rparen
    'zero
    'hexint
    'comment
    'dotword
    'whitespace
))


; to special adjustments to finalize tokens
(define (finalize-token state l line-offset)
  (define fixed-line-offset (- line-offset (length l)))
  (define lexeme-value
    (match state
      ['int (check-int-range (list->number l))] ; convert int string to int
      ['zero 0] ; convert zero to int
      ['hexint (check-hexint-range (list->hexint (drop l 2)))] ; convert hex string to int
      ['register (check-reg-range (list->number (drop l 1)))] ; convert register number to int
      ['label (list->string (drop-right l 1))] ; convert label charlist to string
      ['dotword "WORD"] ; convert word val to string
      ['id (list->string l)] ; convert id char list to string
      [_ l]))
  (define line 0) ; placeholder, filled in later
  (token state lexeme-value 0 fixed-line-offset))
