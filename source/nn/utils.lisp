
(in-package :cl-waffe.nn)

(defmodel LinearLayer (in-features out-features &optional (bias T))
  :parameters ((weight (parameter (randn in-features out-features)))
	      (bias (if bias
			(parameter (zeros `(,out-features 1)))
			nil)))
  :forward ((x) (cl-waffe.nn:linear x (cl-waffe:self weight) (cl-waffe:self bias))))


(defmodel DenseLayer (in-features out-features &optional (bias T) (activation :relu))
  :parameters ((layer (linearlayer in-features out-features bias)) (activation activation))
  :forward ((x)
	    (case (cl-waffe:self activation)
	      (:relu
	       (relu (call (cl-waffe:self layer) x)))
	      (:sigmoid
	       (sigmoid (call (cl-waffe:self layer) x)))
	      (:tanh
	       (wf-tanh (call (cl-waffe:self layer) x)))
	      (T
	       (funcall (cl-waffe:self activation)
			(call (cl-waffe:self layer) x))))))




