;;
;; xterm-control.lisp - Control an XTerm compatible terminal.
;;

(defpackage :xterm-control
  (:documentation "Control an XTerm compatible terminal.")
  (:use :cl :dlib :dlib-misc :char-util :keymap :terminal :terminal-ansi
	:inator :terminal-inator :rl :ppcre :color)
  (:export
   #:control-xterm
   #:!xterm-control
   ))
(in-package :xterm-control)

(declaim (optimize (speed 0) (safety 0) (debug 3) (space 0) (compilation-speed 0)))

(defun iconify (state)
  (tt-format "~a~at" +csi+ (if state 2 1))
  (tt-finish-output))

(defun move-to (x y)
  (tt-format "~a~a;~a;~at" +csi+ 3 x y)
  (tt-finish-output))

(defun resize-pixels (width height)
  (tt-format "~a~a;~a;~at" +csi+ 4 width height)
  (tt-finish-output))

(defun resize-characters (width height)
  (tt-format "~a~a;~a;~at" +csi+ 8 height width)
  (tt-finish-output))

(defun raise ()
  (tt-format "~a~at" +csi+ 5)
  (tt-finish-output))

(defun lower ()
  (tt-format "~a~at" +csi+ 6)
  (tt-finish-output))

(defun refresh-term ()
  (tt-format "~a~at" +csi+ 7)
  (tt-finish-output))

