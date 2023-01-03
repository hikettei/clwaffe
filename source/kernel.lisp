
(in-package :cl-waffe)

(defparameter *kernels* `(:cpu :opencl :mgl))
(defparameter *instructions* `(:add
			       :sub
			       :mul
			       :div
			       :log
			       :pow
			       :sum
			       :mean
			       :dot
			       :exp
			       :tanh
			       :reshape
			       :transpose
			       :repeat))

(defun check-kernel (variable)
  (unless (typep variable 'WaffeTensor)
    (error "The inputs must be tensor got: ~a" variable))
  
  (unless (find (slot-value variable 'backend) *kernels*)
    (error "Invaild kernel: ~a" (slot-value variable 'backend))
    T))

(defun assure-tensors (variables)
  (check-kernel (first variables))
  (or (endp variables)
      (let ((x (slot-value (first variables) 'backend)))
	(every (lambda (y)
		 (check-kernel y)
		 (equal x (slot-value y 'backend)))
	       (rest variables)))))

(defun callop (instruction &rest variables)
  (unless (find instruction *instructions*) ;doesnt works?
    (error "unsupported instruction: ~a" instruction))

  (unless (assure-tensors variables)
    (error "all inputs must have same backends and be waffe tensor"))

  (let* ((backend (waffetensor-backend (first variables)))
	 (args (map 'list (lambda (x) (waffetensor-data x)) variables))
	 (all-not-array (every (lambda (x) (typep x 'waffesupporteddatatype)) args))
	 (result (case backend
		   (:cpu    (cl-waffe.backends.cpu:kernel instruction args))
		   (:opencl (cl-waffe.backends.opencl:kernel instruction args))
		   (:mgl    (if all-not-array ; Use CPU When like Const(1) + Const(1)
			        (cl-waffe.backends.cpu:kernel instruction args)
				(cl-waffe.backends.mgl:kernel instruction args)))))
	 (result (if (numcl:numcl-array-p result)
		     (mgl-mat:array-to-mat result)
		     result)) ; may cause some bugs
	 (result (if (typep result 'mgl-mat:mat)
		     (if (equal (mgl-mat:mat-dimensions result) `(1))
			 (mgl-mat:mref result 0)
			 result)
		     result)))
    (const result :backend backend)))

(defun backends-available ())

(defun check-supported-instruction (backend))

