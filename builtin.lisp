;;
;; builtin.lisp - Lish built-in commands.
;;

;; Here we define the commands that are built in to Lish.

;; Most of these are really just for compatability with a POSIX shell, so
;; perhaps on another operating system you might not need them.
;; For example we might have a set of commands for an internet appliance
;; like a router.
;; @@@ Perhaps we should make some Windows PowerShell commands.
;; @@@ Perhaps we should be able to load a built-in ‘personality’.

(in-package :lish)

(declaim (optimize (speed 0) (safety 3) (debug 3) (space 1)
		   (compilation-speed 0)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Command definitions

(defbuiltin cd (("directory" directory :help "Directory to change to."))
  "Change the current directory to DIRECTORY."
  (setf (lish-old-pwd *shell*) (nos:current-directory))
  (nos:change-directory (or directory (nos:getenv "HOME")))
  ;; Update $PWD like traditional Unix shells.
  ;; @@@ Maybe someday we can get rid of this.
  (nos:setenv "PWD" (nos:current-directory)))

(defbuiltin pwd ()
  "Print the current working directory."
  (format t "~a~%" (nos:current-directory)))

(defbuiltin pushd (("directory" directory
				:help "Directory to push on the stack."))
  "Change the current directory to DIR and push it on the the front of the
directory stack."
  (when (not directory)
    (setf directory (pop (lish-dir-list *shell*))))
  (push (nos:current-directory) (lish-dir-list *shell*))
  (!cd directory))

(defbuiltin popd (("number" number :help "Number of item to pop."))
  "Change the current directory to the top of the directory stack and remove it
from stack."
  (declare (ignore number))
  (let ((dir (pop (lish-dir-list *shell*))))
    (!cd dir)
    dir))

(defbuiltin dirs ()
  "Show the directory stack."
  (format t "~a~%" (lish-dir-list *shell*)))

(defbuiltin suspend ()
  "Suspend the shell."
;  (opsys:kill (opsys:getpid) opsys:sigstop))
  (opsys:kill (opsys:getpid) 17))	; SIGSTOP

(define-builtin-arg-type job-descriptor (arg-integer)
  "A job descriptor."
  ())

(defbuiltin resume
    (("job-descriptor" job-descriptor :optional t :help "Job to resume."))
  "Resume a suspended job."
  (let (job)
    (cond
      ((or (null (lish-suspended-jobs *shell*))
	   (= (length (lish-suspended-jobs *shell*)) 0))
       (format t "No jobs to resume.~%")
       (return-from !resume (values)))
      ((= (length (lish-suspended-jobs *shell*)) 1)
       (setf job (first (lish-suspended-jobs *shell*))))
      (t
       (setf job (find job-descriptor
		       (lish-suspended-jobs *shell*)
		       :test #'equalp
		       :key #'suspended-job-name))))
    (if (not job)
	(format t "Couldn't find a job matching ~a.~%" job-descriptor)
	(if (suspended-job-resume-function job)
	    (progn
	      (setf (lish-suspended-jobs *shell*)
		    (delete job (lish-suspended-jobs *shell*)))
	      (funcall (suspended-job-resume-function job)))
	    (format t "The job doesn't have a resume function ~a.~%"
		    job-descriptor)))))

(defbuiltin jobs
  (("long" boolean :short-arg #\l
     :help "Show the longer output."))
  "Lists spawned processes that are active."
  ;; @@@ not working yet for system commands
  (loop :for j :in (lish-suspended-jobs *shell*)
     :do
     (with-slots (id name command-line resume-function) j
       (format t "~3d ~10a ~20a ~:[~;~a ~]~a~%"
	       id "LISP" name long resume-function command-line)))
  (when (find-package :bt)
    (loop :for j :in (ignore-errors (funcall (find-symbol "ALL-THREADS" :bt)))
       :do
       (format t "~3d ~10a ~20a ~:[~;~a ~]~a~%"
	       0 "THREAD"
	       (funcall (find-symbol "THREAD-NAME" :bt) j)
	       long j ""))))

(defbuiltin history
    (("clear"	      boolean  :short-arg #\c
      :help "Clear the history.")
     ("write"	      boolean  :short-arg #\w
      :help "Write the history to the history file.")
     ("read"	      boolean  :short-arg #\r
      :help "Read the history from the history file.")
     ("append"	      boolean  :short-arg #\a
      :help "Append the history to the history file.")
     ("read-not-read" boolean  :short-arg #\n
      :help "Read history items not already read from the history file.")
     ("filename"      pathname :short-arg #\f
      :help "Use PATHNAME as the history file.")
     ("show-times"    boolean  :short-arg #\t
      :help "Show history times.")
     ("delete"	      integer  :short-arg #\d
      :help "Delete the numbered history entry."))
  "Show a list of the previously entered commands."
  ;; Check argument conflicts
  (cond ;; @@@ Could this kind of thing be done automatically?
    ((and clear (or write read append read-not-read filename show-times delete))
     (error "CLEAR should not be given with any other arguments."))
    ((and delete (or write read append read-not-read filename show-times clear))
     (error "DELETE should not be given with any other arguments."))
    ((> (count t `(,write ,read ,append ,read-not-read)) 1)
     (error
      "Only one of WRITE, READ, APPEND, or READ-NOT-READ should be given."))
    ((and filename (not (or read write append read-not-read)))
     (error
      "FILENAME is only useful with READ, WRITE, APPEND, or READ-NOT-READ.")))
  (cond
    (clear
     (tiny-rl:history-clear :lish))
    ;; @@@ TODO: finish this when history saving in tiny-rl is done.
    (t
     (tiny-rl:show-history :lish))))

;; This seems stupid and unnecessary. 
;; (defbuiltin #:|:| (("args" t :repeating t))
;;   "Arguments are evaluated for side effects."
;;   (declare (ignore args))
;;   (values))

(defbuiltin echo
    (("no-newline" boolean :short-arg #\n :help "Don't output a newline.")
     ("args" t :repeating t))
  "Output the arguments. If -n is given, then don't output a newline a the end."
  (format t "~{~a~#[~:; ~]~}" args)
  (when (not no-newline)
    (format t "~%")))

(defparameter *help-subjects*
  '("commands" "builtins" "editor" "keys" "syntax")
  "Subjects we have help about.")

(defun help-choices ()
  "Return a list of choices for a help subject."
  (concatenate
   'list *help-subjects*
   (mapcar #'(lambda (x)
	       (or (and (symbolp x) (string-downcase (symbol-name x)))
		   (and (stringp x) x)
		   x))
	   *command-list*)))

(defclass arg-help-subject (arg-choice)
  ()
  (:default-initargs
   :choice-func
      #+clisp 'help-choices		; I'm not sure why.
      #-clisp #'help-choices)
  (:documentation "Something which we can get help on."))

(defparameter *basic-help*
"~
Lish version ~a help:
  command [arg*...]   Run a program in your path with the given ARGs.
  ([expressions]...)  Evaluate Lisp expressions.
  help [subject]      Show help on the subject.
  exit                Exit the shell.
Subjects:
  help builtins       Show help on built-in commands.
  help commands       Show help on added commands.
  help editor         Show help on the line editor.
  help keys           Show help on key bindings.
  help syntax         Show help on shell syntax.
  help <command>      Show help for the command.
")

(defparameter *editor-help*
"You can use some Emacs-like commands to edit the command line.

Some notable keys are:
 <Tab>        Try to complete the word in front of the cursor.
 ?            Show what input is expected. List possibilities.
 <Control-D>  Quit, when on an empty line, or delete the following character.
 <Control-P>  Previous history line. Also the <Up Arrow> key.
 <Control-N>  Next history line. Also the <Down Arrow> key.
 <Control-B>  Move the cursor back one character. Also the <Left Arrow> key.
 <Control-F>  Move the cursor forward one character. Also the <Right Arrow> key.
 <Control-Q>  Quote next character, like if you want to really type '?'.
 <F9>         Switch back and forth between LISH and the lisp REPL.
")

(defparameter *syntax-help*
"The syntax is a combination of POSIX shell and Lisp, hopefully in a way that
is familiar and not too surprising to those who know either.
It is vaguely like:
  ; comment
  command [arg...]
  command \"string\" !*lisp-object* (lisp-code) $ENV_VAR 
  command *.glob ?ooba[rz]
  command word\ with\ spaces \"string \\\" with a double quote\"
  command | command | ...
  command < file-name
  command > file-name
  ([lisp expressions...])

Basically, inside parentheses you get Lisp reader syntax. Outside parentheses,
you get a very simplified shell syntax with Lisp strings and comments.
Some typical shell expansions are done in command arguments, such as shell
globbing with *,?,and [], environment variable expansions with $VAR, and
home directory expansions with ~~user. Pipeline and redirections should work
nearly as expected.

Commands can be:
  - System executables in your standard PATH
  - Built-in or later defined commands, defined with DEFCOMMAND
  - Names of systems in your ASDF \"path\" which are expected to define a
    command with the same name as the system, which is then invoked.
  - Lisp functions or methods
")

(defun print-command-help (commands &key (built-in t))
  (let ((rows
	 (loop :with b :and doc :and pos
	    :for k :in commands :do
	    (setf b (get-command k)
		 doc (documentation (command-function b) 'function)
		 pos (position #\. doc))
	    :when (and b (or (and built-in (command-built-in-p b))
			     (and (not built-in) (not (command-built-in-p b)))))
	    :collect
	    (list
	     (command-name b)
	     ;; Only the first sentance, i.e. up to the first period,
	     ;; without newlines.
	     (substitute #\space #\newline
			 (if pos
			     (subseq doc 0 (1+ pos))
			     doc))))))
    (with-input-from-string
	(in-str (with-output-to-string (str)
		  (table:nice-print-table
		   rows nil :trailing-spaces nil
		   :stream str)))
      (with-lines (l in-str)
	;; add spaces in front and clip to screen columns
	(format t "  ~a~%" (subseq l 0 (min (length l)
					    (- (get-cols) 2))))))))

(defbuiltin help (("subject" help-subject :help "Subject to get help on."))
  "Show help on the subject. Without a subject show some subjects that are
available."
  (if (not subject)
      (progn
	(format t *basic-help* *version*))
      ;; topics
      (cond
	((equalp subject "builtins")
	 (let ((commands
		(sort
		 (loop :for k :being :the :hash-keys :of (lish-commands)
		    :collect k)
		 #'string-lessp)))
	   (format t "Built-in commands:~%")
	   (print-command-help commands :built-in t)))
	((equalp subject "commands")
	 (let ((commands
		(sort
		 (loop :for k :being :the :hash-keys :of (lish-commands)
		    :collect k)
		 #'string-lessp)))
	   (format t "Defined commands:~%")
	   (print-command-help commands :built-in nil)))
	((or (equalp subject "editor"))	 (format t *editor-help*))
	((or (equalp subject "syntax"))	 (format t *syntax-help*))
	((or (equalp subject "keys"))
	 (format t "Here are the keys active in the editor:~%")
	 (!bind :print-bindings t))
	(t ;; Try a specific command
	 (let* ((cmd  (get-command subject))
		(symb (intern (string-upcase subject) :lish))
		(doc  (when cmd (documentation cmd 'function)))
		(fdoc (when (fboundp symb)
			(documentation (symbol-function symb) 'function))))
;	   (print-values* (subject cmd symb doc fdoc))
	   (cond
	     (doc  (format t "~a~%" doc))
	     (fdoc (format t "Lisp function:~%~a~%" fdoc))
	     (cmd  (format t "Sorry, there's no help for \"~a\".~%" subject))
	     (t    (format t "I don't know about the subject \"~a\"~%"
			   subject))))))))

(defmethod documentation ((b command) (doctype (eql 'function)))
  "Return the documentation string for the given shell command."
  (with-output-to-string (str)
    (format str "~a" (posix-synopsis b))
    (when (documentation (command-function b) 'function)
      (format str "~%~a" (documentation (command-function b) 'function)))
#|    (when (command-loaded-from b)
      (format str "~%Loaded from ~a" (command-loaded-from b))) |#
    ))

(defun set-alias (name expansion &key global (shell *shell*))
  "Define NAME to be an alias for EXPANSION.
NAME is replaced by EXPANSION before any other evaluation."
  (setf (gethash name
		 (if global
		     (lish-global-aliases shell)
		     (lish-aliases shell)))
	expansion))

(defun unset-alias (name &key global (shell *shell*))
  "Remove the definition of NAME as an alias."
  (remhash name (if global
		    (lish-global-aliases shell)
		    (lish-aliases shell))))

(defun get-alias (name &key global (shell *shell*))
  (if global
      (gethash name (lish-global-aliases shell))
      (gethash name (lish-aliases shell))))

(defbuiltin alias
    (("global"    boolean :short-arg #\g
      :help "True to define a global alias.")
     ("name"      string :help "Name of the alias.")
     ("expansion" string :help "Text to expand to."))
  "Define NAME to expand to EXPANSION when starting a line."
  (if (not name)
      (loop :for a :being :the :hash-keys
	 :of (if global (lish-global-aliases *shell*) (lish-aliases *shell*))
	 :do
	 (format t "alias ~a ~:[is not defined~;~:*~w~]~%"
		 a (get-alias a :global global :shell *shell*)))
      (if (not expansion)
	  (format t "alias ~a ~:[is not defined~;~:*~w~]~%"
		  name (get-alias name :global global :shell *shell*))
	  (set-alias name expansion :global global :shell *shell*))))

(defbuiltin unalias
  (("global" boolean :short-arg #\g :help "True to define a global alias.")
   ("name" string :optional nil     :help "Name of the alias to forget."))
  "Remove the definition of NAME as an alias."
  (unset-alias name :global global :shell *shell*))

(defbuiltin exit (("values" string :repeating t :help "Values to return."))
  "Exit from the shell. Optionally return values."
  (when values
    (setf (lish-exit-values *shell*) (loop :for v :in values :collect v)))
  (setf (lish-exit-flag *shell*) t))

(defbuiltin source (("filename" pathname :optional nil
 		     :help "Filename to read."))
  "Evalute lish commands in the given file."
  (without-warning (load-file *shell* filename)))

;; XXX I wish this would work without using the :use-supplied-flag, just using
;; the default value of :toggle in boolean-toggle, but there is some kind of
;; bug or something about class default args at compile time that I don't
;; understand.

(defbuiltin debug
  (("state" boolean-toggle :help "State of debugging." :use-supplied-flag t))
  "Toggle shell debugging."
  (setf (lish-debug *shell*)
	(if (or (not state-supplied-p) (eql state :toggle))
	    (not (lish-debug *shell*))
	    state))
  (format t "Debugging is ~:[OFF~;ON~].~%" (lish-debug *shell*)))

;; WHY WHY WHY?
;; (format t "----------> ~(~w~)~%"
;;         (command-to-lisp-args
;;          (make-argument-list '(("state" boolean-toggle)))))

#|
;; Just use the version from dlib-misc	;
;; @@@ Or maybe the version from there should live here, since it's shellish?? ;
  (defun printenv (&optional original-order) ; copied from dlib-misc ;
"Like the unix command."
(let ((mv (reduce #'max (nos:environ)
:key #'(lambda (x) (length (symbol-name (car x))))))
(sorted-list (if original-order
(nos:environ)
(sort (nos:environ) #'string-lessp
:key #'(lambda (x) (symbol-name (car x)))))))
(loop :for v :in sorted-list
:do (format t "~va ~30a~%" mv (car v) (cdr v)))))
  |#

(defbuiltin export
    (("name"  string :help "Name of the variable to export.")
     ("value" string :help "Value of the variable to export."))
  "Set environment variable NAME to be VALUE. Omitting VALUE, just makes sure
the current value of NAME is exported. Omitting both, prints all the exported
environment variables. If NAME and VALUE are converted to strings if necessary."
  (when (and name (not (stringp name)))
    (setf name (princ-to-string name)))
  (when (and value (not (stringp value)))
    (setf value (princ-to-string value)))
  (if name
      (if value
	  (nos:setenv name value)
	  (nos:getenv name))		; Actually does nothing
      (printenv)))

(defbuiltin env
    (("ignore-environment" boolean :short-arg #\i
      :help "Ignore the environment.")
     ("variable-assignment" string :repeating t
      :help "Assingment to make in the environment.")
     ("shell-command" shell-command
      :help "Command to execute with the possibly modified environment.")
     ("arguments" object :repeating t
      :help "Arguments to the command."))
  "Modify the command environment. If ignore-environment"
  (if (and (not shell-command) (not arguments))
      ;; Just print variables
      (loop :for v :in variable-assignment
	 :do
	 (let ((var (if (position #\= v)
			(first (split-sequence #\= v))
			v)))
	   (when var
	     (format t "~a=~a~%" var (nos:getenv var)))))
      ;; Set variables and execute command
      (progn
	(loop :for v :in variable-assignment
	   :do
	   (let ((pos (position #\= v))
		 var val seq)
	     (if pos
		 (setf seq (split-sequence #\= v)
		       var (first seq)
		       val (third seq))
		 (setf var v))
	     (when (and var val)
	       (nos:setenv var val))))
	(apply #'do-system-command
	       `(,`(,shell-command ,@arguments)
		   ,@(if ignore-environment '(nil nil nil)))))))

(defun get-cols ()
  (let ((tty (tiny-rl::line-editor-terminal (lish::lish-editor *shell*))))
    (terminal-get-size tty)
    (terminal-window-columns tty)))

(defparameter *signal-names* (make-array
			      (list nos:*signal-count*)
			      :initial-contents
			      (cons ""
			        (loop :for i :from 1 :below nos:*signal-count*
				   :collect (nos:signal-name i))))
  "Names of the signals.")

(define-builtin-arg-type signal (arg-integer)
  "A system signal."
  ()
  :convert string
    (or (position value *signal-names* :test #'equalp)
	(parse-integer value)))

(defbuiltin kill
    (("list-signals" boolean :short-arg #\l
      :help "List available signals.")
     ("signal" 	     signal  :default   15
      :help "Signal number to send.")
     ("pids" 	     integer :repeating t
      :help "Process IDs to signal."))
  ;; @@@ pid should be job # type to support %job
  "Sends SIGNAL to PID."
  ;; @@@ totally faked & not working
  (if list-signals
      (format t (s+ "~{~<~%~1," (get-cols) ":;~a~> ~}~%") ; bogus, but v fails
	      (loop :for i :from 1 :below nos:*signal-count*
		 :collect (format nil "~2d) ~:@(~8a~)" i (nos:signal-name i))))
      (when pids
	(mapcar #'(lambda (x) (nos:kill signal x)) pids))))

;; Actually I think that "format" and "read" are a bad idea / useless, because
;; they're for shell scripting which you should do in Lisp.

;;; make printf an alias
(defbuiltin format
    (("format-string" string :optional nil :help "Format control string.")
     ("args" t :repeating t :help "Format arguments."))
  "Formatted output."
  ;; @@@ totally faked & not working
  (apply #'format t format-string args))

;; Since this is for scripting in other shells, I think we don't need to worry
;; about it, since the user can just call READ-LINE-like functions directly.
(defbuiltin read
    (("name"    string                 :help "Variable to read.")
     ("prompt"  string  :short-arg #\p :help "Prompt to print.")
     ("timeout" integer :short-arg #\t :help "Seconds before read times out.")
     ("editing" boolean :short-arg #\e :help "True to use line editing."))
  "Read a line of input."
  ;; @@@ totally faked & not working
  (declare (ignore timeout name))
  (if editing (tiny-rl:tiny-rl :prompt prompt)
      (read-line nil nil)))

(defbuiltin time (("command" string :repeating t :help "Command to time."))
  "Shows some time statistics resulting from the execution of COMMNAD."
  (time (shell-eval *shell* (make-shell-expr :words command))))

(defun print-timeval (tv &optional (stream t))
  (let* ((secs  (+ (timeval-seconds tv)
		   (/ (timeval-micro-seconds tv) 1000000)))
	 days hours mins)
    (setf days  (/ secs (* 60 60 24))
	  secs  (mod secs (* 60 60 24))
	  hours (/ secs (* 60 60))
	  secs  (mod secs (* 60 60))
	  mins  (/ secs 60)
	  secs  (mod secs 60))
    ;; (format t "days ~a hours ~a min ~a sec ~a~%"
    ;; 	    (floor days) (floor hours) (floor mins) secs)
    (format stream
	    "~@[~dd ~]~@[~dh ~]~@[~dm ~]~5,3,,,'0fs"
            (when (>= days 1) (floor days))
            (when (>= hours 1) (floor hours))
            (when (>= mins 1) (floor mins))
            secs)))

(defbuiltin times ()
  "Show accumulated times for the shell."
  (let ((self (getrusage :SELF))
	(children (getrusage :CHILDREN)))
    (format t "Self     User: ~a~32tSys: ~a~%"
	    (print-timeval (rusage-user self) nil)
	    (print-timeval (rusage-system self) nil))
    (format t "Children User: ~a~32tSys: ~a~%"
	    (print-timeval (rusage-user children) nil)
	    (print-timeval (rusage-system children) nil))))

(defbuiltin umask
    (("print-command" boolean :short-arg #\p
      :help "Print a command which sets the umask.")
     ("symbolic"      boolean :short-arg #\S
      :help "Output in symbolic mode.")
     ("mask"	     string
      :help "Mask to set."))
  "Set or print the default file creation mode mask (a.k.a. permission mask).
If mode is not given, print the current mode. If PRINT-COMMAND is true, print
the mode as a command that can be executed. If SYMBOLIC is true, output in
symbolic format, otherwise output in octal."
  (declare (ignore symbolic)) ;; @@@
  (if (not mask)
      ;; printing
      (let ((current-mask (nos:umask 0)))
	(nos:umask current-mask)
	(when print-command
	  (format t "umask "))
	;; (if symbolic
	;;     (format t "~a~%" (symbolic-mode-offset current-mask))
	;;     (format t "~o~%" current-mode)))
	(format t "~o~%" current-mask))
      ;; setting
      (progn
	(multiple-value-bind (real-mask err)
	    (ignore-errors (parse-integer mask :radix 8))
	  (when (typep err 'error)
	    (error err))
	  (nos:umask real-mask)))))

(defbuiltin ulimit ()
  "Examine or set process resource limits."
  (values))

(defbuiltin wait ()
  "Wait for commands to terminate."
  (values))

(defbuiltin exec (("command-words" t :repeating t
                    :help "Words of the command to execute."))
  "Replace the whole Lisp system with another program. This seems like a rather
drastic thing to do to a running Lisp system. Wouldn't you prefer a nice game
of chess?"
  (when command-words
    (let ((path (command-pathname (first command-words))))
      (format t "path = ~w~%command-words = ~w~%" path command-words)
      (nos:exec path command-words))))

(define-builtin-arg-type function (arg-symbol)
  "A function name."
  ()
  :convert string
  (find-symbol (string-upcase value)))

(define-builtin-arg-type key-sequence (arg-string)
  "A key sequence."
  ())

(defbuiltin bind
    (("print-bindings"		 boolean      :short-arg #\p
      :help "Print key bindings.")
     ("print-readable-bindings"	 boolean      :short-arg #\P
      :help "Print key bindings in a machine readable way.")
     ("query"			 function     :short-arg #\q
      :help "Ask what key invokes a function.")
     ("remove-function-bindings" function     :short-arg #\u
      :help "Remove the binding for FUNCTION.")
     ("remove-key-binding"	 key-sequence :short-arg #\r
      :help "Remove the binding for a KEY-SEQUENCE.")
     ("key-sequence"		 key-sequence
      :help "The key sequence to bind.")
     ("function-name"		 function
      :help "The function to bind the key sequence to."))
  "Manipulate key bindings."
  (when (> (count t (list print-bindings print-readable-bindings query
			  remove-function-bindings remove-key-binding)) 1)
    (error "Mutually exclusive arguments provided."))
  (cond
    (print-bindings
     (keymap:dump-keymap tiny-rl:*normal-keymap*))
    (print-readable-bindings
     (keymap:map-keymap
      #'(lambda (key val)
	  (format t "(keymap:define-key tiny-rl:*normal-keymap* ~w '~a)~%"
		  key val))
      tiny-rl:*normal-keymap*))
    ;; @@@ todo: query remove-function-bindings remove-key-binding
    ((and key-sequence (not function-name))
     (format t "~w: ~(~a~)~%" key-sequence
	     (keymap:key-sequence-binding
	      key-sequence tiny-rl:*normal-keymap*)))
    (query
     (if (not function-name)
	 (error "Missing function name.")
	 (keymap:map-keymap
	  #'(lambda (key val)
	      (when (equal val function-name)
		(format t "~w: ~a~%" key val)))
	  tiny-rl:*normal-keymap*)))
    ((and key-sequence function-name)
     (keymap:set-key key-sequence function-name tiny-rl:*normal-keymap*))))


#|
This is really just for simple things. You should probably use the
Lisp version instead.

This is what I might like to be able to say:
@ defcommand tf ((file filename :optional nil)) (! "file" ($$ "type -p" file))

Actually I think this whole thing is ill advised becuase of syntax mixing
problems. As a command the stuff in parens doesn't parse right, so it's
better just to use Lisp syntax.
|#

#|
(defbuiltin defcommand
    (("name"     string :optional nil)
     ("function" string :optional nil))
    "Defines a command which calls a function."
  (let (;(func-name (command-function-name name))
	(cmd-name (string-downcase name))
	(func-symbol (let ((*read-eval* nil))
		       (read-from-string (string-upcase function))))
	(cmd-symbol (intern (string name))))
    (if (fboundp func-symbol)
	(progn
	  (push cmd-symbol *command-list*)
	  (set-command cmd-name
		       (make-instance 'command
				      :name cmd-name
				      :function func-symbol
				      :arglist '())))
	(format t "~a is not a function" func-symbol))))
|#

#|
(defclass arg-command (arg-choice)
  ()
  (:default-initargs
   :choice-func #'verb-list)
  (:documentation "The name of a lish command."))
(defmethod convert-arg ((arg arg-command) (value string) &optional quoted)
  "Convert a string to a command."
  (get-command value))
|#

(defbuiltin undefcommand (("command" command :help "The command to forget."))
  "Undefine a command."
  (typecase command
    ((or string symbol)
     (undefine-command (string-downcase command)))
    (command
     (undefine-command (command-name command)))
    (t
     (error "I don't know how to undefine a command of type ~a."
	    (type-of command)))))

#|
(defun is-executable (s)
  (logand (file-status-mode s) S_IXUSR))

(defun is-regular (s)
  (logand (file-status-mode s) S_IXUSR))

(defun is-regular-executable (p)
  (let ((st (stat p)))
    (and st (is-executable st) (is-regular st))))
|#

(defun has-directory-p (p)
  (position *directory-separator* p))

(defun command-pathname (cmd)
  "Return the full pathname of the first executable file in the PATH or nil
if there isn't one."
  (when (has-directory-p cmd)
    (return-from command-pathname cmd))
  (loop :for dir :in (split-sequence *path-separator* (getenv "PATH")) :do
     (handler-case
       (when (probe-directory dir)
	 (loop :with full = nil
	    :for f :in (read-directory :dir dir) :do
	    (when (and (equal f cmd)
		       (is-executable
			(setf full (format nil "~a~c~a"
					   dir *directory-separator* cmd))))
	      (return-from command-pathname full))))
       (error (c) (declare (ignore c)))))
  nil)

(defun command-paths (cmd)
  "Return all possible command paths. Don't cache the results."
  (loop :with r = nil
    :for dir :in (split-sequence *path-separator* (getenv "PATH"))
    :do
    (setf r (when (probe-directory dir)
	      (loop :with full = nil
		    :for f :in (read-directory :dir dir)
		    :when (and (equal f cmd)
			       (is-executable
				(setf full
				      (format nil "~a~c~a"
					      dir *directory-separator* cmd))))
		    :return full)))
    :if r
    :collect r))

(defparameter *command-cache* nil
  "A hashtable which caches the of full names of commands.")

(defun get-command-path (cmd)
  "Return the possibly cached command path."
  (when (not *command-cache*)
    (setf *command-cache* (make-hash-table :test #'equal)))
  (let ((result (gethash cmd *command-cache*)))
    (when (not result)
      (let ((path (command-pathname cmd)))
	(when path
	  (setf (gethash cmd *command-cache*) path
		result path))))
    result))

(defbuiltin hash
    (("rehash" boolean :short-arg #\r
      :help "Forget about command locations.")
     ("commands" t :repeating t
      :help "Command to operate on."))
  "Show or forget remembered full pathnames of commands."
  (labels ((pr-cmd (c) (format t "~a~%" c)))
    (if rehash
	(if commands
	    (loop :for c :in commands :do
	       (remhash c *command-cache*))
	    (setf *command-cache* nil))
	(when *command-cache*
	  (if commands
	      (loop :for c :in commands :do
		 (pr-cmd (gethash c *command-cache*)))
	      (maphash #'(lambda (c p) (declare (ignore c)) (pr-cmd p))
		       *command-cache*))))))

;; Since this is based on phonetics, we would need phonetic dictionaries to do
;; this right.
(defun indefinite (str)
  (declare (type string str))
  "Return an approximately appropriate indefinite article for the given ~
string. Sometimes gets it wrong for words startings with 'U', 'O', or 'H'."
  (when (> (length str) 0)
    (let ((c (aref str 0)))
      (if (position c "aeiouAEIOU") "an" "a"))))

(defun command-type (sh command)
  "Return a string representing the command type of command."
  (cond
    ((gethash command (lish-commands))	        "command")
    ((gethash command (lish-aliases sh))        "alias")
    ((gethash command (lish-global-aliases sh)) "global alias")
    ((get-command-path command)		        "file")
    (t nil)))

(defun describe-command (cmd)
  (let (x)
    (cond
      ((setf x (gethash cmd (lish-aliases *shell*)))
       (when x
	 (format t "~a is aliased to ~a~%" cmd x)))
      ((setf x (gethash cmd (lish-global-aliases *shell*)))
       (when x
	 (format t "~a is a global alias for ~a~%" cmd x)))
      ((setf x (gethash cmd (lish-commands)))
       (when x
	 (format t "~a is the command ~a~%" cmd x)))
      ((setf x (get-command-path cmd))
       (when x
	 (format t "~a is ~a~%" cmd x)))
      ((setf x (read-from-string cmd))
       (when (and (symbolp x) (fboundp x))
	 (format t "~a is the function ~s~%" cmd (symbol-function x)))))))

(defbuiltin type
    (("type-only" boolean :short-arg #\t
      :help "Show only the type of the name.")
     ("path-only" boolean :short-arg #\p
      :help "Show only the path of the name.")
     ("all" 	  boolean :short-arg #\a
      :help "Show all definitions of the name.")
     ("names" 	  string  :repeating t
      :help "Names to describe."))
  "Describe what kind of command the name is."
  (when names
    (loop :with args = names :and n = nil :and did-one
       :while args :do
       (setf n (car args)
	     did-one nil)
       (cond
	 (path-only
	  (let ((paths (command-paths n)))
	    (when paths
	      (format t "~a~%" (first paths)))))
	 (all
	  (let ((x (gethash n (lish-aliases *shell*))))
	    (when x
	      (format t "~a is aliased to ~a~%" n x)
	      (setf did-one t)))
	  (let ((x (gethash n (lish-global-aliases *shell*))))
	    (when x
	      (format t "~a is globally aliased to ~s~%" n x)
	      (setf did-one t)))
	  (let ((x (gethash n (lish-commands))))
	    (when x
	      (format t "~a is the command ~a~%" n x)
	      (setf did-one t)))
	  (let ((paths (command-paths n)))
	    (when paths
	      (format t (format nil "~~{~a is ~~a~~%~~}" n)
		      paths)
	      (setf did-one t)))
	  (let* ((obj (read-from-string n)))
	    (when (and (symbolp obj) (fboundp obj))
	      (format t "~a is the function ~s~%" n (symbol-function obj))
	      (setf did-one t)))
	  (when (not did-one)
	    (format t "~a in unknown~%" n)))
	 (t
	  (let ((tt (command-type *shell* n)))
	    (if tt
	      (if type-only
		  (format t "~a~%" tt)
		  (describe-command n))
	      (format t "~a is unknown~%" n)))))
	 (setf args (cdr args)))))

(defbuiltin stats
    (("command" choice :choices ("save" "show")
      :help "What to do with the statistics."))
  "Show command statistics."
  (cond
    ((equal command "save")
     (format t "Stats saved in ~a.~%" (save-command-stats)))
    ((equal command "show")
     (show-command-stats))
    (t
     (show-command-stats))))

(defbuiltin opt
  (("readable" boolean :short-arg #\r
    :help "True to output options that are re-readable by the shell.")
   ("name"  option :help "Option to set.")
   ("value" object :help "Value to set option to." :use-supplied-flag t))
  "Examine or set shell options."
  (if name
      (if value-supplied-p
	  (set-option *shell* name value)
	  (format t "~w~%" (get-option *shell* name)))
      (if readable
	  (loop :for o :in (lish-options *shell*) :do
	     (format t "opt ~a ~w~%" (arg-name o) (arg-value o)))
	  (print-properties
	   (loop :for o :in (lish-options *shell*)
	      :collect (list (arg-name o) (format nil "~s" (arg-value o))))
	   :de-lispify nil :right-justify t))))
      
;; EOF
