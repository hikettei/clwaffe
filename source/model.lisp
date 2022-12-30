
(in-package :cl-waffe)

(defun call (model &rest args)
  (let ((result (apply (slot-value model 'forward) model args)))
    (setf (slot-value result 'backward) (slot-value model 'backward))
    (setf (slot-value result 'state) model) ; last state
    (setf (slot-value result 'variables) (coerce args 'list))
    result))

(defmacro defnode (name args &key parameters forward backward)
  `(defmodel ,name ,args :parameters ,parameters :forward ,forward :backward ,backward :hide-from-tree T))

(defmacro defmodel (name args &key parameters forward backward hide-from-tree)
  (labels ((assure-args (x)
	     (if (or (equal (symbol-name x) "forward")
		     (equal (symbol-name x) "backward")
		     (equal (symbol-name x) "hide-from-tree")
		     (equal (symbol-name x) "self")) ; i am not sure if it is really enough
		 (error "the name ~a is not allowed to use" (symbol-name x))
		 x)))
    (unless forward
      (error "insufficient forms"))
    `(defmacro ,name (&rest init-args &aux (c (gensym)))
       `(progn
	  (defstruct (,(gensym (symbol-name ',name))
		     (:constructor ,c (,@',args &aux ,@',parameters)))
	    ,@',(map 'list (lambda (x) (assure-args (car x))) parameters)
	   (hide-from-tree ,',hide-from-tree)
	   (forward ,',(let ((largs (car forward))
			     (lbody (cdr forward))
			     (self-heap (gensym)))
			 `(dolist (i ,largs) (assure-args i))
			 `(lambda ,(concatenate 'list (list self-heap) largs)
			    (macrolet ((self (name)
					 `(slot-value ,',self-heap ',name)))
			      ,@lbody))))
	   (backward ,',(if backward
			    (let ((largs (car backward))
				  (lbody (cdr backward))
				  (self-heap (gensym)))
			      `(dolist (i ,largs) (assure-args i))
			      `(lambda ,(concatenate 'list (list self-heap) largs)
				 (macrolet ((self (name)
					      `(slot-value ,',self-heap ',name)))
				   ,@lbody)))
			    nil)))
	 (,c ,@init-args)))))

