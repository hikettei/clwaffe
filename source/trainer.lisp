
(in-package :cl-waffe)


(defmacro deftrainer (name args &key model optimizer optimizer-args step-model (forward NIL))
  (if forward (error ":forward is unavailable in deftrainer macro. use instead: :step-model"))
  (labels ((assure-args (x)
		     (if (or (eq (symbol-name x) "model")
			     (eq (symbol-name x) "optimizer")
			     (eq (symbol-name x) "step"))
			 (error "cant use ~a as a name" (symbol-name x))
			 x)))
     `(defmacro ,name (&rest init-args &aux (constructor-name (gensym)))
	`(progn
	  (defstruct (,(gensym (symbol-name ',name))
		      (:print-function (lambda (trainer stream _)
					 (declare (ignore trainer _))
					 (format stream "[Trainer of ___]")))
		      (:constructor ,constructor-name (,@',(map 'list (lambda (x) (assure-args x)) args)
						       &aux (model ,',model)
							 (optimizer (cl-waffe.optimizers:init-optimizer ,',optimizer
													model
													,@',optimizer-args)))))
		     (model NIL)
		     (optimizer NIL)
		     (step-model ,',(let ((largs (car step-model))
					  (lbody (cdr step-model))
					  (self-heap (gensym)))
				      `(lambda ,(concatenate 'list (list self-heap) largs)
					 (macrolet ((model     ()            `(slot-value ,',self-heap 'model))
						    (update    (&rest args1) `(call (slot-value ,',self-heap 'optimizer) ,@args1))
						    (zero-grad ()            `(funcall (slot-value (slot-value ,',self-heap 'optimizer) 'backward)
										       (slot-value ,',self-heap 'optimizer) ,',model)))
					    ,@lbody)))))
	  (,constructor-name ,@init-args)))))

(defun step-model (trainer &rest args)
  (apply (slot-value trainer 'step-model) trainer args))

(defun step-model1 (trainer args)
  (apply (slot-value trainer 'step-model) trainer args))

(defmacro defdataset (name args &key parameters forward length)
  (labels ((assure-args (x)
		     (if (or (eq (symbol-name x) "parameters")
			     (eq (symbol-name x) "forward")
			     (eq (symbol-name x) ""))
			 (error "cant use ~a as a name" (symbol-name x))
			 x)))
    (unless forward
      (error ""))
    (unless length
      (error ""))
     `(defmacro ,name (&rest init-args &aux (constructor-name (gensym)))
	`(progn
	  (defstruct (,(gensym (symbol-name ',name))
		      (:print-function (lambda (trainer stream _)
					 (declare (ignore trainer _))
					 (format stream "[Dataset of ___]")))
		      (:constructor ,constructor-name (,@',args &aux ,@',parameters)))
	    ,@',(map 'list (lambda (x) (assure-args (car x))) parameters)
	    (length ,',(let ((largs (car length))
			     (lbody (cdr length))
			     (self-heap (gensym)))
			 `(lambda ,(concatenate 'list (list self-heap) largs)
			    (macrolet ((self (name) `(slot-value ,',self-heap ',name)))
			      ,@lbody))))
	    (forward    ,',(let ((largs (car forward))
				 (lbody (cdr forward))
				 (self-heap (gensym)))
			     `(lambda ,(concatenate 'list (list self-heap) largs)
				(macrolet ((self (name) `(slot-value ,',self-heap ',name)))
				  ,@lbody)))))
	  (,constructor-name ,@init-args)))))

(defun get-dataset (dataset index)
  (funcall (slot-value dataset 'forward) dataset index))

(defun get-dataset-length (dataset)
  (apply (slot-value dataset 'length) (list dataset)))

(defun train (trainer dataset &key (enable-animation t)
		                (epoch 1)
			     	(max-iterate nil)
				(verbose t)
				(stream t)
				(progress-bar-freq 1)
				(save-model-path nil)
				(width 20)
				(height 5)
				(color :while))
  (let ((losses `(0.0))
	(status-bar nil))
    (if (and enable-animation verbose)
	(cl-cram:init-progress-bar status-bar (format nil "loss:~a" (first losses)) (get-dataset-length dataset)))
    (dotimes (epoch-num epoch)
      (if verbose
	  (format stream "~C==|Epoch: ~a|======================~C" #\newline epoch-num #\newline))

      (let ((total-len (if max-iterate max-iterate (get-dataset-length dataset))))
	(fresh-line)
	(print "losses")
	(dotimes (i total-len)
	  (let* ((args (get-dataset dataset i))
		 (loss (data (step-model1 trainer args))))
	    (push loss losses)
	    (if (and enable-animation verbose)
		(cl-cram:update status-bar 1 :desc (format nil "loss:~a" (first losses))))))
	(let ((figure (make-instance 'cl-termgraph:figure-graph-frame
				     :figure #'(lambda (a) (multiple-value-bind (n _) (round a) (declare (ignore a))
							     (if (< (length losses) n) (nth n losses) 0.0)))
				     :from 0
				     :end (length losses)
				     :width width
				     :height height
				     :name (format nil "|Losses at Epoch: ~a|" epoch-num))))
	  (cl-termgraph:plot figure nil)

	(cl-cram:update status-bar total-len :desc (format nil "loss:~a" (first losses)) :reset t)
	(setq losses `(0.0)))))))

	    