;; I would like to use this to toggle, but it doesn't seem to work quite right.
;; (tt-format "~c[10;2t" #\escape)
(defun set-fullscreen (state)
  (tt-format "~a10;~dt" +csi+ (if state 1 0))
  (tt-finish-output))

(defun set-utf8-title-mode (state)
  (tt-format "~c[>2;3~c" #\escape (if state #\t #\T))
  (tt-finish-output))

(defun set-title (title &optional (which :window))
  (let ((param (case which
		 (:window 2)
		 (:icon 1)
		 (:both 0))))
    (tt-format "~a~a;~a~c" +osc+ param title (char-util:ctrl #\G))
    ;;(tt-format "~a~a;~a~a" +osc+ param title +st+)
    (tt-finish-output)))

(defun get-title (&optional (which :window))
  (set-utf8-title-mode t)
  (let ((param (case which
		 (:icon "20")
		 (:window "21")
		 (otherwise "21"))))
    (query-string (s+ param "t"))))

(defun edit-title (&optional (which :window))
  (let ((title (get-title which)) result)
    (tt-home)
    (tt-finish-output)
    (setf result
    	  (rl:rl :prompt (format nil "~:(~a~) Title: " which)
		 :string (or title "")
		 :terminal-class 'terminal-ansi:terminal-ansi
		 :accept-does-newline nil))
    (when result
      (set-title result which))
    (terminal-start *terminal*)
    (tt-beginning-of-line)
    (tt-erase-to-eol)
    (or result title)))

(defun get-font ()
  (query-string (format nil "50;?~c" (char-util:ctrl #\G))
		:lead-in +osc+ :offset 3 :ending 1))

(defun set-font (font)
  (tt-format "~a50;~a~c" +osc+ font (char-util:ctrl #\G))
  (tt-finish-output))

(defun edit-font ()
  (let ((font (get-font)) result)
    (tt-home)
    (tt-finish-output)
    (setf result
	  (rl:rl :prompt "Font: "
		 :string (or font "")
		 :terminal-class 'terminal-ansi:terminal-ansi
		 :accept-does-newline nil))
    (when result
      (set-font result))
    (terminal-start *terminal*)
    (tt-beginning-of-line)
    (tt-erase-to-eol)
    (or result font)))

(defkeymap *xterminator-keymap*
  `((#\escape		  . *xterminator-escape-keymap*)
    (,(ctrl #\G)	  . quit)
    (#\q	  	  . quit)
    (#\i		  . increment-increment)
    (#\I		  . decrement-increment)

    (#\return		  . edit-window-title)
    (,(meta-char #\I)	  . edit-icon-title)
    (,(meta-char #\F)	  . edit-font-name)
    ;;(#\w		  . edit-window-title)
    ;;(#\i	  	  . edit-icon-title)
    ;;(#\x	  	  . edit-font-name)

    (#\f		  . toggle-fullscreen)
    (#\F		  . fullscreen-on)
    (,(ctrl #\F)	  . fullscreen-off)

    (:down		  . down-multiple)
    (:up		  . up-multiple)
    (:left		  . backward-multiple)
    (:right		  . forward-multiple)

    (#\j		  . down-multiple)
    (#\k		  . up-multiple)
    (#\h		  . backward-multiple)
    (#\l		  . forward-multiple)

    (#\J		  . next)
    (#\K		  . previous)
    (#\H		  . backward-unit)
    (#\L		  . forward-unit)

    (#\]		  . move-to-bottom)
    (,(meta-char #\>)     . move-to-bottom)
    (:end		  . move-to-bottom)
    (#\[		  . move-to-top)
    (,(meta-char #\<)     . move-to-top)
    (:home		  . move-to-top)

    (,(ctrl #\V)	  . expand-height-chars)
    (:npage		  . expand-height-chars)
    (,(meta-char #\v)	  . shrink-height-chars)
    (:ppage		  . shrink-height-chars)

    (#\+		  . expand-height-chars)
    (#\-	  	  . shrink-height-chars)
    (#\>		  . expand-width-chars)
    (#\<	  	  . shrink-width-chars)
    (#\,		  . shrink-height-chars)
    (#\.	  	  . expand-height-chars)

    (#\r		  . decrement-background-red)
    (#\R		  . increment-background-red)
    (#\g		  . decrement-background-green)
    (#\G		  . increment-background-green)
    (#\b		  . decrement-background-blue)
    (#\B		  . increment-background-blue)

    (#\1		  . decrement-foreground-red)
    (#\!		  . increment-foreground-red)
    (#\2		  . decrement-foreground-green)
    (#\@		  . increment-foreground-green)
    (#\3		  . decrement-foreground-blue)
    (#\#		  . increment-foreground-blue)
    
    (#\8		  . decrement-background-red)
    (#\*		  . increment-background-red)
    (#\9		  . decrement-background-green)
    (#\(		  . increment-background-green)
    (#\0		  . decrement-background-blue)
    (#\)		  . increment-background-blue)

    ;;(,(meta-char #\=)	  . pick-list-binding-of-key)
    (#\?		  . help)
    ))

(defparameter *xterminator-escape-keymap*
  (build-escape-map *xterminator-keymap*))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ANSI-inator

#|
(defclass ansi-inator (inator)
  ()
  (:documentation "A ansi-terminal-inator."))

(defmethod initialize-instance
    :after ((o ansi-inator) &rest initargs &key &allow-other-keys)
  "Initialize a ansi-inator."
  (declare (ignore initargs)))

;; (defmethod start-inator ((i ansi-inator))
;;   "Start a ANSI-INATOR."
;;   (terminal-start i)
;;   (call-next-method))

;; (defmethod finish-inator ((i ansi-inator))
;;   "Stop a ANSI-INATOR."
;;   (terminal-end i)
;;   (call-next-method))

(defmethod update-display ((i ansi-inator))
  "Update the view of a ANSI-INATOR."
  (call-next-method)
  (tt-finish-output))

(defmethod await-event ((i ansi-inator))
  "Get an event from a ANSI-INATOR."
  (declare (ignore i))
  (tt-get-key))

(defmethod message ((i ansi-inator) format-string &rest args)
  "Display a short message."
  (tt-move-to (1- (terminal-window-rows *terminal*)) 0)
  (tt-erase-to-eol)
  ;; We use terminal-format here because tt-format is a macro.
  (apply #'terminal-format *terminal* format-string args))

#|
(defun inator-doc-finder (i func)
  "Find documentation for an inator (subclass) method."
  (when (fboundp func)
    (let ((method
	   (and (typep (symbol-function func) 'generic-function)
		(find-method (symbol-function func) '()
			     (list (class-of i)) nil))))
      (when method (documentation method t)))))

(defmethod help ((i ansi-inator))
  "Show help for the inator."
  (typecase (inator-keymap i)
    (keymap
     (display-text "Help"
		   (help-list (inator-keymap i) (_ (inator-doc-finder i _)))
		   :justify nil))
    (list
     (display-text "Help"
		   (loop :for k :in (inator-keymap i)
		      :append
		      (help-list k (_ (inator-doc-finder i _))))
		   :justify nil))))
|#

(defmethod redraw ((i ansi-inator))
  "Redraw the screen."
  (tt-clear)
  (tt-finish-output)
  (update-display i))

|#

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defclass xterminator (terminal-inator)
  ((x
    :initarg :x :accessor xterminator-x  :type integer
    :documentation "X coordinate in pixels.")
   (y
    :initarg :y :accessor xterminator-y  :type integer
    :documentation "Y coordinate in pixels.")
   (char-width
    :initarg :width :accessor xterminator-char-width  :type integer
    :documentation "Width in character cells.")
   (char-height
    :initarg :char-height :accessor xterminator-char-height  :type integer
    :documentation "Height in character cells.")
   (pixel-width
    :initarg :pixel-width :accessor xterminator-pixel-width  :type integer
    :documentation "Width in pixels.")
   (pixel-height
    :initarg :pixel-height :accessor xterminator-pixel-height  :type integer
    :documentation "Height in pixels.")
   (screen-char-width
    :initarg :screen-char-width :accessor xterminator-screen-char-width
    :type integer
    :documentation "Width of the screen in characters.")
   (screen-char-height
    :initarg :screen-char-height :accessor xterminator-screen-char-height
    :type integer
    :documentation "Height of the screen in characters.")
   (fullscreen
    :initarg :fullscreen :accessor xterminator-fullscreen :initform nil
    :type boolean
    :documentation "True if the window is in fullscreen mode.")
   (background
    :initarg :background :accessor xterminator-background  
    :documentation "Background color.")
   (foreground
    :initarg :foreground :accessor xterminator-foreground  
    :documentation "Foreground color.")
   (title
    :initarg :title :accessor xterminator-title
    :documentation "Window title.")
   (icon-title
    :initarg :icon-title :accessor xterminator-icon-title  
    :documentation "Icon title.")
   (font
    :initarg :font :accessor xterminator-font
    :documentation "Font name as XLFD or TrueType if enabled.")
   (increment
    :initarg :increment :accessor xterminator-increment :initform 20
    :type integer
    :documentation "Size to increment.")
   (initialize-all
    :initarg :initialize-all :accessor xterminator-initialize-all
    :initform nil :type boolean
    :documentation "True to initialize all parameters.")
   )
  (:documentation "XTerm compatible terminal manipulator."))

(defun get-xterm-parameter (o parameter)
  (let (result)
    ;; location
    (when (find parameter '(x y))
      (when (not (slot-boundp o parameter))
	(if (setf result (query-parameters "13t"))
	    (setf (slot-value o 'x) (elt result 1)
		  (slot-value o 'y) (elt result 2))
	    (setf (slot-value o 'x) 0
		  (slot-value o 'y) 0)))
      (slot-value o parameter))

    ;; pixel size
    (when (find parameter '(pixel-width pixel-height))
      (when (not (slot-boundp o parameter))
	(if (setf result (query-parameters "14t"))
	    (setf (slot-value o 'pixel-width) (elt result 2)
		  (slot-value o 'pixel-height) (elt result 1))
	    (setf (slot-value o 'pixel-width) 0
		  (slot-value o 'pixel-height) 0)))
      (slot-value o parameter))

    ;; character size
    (when (find parameter '(char-height char-width))
      (when (not (slot-boundp o parameter))
	(if (setf result (query-parameters "18t"))
	    (setf (slot-value o 'char-width) (elt result 2)
		  (slot-value o 'char-height) (elt result 1))
	    (setf (slot-value o 'char-width) 0
		  (slot-value o 'char-height) 0)))
      (slot-value o parameter))

    ;; screen size
    (when (find parameter '(screen-char-width screen-char-height))
      (when (not (slot-boundp o parameter))
	(if (setf result (query-parameters "19t"))
	    (setf (slot-value o 'screen-char-width) (elt result 2)
		  (slot-value o 'screen-char-height) (elt result 1))
	    (setf (slot-value o 'screen-char-width) 0
		  (slot-value o 'screen-char-height) 0)))
      (slot-value o parameter))

    ;; Try to figure out fullscreen
    (when (eq parameter 'fullscreen)
      (when (not (slot-boundp o parameter))
	(setf (slot-value o 'fullscreen)
	      (and (not (zerop (slot-value o 'screen-char-width)))
		   (= (slot-value o 'screen-char-width)
		      (slot-value o 'char-width))
		   (= (slot-value o 'screen-char-height)
		      (slot-value o 'char-height)))))
      (slot-value o parameter))

    ;; Foreground & background colors
    (when (find parameter '(foreground background))
      (when (not (slot-boundp o parameter))
	(setf (slot-value o 'foreground)
	      (and-<> (foreground-color)
		      (convert-color-to <> :rgb8))
	      (slot-value o 'background)
	      (and-<> (background-color)
		      (convert-color-to <> :rgb8))))
      (slot-value o parameter))

    ;; title
    (when (eq parameter 'title)
      (when (not (slot-boundp o parameter))
	(setf (slot-value o 'title) (get-title)))
      (slot-value o parameter))

    ;; icon
    (when (eq parameter 'icon-title)
      (when (not (slot-boundp o parameter))
	(setf (slot-value o 'icon-title) (get-title :icon)))
      (slot-value o parameter))

    (when (eq parameter 'font)
      (when (not (slot-boundp o parameter))
	(setf (slot-value o 'font) (get-font)))
      (slot-value o parameter))))

(defun get-xterm-parameters (o)
  (with-slots (x y pixel-width pixel-height char-width char-height
	       screen-char-width screen-char-height fullscreen
	       background foreground title icon-title font) o
    (let (result)
      ;; location
      (if (setf result (query-parameters "13t"))
	  (setf x (elt result 1) y (elt result 2))
	  (setf x 0 y 0))
      ;; pixel size
      (if (setf result (query-parameters "14t"))
	  (setf pixel-width (elt result 2)
		pixel-height (elt result 1))
	  (setf pixel-width 0
		pixel-height 0))
      ;; character size
      (if (setf result (query-parameters "18t"))
	  (setf char-width (elt result 2)
		char-height (elt result 1))
	  (setf char-width 0
		char-height 0))
      ;; screen size
      (if (setf result (query-parameters "19t"))
	  (setf screen-char-width (elt result 2)
		screen-char-height (elt result 1))
	  (setf screen-char-width 0
		screen-char-height 0))
      ;; Try to figure out fullscreen
      (setf (slot-value o 'fullscreen)
	    (and (not (zerop screen-char-width))
		 (= screen-char-width char-width)
		 (= screen-char-height char-height)))
      ;; Foreground & background colors
      (setf foreground (and-<> (foreground-color)
			       (convert-color-to <> :rgb8))
	    background (and-<> (background-color)
			       (convert-color-to <> :rgb8)))
      ;; title
      (setf title (get-title))
      ;; icon
      (setf icon-title (get-title :icon))
      (setf font (get-font)))))

(defmethod initialize-instance
    :after ((o xterminator) &rest initargs &key &allow-other-keys)
  "Initialize a xterminator."
  (when (or (and (slot-boundp o 'initialize-all)
		 (slot-value o 'initialize-all))
	    (getf initargs :initialize-all))
    (format t "Initializing all..~%")
    (get-xterm-parameters o)))

(defvar *xterminator* nil
  "Dynamic xterminator instance.")

(defmethod next ((i xterminator))
  "Move the window down."
  (incf (xterminator-y i))
  (move-to (xterminator-x i) (xterminator-y i)))

(defmethod previous ((i xterminator))
  "Move the window up."
  (when (> (xterminator-y i) 0)
    (decf (xterminator-y i))
    (move-to (xterminator-x i) (xterminator-y i))))

(defmethod forward-unit ((i xterminator))
  "Move the window right."
  (incf (xterminator-x i))
  (move-to (xterminator-x i) (xterminator-y i)))

(defmethod backward-unit ((i xterminator))
  "Move the window left."
  (when (> (xterminator-x i) 0)
    (decf (xterminator-x i))
    (move-to (xterminator-x i) (xterminator-y i))))

(defmethod forward-multiple ((i xterminator))
  "Move the window right by some."
  (incf (xterminator-x i) (xterminator-increment i))
  (move-to (xterminator-x i) (xterminator-y i)))

(defmethod backward-multiple ((i xterminator))
  "Move the window left by some."
  (with-slots (x y increment) i
    (if (> (- x increment) 0)
	(decf x increment)
	(setf x 0))
    (move-to x y)))

(defun up-multiple (i)
  "Move the window up by some."
  (with-slots (x y increment) i
    (if (> (- y increment) 0)
	(decf y increment)
	(setf y 0))
    (move-to x y)))

(defun down-multiple (i)
  "Move the window down by some."
  (incf (xterminator-y i) (xterminator-increment i))
  (move-to (xterminator-x i) (xterminator-y i)))

(defun shrink-width-pixels (i)
  "Shrink the window width by pixels."
  (with-slots (pixel-width pixel-height increment) i
    (decf pixel-width increment)
    (resize-pixels pixel-width pixel-height)))

(defun shrink-height-pixels (i)
  "Shrink the window height by pixels."
  (with-slots (pixel-width pixel-height increment) i
    (decf pixel-height increment)
    (resize-pixels pixel-width pixel-height)))

(defun expand-width-pixels (i)
  "Expand the window width by pixels."
  (with-slots (pixel-width pixel-height increment) i
    (incf pixel-width increment)
    (resize-pixels pixel-width pixel-height)))

(defun expand-height-pixels (i)
  "Expand the window height by pixels."
  (with-slots (pixel-width pixel-height increment) i
    (incf pixel-height increment)
    (resize-pixels pixel-width pixel-height)))

(defun shrink-width-chars (i)
  (with-slots (char-width char-height increment) i
    (decf char-width)
    (resize-characters char-width char-height)))

(defun shrink-height-chars (i)
  (with-slots (char-width char-height) i
    (decf char-height)
    (resize-characters char-width char-height)))

(defun expand-width-chars (i)
  "Expand the window width by characters."
  (with-slots (char-width char-height) i
    (incf char-width)
    (resize-characters char-width char-height)))

(defun expand-height-chars (i)
  "Expand the window height by characters."
  (with-slots (char-width char-height) i
    (incf char-height)
    (resize-characters char-width char-height)))

(defmethod move-to-top ((i xterminator))
  "Raise the window."
  (raise))

(defmethod move-to-bottom ((i xterminator))
  "Lower the window."
  (lower))

(defmethod redraw ((i xterminator))
  "Lower the window."
  (refresh-term))

(defun toggle-fullscreen (i)
  (with-slots (fullscreen) i
    (setf fullscreen (not fullscreen))
    (set-fullscreen fullscreen)))

(defun fullscreen-on (i)
  (with-slots (fullscreen) i
    (set-fullscreen (setf fullscreen t))))

(defun fullscreen-off (i)
  (with-slots (fullscreen) i
    (set-fullscreen (setf fullscreen nil))))

;; color changer
(defmacro def-cc (dir slot element) 
  "Wiggida wiggida wack mac ro yo!"
  (declare (type (member inc dec) dir)
	   (type (member background foreground) slot)
	   (type (member red green blue) element))
  (let ((fun    (symbolify (s+ dir "rement-" slot "-" element)))
	(kw     (keywordify element))
	(setter (symbolify (s+ "set-" slot "-color")))
	(minimax (if (eq dir 'inc) 'min 'max))
	(op      (if (eq dir 'inc) '+ '-))
	(val     (if (eq dir 'inc) 255 0)))
    `(defun ,fun (i)
       (with-slots (,slot increment) i
	 (when ,slot
	   (setf (color-component ,slot ,kw)
		 (,minimax ,val (,op (color-component ,slot ,kw) increment)))
	   (,setter ,slot))))))

(def-cc dec background red)
(def-cc dec background green)
(def-cc dec background blue)
(def-cc inc background red)
(def-cc inc background green)
(def-cc inc background blue)

(def-cc dec foreground red)
(def-cc dec foreground green)
(def-cc dec foreground blue)
(def-cc inc foreground red)
(def-cc inc foreground green)
(def-cc inc foreground blue)

(defun increment-increment (i)
  "Add one to the increment."
  (incf (xterminator-increment i)))

(defun decrement-increment (i)
  "Subtract one from the increment."
  (decf (xterminator-increment i)))

(defun edit-window-title (i)
  (setf (xterminator-title i) (edit-title :window)))

(defun edit-icon-title (i)
  (setf (xterminator-icon-title i) (edit-title :icon)))

(defun edit-font-name (i)
  (setf (xterminator-font i) (edit-font)))

(defmethod update-display ((i xterminator))
  (with-slots (x y char-width char-height pixel-width pixel-height fullscreen
	       foreground background title icon-title font increment)
      *xterminator*
    (tt-clear)
    (tt-move-to 1 0)
    (tt-write-string
     (with-output-to-string (str)
       (print-values*
	(title icon-title font
	       x y char-width char-height pixel-width pixel-height
	       fullscreen foreground background increment)
	str)))
    (tt-scroll-down 1)
    (tt-format "hjkl     - Move window (HJKL by pixel)~%~
                <>,.     - Resize window~%~
                f        - Toggle fullscreen~%~
                [ ]      - Raise / Lower~%~
                ^M       - Edit window title~%~
                M-i      - Edit icon title~%~
                M-f      - Edit font~%~
                123 !@#  - Adjust foreground color down/up (red blue green)~%~
                890 *()  - Adjust background color down/up (red blue green)~%~
		iI       - Adjust increment down/up.~%~
                q        - Quit~%")))

(defun control-xterm ()
  (with-terminal (:ansi)
    (let ((*xterminator*
	   (make-instance 'xterminator
			  :keymap (list *xterminator-keymap*
					*default-inator-keymap*))))
      (event-loop *xterminator*))))

#+lish
(lish:defcommand xterm-control
  ((iconify boolean :short-arg #\i :help "Iconify the terminal.")
   (x integer :short-arg #\x
    :help "Set the window's horizontal position.")
   (y integer :short-arg #\y
    :help "Set the window's vertical position.")
   (width integer :short-arg #\w
    :help "Set the window's horizontal size.")
   (height integer :short-arg #\h
    :help "Set the window's vertical size.")
   (raise boolean :short-arg #\r
    :help "Raise the window in the stacking order.")
   (lower boolean :short-arg #\l
    :help "Lower the window in the stacking order.")
   (toggle-fullscreen boolean :short-arg #\f
    :help "True to toggle the window's fullscreen state.")
   (fullscreen boolean :short-arg #\F
    :help "Set the window's fullscreen state.")
   (title string :short-arg #\t :help "Set the window's title.")
   (get-title boolean :short-arg #\g :help "Get the window's title.")
   (icon-title string :short-arg #\T :help "Set the icon's title.")
   (get-icon-title boolean :short-arg #\G :help "Get the icon's title.")
   (font string :long-arg "font" :help "Set the font.")
   (get-font boolean :long-arg "get-font" :help "Get the font.")
   (get-parameter choice :short-arg #\p
    :choices '(title icon-title font x y char-width char-height
	       pixel-width pixel-height fullscreen foreground background)
    :repeating t
    :help "Get an parmeter value.")
   )
  "Control an XTerm comaptible terminal. If no arguments are given, go into an
interactive control mode."
  (if (or iconify x y width height raise lower toggle-fullscreen fullscreen
	  title get-title icon-title get-icon-title font get-font get-parameter)
      (let (xt)
	(when (and raise lower)
	  (error "I can't both raise and lower the window."))
	(when (and toggle-fullscreen fullscreen)
	  (error "I can't both set and toggle fullscreen mode."))
	(when (or x y)
	  (move-to (or x "") (or y "")))
	(when (or width height)
	  (setf xt (or xt (make-instance 'xterminator)))
	  (resize-characters (or width (xterminator-char-width xt))
			     (or height (xterminator-char-height xt))))
	(when title (set-title title))
	(when icon-title (set-title title :icon))
	(when font (set-font font))
	(when toggle-fullscreen
	  (setf xt (or xt (make-instance 'xterminator)))
	  (set-fullscreen (not (xterminator-fullscreen xt))))
	(when fullscreen (set-fullscreen fullscreen))
	(when raise (raise))
	(when lower (lower))
	(when iconify (iconify t))
	(when get-title (format t "~a~%" (get-title)))
	(when get-icon-title (format t "~a~%" (get-title :icon)))
	(when get-font (format t "~a~%" (get-font)))
	(when get-parameter
	  (let ((x (make-instance 'xterminator :initizlize-all nil))
		(params (mapcar (_ (intern (string-upcase _) :xterm-control))
				get-parameter)))
	    ;; (format t "~s ~s~%" params (symbol-package (car params)))
	    (setf lish:*output*
		  (if (= (length get-parameter) 1)
		      (progn
			(get-xterm-parameter x (car params))
			(slot-value x (car params)))
		      (loop :for p :in params
			 :do (get-xterm-parameter x p)
			 :collect (keywordify p)
			 :collect (slot-value x p)))))))
      (control-xterm)))

;; EOF
