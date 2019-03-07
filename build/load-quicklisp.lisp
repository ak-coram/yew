;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Try to load QuickLisp, if it's not alread loaded.

(defparameter *quicklisp-fail*
  "Perhaps try installing a new QuickLisp by following the instructions at:
https://www.quicklisp.org/beta/")

(defparameter *not-strictly-necessary*
  "QuickLisp is not strictly necessary, but if you don't have it, you will have
to make sure all the dependencies are availible to be loaded by ASDF.")

(when (not (find-package :quicklisp))
  (if (sf-getenv "LISH_QUICKLISP")
      (handler-case
      	  (load (sf-getenv "LISH_QUICKLISP"))
	(error (c)
	  (print c)
	  (fail "LISH_QUICKLISP is set to ~s.~%~
                 We failed to load the custom QuickLisp. ~a~a"
		*quicklisp-fail* *not-strictly-necessary*)))
      (let ((quicklisp-init (merge-pathnames "quicklisp/setup.lisp" *home*)))
	(if (probe-file quicklisp-init)
	    (block nil
	      (handler-case
		  (with-unicode-files ()
		    (load quicklisp-init))
		(error (c)
		  (print c)
		  (format t "~&/~v,,,va~%~
                             We failed to load QuickLisp from ~s.~%~a~%~a~
                             ~&\\~v,,,va~%"
			  40 #\- #\-
			  quicklisp-init
			  *quicklisp-fail*
			  *not-strictly-necessary*
			  40 #\- #\-)
		  (return nil))))
	    (format t "QuickLisp was not found at ~s.~%~s" quicklisp-init
		    *not-strictly-necessary*)))))
