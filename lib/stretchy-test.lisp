;;
;; stretchy-test.lisp - Tests for stretchy system.
;;

(defpackage :stretchy-test
  (:documentation "Tests for the STRETCHY system.")
  (:use :cl :test :stretchy)
  (:export
   #:run
   ))
(in-package :stretchy-test)

(deftests (stretchy-string)
  "String tests"
  "Making string types"
  (let ((s (make-stretchy-string 0)))
    (typep s 'stretchy-string))
  (let ((s (make-stretchy-string 1)))
    (typep s 'stretchy-string))
  (let ((s (make-stretchy-string 100)))
    (typep s 'stretchy-string))
  "Appending characters"
  (let ((s (make-stretchy-string 0)))
    (stretchy-append s #\x)
    (equal s "x"))
  (let ((s (make-stretchy-string 0)))
    (stretchy-append s #\1)
    (stretchy-append s #\2)
    (stretchy-append s #\3)
    (equal s "123"))
  (let ((s (make-stretchy-string 10)))
    (stretchy-append s #\1)
    (stretchy-append s #\2)
    (stretchy-append s #\3)
    (equal s "123"))
  "Appending strings"
  (let ((s (make-stretchy-string 0)))
    (stretchy-append s "")
    (equal s ""))
  (let ((s (make-stretchy-string 10)))
    (stretchy-append s "")
    (equal s ""))
  (let ((s (make-stretchy-string 10)))
    (stretchy-append s "123")
    (equal s "123"))
  (let ((s (make-stretchy-string 10)))
    (stretchy-append s "123")
    (stretchy-append s "456")
    (equal s "123456"))
  (let ((s (make-stretchy-string 4)))
    (stretchy-append s "123")
    (stretchy-append s "456")
    (stretchy-append s "789")
    (equal s "123456789"))
  (let ((s (make-stretchy-string 4)))
    (stretchy-append s "123")
    (stretchy-append s "456")
    (stretchy-append s "7890")
    (stretchy-append s "1234567890123456789012345678901234567890")
    (equal s "12345678901234567890123456789012345678901234567890"))
  (let ((s1 (make-stretchy-string 13))
	(s2 (make-string 1111 :initial-element #\x)))
    (loop :repeat 1111 :do (stretchy-append s1 #\x))
    (equal s1 s2))
  "Appending symbols"
  (let ((s (make-stretchy-string 5)))
    (stretchy-append s 'this)
    (equal s "THIS"))
  (let ((s (make-stretchy-string 23)))
    (stretchy-append s 'this)
    (stretchy-append s 'or)
    (stretchy-append s 'that)
    (equal s "THISORTHAT"))
  (let ((s (make-stretchy-string 123)))
    (stretchy-append s '|Foo|)
    (stretchy-append s #\space)
    (stretchy-append s 'the)
    (stretchy-append s #\space)
    (stretchy-append s '|Bar|)
    (equal s "Foo THE Bar"))
  "Appending vectors"
  (let ((s (make-stretchy-string 1)))
    (stretchy-append s #(#\W #\h #\y #\space #\i #\s #\space #\i #\t #\?))
    (equal s "Why is it?"))
  (let ((s (make-stretchy-string 12)))
    (stretchy-append s "Something ")
    (stretchy-append s #\o)
    (stretchy-append s #\r)
    (stretchy-append s #(#\space #\n #\o #\t #\h #\i #\n #\g))
    (equal s "Something or nothing"))
  "Setting elements"
  (let ((s (make-stretchy-string 0)))
    (stretchy-set s 3 #\x)
    (equalp s #(#\nul #\nul #\nul #\x)))
  (let ((s (make-stretchy-string 6)))
    (stretchy-set s 3 #\x)
    (equalp s #(#\nul #\nul #\nul #\x)))
  (let ((s (make-stretchy-string 6)))
    (stretchy-append s #\f)
    (stretchy-append s #\o)
    (stretchy-append s #\o)
    (stretchy-set s 6 #\x)
    (equalp s #(#\f #\o #\o #\nul #\nul #\nul #\x)))
  "Truncating"
  (let ((s (make-stretchy-string 10)))
    (stretchy-append s "It's not")
    (stretchy-truncate s 0)
    (equal s ""))
  (let ((s (make-stretchy-string 10)))
    (stretchy-append s "It's really not")
    (stretchy-truncate s 0)
    (zerop (length s)))
  (let ((s (make-stretchy-string 23)))
    (stretchy-append s "so very stupid")
    (stretchy-truncate s 7)
    (equal s "so very"))
  )

(deftests (stretchy-vector)
  "Vector tests"
  "Making vector types"
  (let ((s (make-stretchy-vector 0)))
    (typep s 'stretchy-vector))
  (let ((s (make-stretchy-vector 1)))
    (typep s 'stretchy-vector))
  (let ((s (make-stretchy-vector 100)))
    (typep s 'stretchy-vector))
  "Appending objects"
  (let ((s (make-stretchy-vector 0)))
    (stretchy-append s 1)
    (equalp s #(1)))
  (let ((s (make-stretchy-vector 0)))
    (stretchy-append s 1)
    (stretchy-append s 2)
    (stretchy-append s 3)
    (equalp s #(1 2 3)))
  (let ((s (make-stretchy-vector 10)))
    (stretchy-append s #\1)
    (stretchy-append s #\2)
    (stretchy-append s #\3)
    (equalp s #(#\1 #\2 #\3)))
  "Appending vectors"
  (let ((s (make-stretchy-vector 0)))
    (stretchy-append s #())
    (equalp s #()))
  (let ((s (make-stretchy-vector 10)))
    (stretchy-append s #())
    (equalp s #()))
  (let ((s (make-stretchy-vector 10)))
    (stretchy-append s #(1 2 3))
    (equalp s #(1 2 3)))
  (let ((s (make-stretchy-vector 10)))
    (stretchy-append s #(1 2 3))
    (stretchy-append s #(4 5 6))
    (equalp s #(1 2 3 4 5 6)))
  (let ((s (make-stretchy-vector 4)))
    (stretchy-append s #(1 2 3))
    (stretchy-append s #(4 5 6))
    (stretchy-append s #(7 8 9))
    (equalp s #(1 2 3 4 5 6 7 8 9)))
  (let ((s (make-stretchy-vector 4)))
    (stretchy-append s #(1 2 3))
    (stretchy-append s #(4 5 6))
    (stretchy-append s #(7 8 9 0))
    (stretchy-append s #(1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0
			 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0))
    (equalp s #(1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0
		1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0
		1 2 3 4 5 6 7 8 9 0)))
  (let ((s1 (make-stretchy-vector 13))
	(s2 (make-string 1111 :initial-element #\7)))
    (loop :repeat 1111 :do (stretchy-append s1 #\7))
    (equalp s1 s2))
  "Appending strings"
  (let ((s (make-stretchy-vector 5)))
    (stretchy-append s "this")
    (equalp s #(#\t #\h #\i #\s)))
  (let ((s (make-stretchy-vector 23)))
    (stretchy-append s "this")
    (stretchy-append s '"or")
    (stretchy-append s "that")
    (equalp s #(#\t #\h #\i #\s #\o #\r #\t #\h #\a #\t)))
  (let ((s (make-stretchy-vector 123)))
    (stretchy-append s "Foo")
    (stretchy-append s #\space)
    (stretchy-append s "the")
    (stretchy-append s #\space)
    (stretchy-append s "Bar")
    (equalp s #(#\F #\o #\o #\  #\T #\H #\E #\  #\B #\a #\r)))
  "Setting elements"
  (let ((s (make-stretchy-vector 0)))
    (stretchy-set s 3 111)
    (equalp s #(0 0 0 111)))
  (let ((s (make-stretchy-vector 6)))
    (stretchy-set s 3 111)
    (equalp s #(0 0 0 111)))
  (let ((s (make-stretchy-vector 6)))
    (stretchy-append s 2.3)
    (stretchy-append s 7/8)
    (stretchy-append s #b1010011)
    (stretchy-set s 6 111)
    (equalp s #(2.3 7/8 #b1010011 0 0 0 111)))
  "Truncating"
  (let ((s (make-stretchy-vector 10)))
    (stretchy-append s #(9 382 3 3280328 23843 2348))
    (stretchy-truncate s 0)
    (equalp s #()))
  (let ((s (make-stretchy-vector 10)))
    (stretchy-append s #(0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18))
    (stretchy-truncate s 0)
    (zerop (length s)))
  (let ((s (make-stretchy-vector 23)))
    (stretchy-append s #(0 1 2 3 4 5 6 1923 8349 3983 1284 2875))
    (stretchy-truncate s 7)
    (equalp s #(0 1 2 3 4 5 6)))
  )

(deftests (stretchy-all :doc "Test :stretchy.")
  stretchy-string stretchy-vector)

(defun run ()
  (run-group-name 'stretchy-all :verbose t))

;; EOF
