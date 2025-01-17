;;;
;;; base.lisp - Things that need to be defined before the system specific code.
;;;

(in-package :deblarg)

;; (declaim
;;  (optimize (speed 0) (safety 3) (debug 3) (space 0) (compilation-speed 0)))

(defstruct thread
  "Per thread state."
  repeat-condition
  repeat-restart)

(defclass deblargger ()
  ((current-frame
    :initarg :current-frame :accessor debugger-current-frame :initform nil
    :documentation "The which the debugger is looking at.")
   (saved-frame
    :initarg :saved-frame :accessor debugger-saved-frame :initform nil
    :documentation "The frame which the debugger was entered from.")
   (condition
    :initarg :condition :accessor debugger-condition :initform nil
    :type (or condition null)
    :documentation "The condition which got us in here.")
   (term
    :initarg :term :accessor debugger-term  :type terminal
    :documentation "The terminal for debugger I/O.")
   (visual-mode
    :initarg :visual-mode :accessor debugger-visual-mode
    :initform nil :type boolean
    :documentation "True if we are in visual mode.")
   (visual-term
    :initarg :visual-term :accessor debugger-visual-term
    :initform nil :type (or terminal null)
    :documentation "The terminal for visual mode."))
  (:documentation "I don't debug much, but when I do, I deblarg."))

(defvar *deblarg* nil
  "The current debugger instance.")

(defvar *thread* nil
  "Per thread state.")

(defvar *deblargger-implementation-class* nil
  "The class name for the implementation type.")

(defun debugger-sorry (x)
  "What to say when we can't do something."
  (format *debug-io* "~%Sorry, don't know how to ~a on ~a. ~
		       Snarf some slime!~%" x (lisp-implementation-type)))

(defun make-deblargger (&rest args)
  "Make a deblargger instance of the appropriate implentation type and return it.
‘args’ are given as arguments to make-instance."
  (apply #'make-instance *deblargger-implementation-class*
	 args))

(defmacro def-debug (name (&rest args) doc-string &key no-object quiet)
  "Defines a debugger generic function along with a macro that calls that
generic function with ‘*deblarg*' as it's first arg. If ‘no-object’ is true,
the first arg is eql specialized by ‘*deblargger-implementation-class*’.
If ‘quiet’ is true, the default method doesn't apologize."
  (let ((dd-name (symbolify (s+ "DD-" name)))
	(generic-name (symbolify (s+ "DEBUGGER-" name)))
	(whole-arg (gensym "DEF-DEBUG-WHOLE-ARG"))
	(ignorables (lambda-list-vars args :all-p t))
	(first-arg (if no-object
		       '*deblargger-implementation-class*
		       '*deblarg*)))
    `(progn
       (defgeneric ,generic-name (tt ,@args)
	 (:documentation ,doc-string)
	 (:method (d ,@args)
	   (declare (ignore d) (ignorable ,@ignorables))
	   ;; A default apology.
	   ,@(unless quiet `((debugger-sorry ',generic-name)))))
       (defmacro ,dd-name (&whole ,whole-arg ,@args)
	 (declare (ignorable ,@ignorables))
	 ,doc-string
	 (append (list ',generic-name ',first-arg) (cdr ,whole-arg))))))

;; (defvar *interceptor-condition* nil
;;   "The condition that happened.")

;; @@@ Do we really need this separate here? Could we just use *terminal*
;; in with-new-terminal?
(defvar *debug-term* nil
  "*debug-io* as a terminal.")

(defvar *dont-use-a-new-term* nil
  "Prevent the debugger from opening a new terminal.")

(defmacro with-new-debugger-io ((d) &body body)
  "Evaluate BODY with a new *terminal* redirected to *debug-io*."
  (with-unique-names (thunk)
    `(flet ((,thunk () ,@body))
       (if *dont-use-a-new-term*
	   (progn
	     (setf (debugger-term ,d) *terminal*)
	     (,thunk))
	   (let ((fd (nos:stream-system-handle *debug-io*))
		 device-name)
	     (when fd
	       (setf device-name (nos:file-handle-terminal-name fd)))
	     (if device-name
		 ;; @@@ Could we just use *terminal*?
		 (with-new-terminal ((platform-default-terminal-type)
				     *debug-term*
				     :device-name device-name
				     :output-stream
				     (make-broadcast-stream *debug-io*))
		   (setf (debugger-term ,d) *debug-term*)
		   (,thunk))
		 (with-new-terminal ((platform-default-terminal-type)
				     *debug-term*
				     :output-stream
				     (make-broadcast-stream *debug-io*))
		   (setf (debugger-term ,d) *debug-term*)
		   (,thunk))))))))

(defmacro with-debugger-io ((d) &body body)
  "Evaluate BODY with *debug-term* set up, either existing or new."
  (with-unique-names (thunk)
    `(flet ((,thunk () ,@body))
       (if *debug-term*
	   (,thunk)
	   (with-new-debugger-io (,d)
	     (,thunk))))))

;; @@@ Figure out some way to make these respect *debug-io*, even when not
;; in the debugger.

(defun debugger-print-string (string)
  (let ((term (or (and *deblarg* (debugger-term *deblarg*)) *terminal*)))
    (typecase string
      (string (princ string term))
      (fatchar-string
       (render-fatchar-string string :terminal term))
      (fat-string
       (render-fat-string string :terminal term)))))

(defun print-span (span)
  ;; This doesn't work since some implementations wrap our terminal stream
  ;; with something else before it gets to print-object.
  ;;(princ (span-to-fat-string span) *terminal*)
  (render-fatchar-string (span-to-fatchar-string span)
			 :terminal
			 (if *deblarg*
			     (debugger-term *deblarg*)
			     terminal:*terminal*)))

(defun display-value (v stream)
  "Display V in a way which hopefully won't mess up the display. Also errors
are indicated instead of being signaled."
  (handler-case
      (typecase v
	;; Make strings with weird characters not screw up the display.
	(string
	 (prin1 (with-output-to-string (str)
		  (loop :for c :across v :do
		     (displayable-char c :stream str
				       :all-control t :show-meta nil)))
		stream))
	(t (prin1 v stream)))
    (error (c)
      (declare (ignore c))
      (return-from display-value
	(format nil "<<Error printing a ~a>>" (type-of v))))))

(defun print-stack-line (line &key width)
  "Print a stack LINE, which is a cons of (line-numbner . string)."
  (destructuring-bind (num . str) line
    (print-span `((:fg-yellow ,(format nil "~3d" num) " ")))
    (debugger-print-string
     (if width
	 (osubseq str 0 (min (olength str) (- width 4)))
	 str))
    ;;(terpri *terminal*)
    (terminal-write-char (or (and *deblarg* (debugger-term *deblarg*))
			     *terminal*) #\newline)))

;; EOF
