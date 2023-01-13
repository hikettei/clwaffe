
(in-package :cl-waffe.backends.mgl)

; Todo Rewrite with define-lisp-kernel

(defmacro duplicate-tensor (mat)
  `(let ((o (mgl-mat:make-mat (mgl-mat:mat-dimensions ,mat))))
     (mgl-mat:copy! ,mat o)
     o))

(defmacro apply-destruct (out)
  `(progn ; tensor=out
     (setf (waffetensor-is-data-destructed? ,out) t)
     (setf (waffetensor-destructively-calln ,out) 1))
  nil)

(defmacro assure-destructed? (out)
  `(progn
     (unless (waffetensor-destructive? ,out)
       (error "Kernel Error: Modifying tensor that is not allowed to destruct"))
     (data ,out)))


(defgeneric decide-out-buffer (out args enable-optim))

(defmethod decide-out-buffer ((out waffetensor) (args waffetensor) enable-optim)
  (apply-destruct out)
  (if (and (not enable-optim) (waffetensor-destructive? out))
      (assure-destructed? args)
      (duplicate-tensor (assure-destructed? out))))

(defmethod decide-out-buffer ((out waffetensor) (args mgl-mat:mat) enable-optim)
  (apply-destruct out)
  (if (and (not enable-optim) (waffetensor-destructive? out))
      args
      (duplicate-tensor (assure-destructed? out))))

(defmethod decide-out-buffer ((out null) (args waffetensor) enable-optim)
  (declare (ignore out enable-optim))
  (duplicate-tensor (assure-destructed? args)))

(defmethod decide-out-buffer ((out null) (args mgl-mat:mat) enable-optim)
  (declare (ignore out enable-optim))
  (duplicate-tensor args))

(declaim (ftype (function (mgl-mat:mat fixnum &key (:axis fixnum)) mgl-mat:mat) mgl-repeat))
(defun mgl-repeat (tensor n &key axis)
  (declare (optimize (speed 3) (safety 0) (debug 0))
	   (type waffetensor tensor)
	   (type fixnum n axis))
  (if (>= axis 0)
      (if (>= (length (the cons (mgl-mat:mat-dimensions tensor))) 2)
          (mgl-mat:stack axis (loop for i below n collect tensor))
	  (mgl-repeat (mgl-mat:reshape tensor `(,@(mgl-mat:mat-dimensions tensor) 1)) n :axis axis))
      (error "axis=-1")))

(declaim (ftype (function (mgl-mat:mat waffesupporteddatatype) mgl-mat:mat) trasposedmgl-full-like mgl-full-like))
(defun mgl-full-like (tensor value)
  (declare (optimize (speed 3) (safety 0) (debug 0))
	   (type mgl-mat:mat tensor)
	   (type waffesupporteddatatype value))
  (mgl-mat:make-mat (mgl-mat:mat-dimensions tensor)
		    :initial-element value))

(defun transposed-mgl-full-like (tensor value)
  (declare (optimize (speed 3) (safety 0) (debug 0))
	   (type mgl-mat:mat tensor)
	   (type waffesupporteddatatype value))
  (let ((dims (mgl-mat:mat-dimensions tensor)))
    (declare (type cons dims))
    (mgl-mat:make-mat (reverse dims)
		      :initial-element value)))

(defparameter *v2v-operations* `(:add :sub :mul :div :dot :matmul))
(defparameter *abort-delay-instruction* :matmul)

(defmacro deliv-delay (tensor func &rest args)
  `(lambda (shape? step?)
     (if shape?
	 (reverse (mgl-mat:mat-dimensions ,tensor))
	 (if step?
	     (funcall ,func ,tensor ,@args) ; receive before node
	     ,tensor)))) ; abort before node

(defun next-delay (delay state)
  (if (typep delay 'function)
      (funcall delay nil state)
      delay))

(defmacro abort-delay (delay)
  `(next-delay ,delay nil))

(defmacro receive-delay (delay)
  `(next-delay ,delay t))

(defun ensure-shape (ope x)
  (declare (type keyword ope))
  (if (find ope *v2v-operations*)
      (if (or (typep x 'mgl-mat:mat) (typep x 'function))
	  (if (eq ope *abort-delay-instruction*)
	      (abort-delay x)
	      (receive-delay x))
	  (if (eq ope :matmul)
	      (transposed-mgl-full-like m x)
	      (mgl-full-like m x)))))

(defun infomation ())

(declaim (ftype (function (boolean waffetensor waffetensor waffetensor waffetensor) mgl-mat:mat)
		div-tensor))

(declaim (ftype (function (boolean waffetensor waffetensor) mgl-mat:mat)
		inv-tensor
		sqrt-tensor
		log-tensor
		tanh-tensor
		exp-tensor))

(defgeneric add-tensor (enable-optimize? out out1 x y))

(defmethod add-tensor (enable-optimize? (out waffetensor) (out1 waffetensor) (x mgl-mat:mat) (y mgl-mat:mat))
  (declare (optimize (speed 3) (space 0) (safety 0))
	   (ignore out1))
  (if (eq (mgl-mat:mat-dimensions x) (mgl-mat:mat-dimensions y))
      (let ((o (mgl-mat:make-mat (mgl-mat:mat-dimensions x))))
	(mgl-mat:axpy! 1.0 x o)
	(mgl-mat:axpy! 1.0 y o)
	o)
      (mgl-mat:m+ x y)))

(defmethod add-tensor (enable-optimize? (out waffetensor) (out1 waffetensor) (x mgl-mat:mat) y)
  (declare (optimize (speed 3) (space 0) (safety 0))
	   (ignore out1))
  (let ((o (decide-out-buffer out x enable-optimize?)))
    (the mgl-mat:mat (mgl-mat:.+! y o))))

(defmethod add-tensor (enable-optimize? (out waffetensor) (out1 waffetensor) x (y mgl-mat:mat))
  (declare (optimize (speed 3) (space 0) (safety 0))
	   (ignore out))
  (let ((o (decide-out-buffer out1 y enable-optimize?)))
    (the mgl-mat:mat (mgl-mat:.+! x o))))


(defgeneric sub-tensor (enable-optimize? out out1 x y))
(defmethod sub-tensor (enable-optimize? (out waffetensor) (out1 waffetensor) (x mgl-mat:mat) (y mgl-mat:mat))
  (declare (optimize (speed 3) (space 0) (safety 0))
	   (ignore out1))
  (if (eq (mgl-mat:mat-dimensions x) (mgl-mat:mat-dimensions y))
      (let ((o (mgl-mat:make-mat (mgl-mat:mat-dimensions x))))
	(mgl-mat:axpy!  1.0 x o)
	(mgl-mat:axpy! -1.0 y o)
	o)
      (mgl-mat:m- x y)))

(defmethod sub-tensor (enable-optimize? (out waffetensor) (out1 waffetensor) (x mgl-mat:mat) y)
  (declare (optimize (speed 3) (space 0) (safety 0))
	   (ignore out1))
  (let ((o (decide-out-buffer out x enable-optimize?)))
    (the mgl-mat:mat (mgl-mat:.+! (* -1 y) o))))

(defmethod sub-tensor (enable-optimize? (out waffetensor) (out1 waffetensor) x (y mgl-mat:mat))
  (declare (optimize (speed 3) (space 0) (safety 0))
	   (ignore out))
  (let ((o (decide-out-buffer out1 y enable-optimize?)))
    (the mgl-mat:mat (mgl-mat:.+! (* -1 x) o))))

(defgeneric mul-tensor (enable-optimize? out out1 x y))
(defmethod mul-tensor (enable-optimize? (out waffetensor) (out1 waffetensor) (x mgl-mat:mat) (y mgl-mat:mat))
  (declare (optimize (speed 3) (space 0) (safety 0)))
  (let ((o (mgl-mat:make-mat (mgl-mat:mat-dimensions x))))
    (mgl-mat:geem! 1 x y 0 o)))

(defmethod mul-tensor (enable-optimize? (out waffetensor) (out1 waffetensor) x (y mgl-mat:mat))
  (declare (optimize (speed 3) (space 0) (safety 0))
	   (ignore out))
  (let ((o (decide-out-buffer out1 y enable-optimize?)))
	(mgl-mat:scal! x o)))

(defmethod mul-tensor (enable-optimize? (out waffetensor) (out1 waffetensor) (x mgl-mat:mat) y)
  (declare (optimize (speed 3) (space 0) (safety 0))
	   (ignore out1))
  (let ((o (decide-out-buffer out x enable-optimize?)))
	(mgl-mat:scal! y o)))

(defun inv-tensor (enable-optim out x)
  (declare (optimize (speed 3) (space 0) (safety 0))
	   (type boolean enable-optim)
           (type waffetensor out x))
  (let ((o (decide-out-buffer out x enable-optim)))
    (mgl-mat:.inv! o)))

(defun div-tensor (enable-optimize? out out1 x y)
  (declare (optimize (speed 3) (space 0) (safety 0))
	   (type boolean enable-optimize?)
	   (type waffetensor out x y)
	   (ignore out x))
  (inv-tensor enable-optimize? out1 y))

(defun dot-tensor (enable-optimize? out x y)
  (declare (ignore enable-optimize? out))
  (mgl-mat:dot (data x) (data y)))

(declaim (ftype (function (boolean waffetensor waffetensor waffetensor) mgl-mat:mat)
		matmul-tensor
		pow-tensor
		compare-tensor
		sum-tensor))
(defun matmul-tensor (enable-optimize? o x y)
  (declare (optimize (speed 3) (space 0) (safety 0))
	   (ignore enable-optimize? o)
	   (type boolean enable-optimize?)
	   (type waffetensor o))

  (let* ((x1 (ensure-shape :matmul (data x)))
	 (y1 (ensure-shape :matmul (data y)))
	 (transpose-map `(,(typep (data x) 'function) ,(typep (data y) 'function)))
	 (out (mgl-mat:make-mat `(,(if (car transpose-map)
	 			       (car  (reverse (mgl-mat:mat-dimensions x1)))
	   			       (car  (mgl-mat:mat-dimensions x1)))
				  ,(if (second transpose-map)
				       (second (reverse (mgl-mat:mat-dimensions y1)))
				       (second (mgl-mat:mat-dimensions y1)))))))
    (unless (and (<= (length (the list (mgl-mat:mat-dimensions x1))) 2)
		 (<= (length (the list (mgl-mat:mat-dimensions y1))) 2))
      (error "cl-waffe.backends.mgl: :matmul failed due to unsatisfied with (!dims a) <= 2 and (!dims b) <= 2"))
    
    (mgl-mat:gemm! 1 x1 y1 0 out :transpose-a? (car transpose-map) :transpose-b? (second transpose-map))
    out))

(defun log-tensor (enable-optim out x)
  (declare (optimize (speed 3) (space 0) (safety 0))
	   (type boolean enable-optim)
           (type waffetensor out x))
  (let ((o (decide-out-buffer out x enable-optim)))
           (mgl-mat:.log! o)))

(defun exp-tensor (enable-optim out x)
  (declare (optimize (speed 3) (space 0) (safety 0))
	   (type boolean enable-optim)
           (type waffetensor out x))
  (let ((o (decide-out-buffer out x enable-optim)))
    (mgl-mat:.exp! o)))

(defun sqrt-tensor (enable-optim out x)
  (declare (optimize (speed 3) (space 0) (safety 0))
	   (type boolean enable-optim)
           (type waffetensor out x))
  (let ((o (decide-out-buffer out x enable-optim)))
           (mgl-mat:.sqrt! o)))

(defun pow-tensor (enable-optim out x y)
  (declare (optimize (speed 3) (space 0) (safety 0))
	   (type boolean enable-optim)
           (type waffetensor out x y))
  (let ((o (decide-out-buffer out x enable-optim)))
    (mgl-mat:.expt! o (data y))))

(defun tanh-tensor (enable-optim out x)
  (declare (optimize (speed 3) (space 0) (safety 0))
	   (type boolean enable-optim)
           (type waffetensor out x))
  (let ((o (decide-out-buffer out x enable-optim)))
       (mgl-mat:.tanh! o)))

(defun compare-tensor (enable-optim out x y)
  (declare (optimize (speed 3) (space 0) (safety 0))
	   (type boolean enable-optim)
           (type waffetensor out x y))
  (let ((o (decide-out-buffer out x enable-optim)))
           (mgl-mat:.<! (data y) o)))

(defun sum-tensor (is-first-time-call? out x y)
  (declare (optimize (speed 3) (space 0) (safety 0))
           (type boolean is-first-time-call?)
           (type waffetensor out x y)
	   (ignore is-first-time-call? out))

  (let* ((dims (mgl-mat:mat-dimensions (data x)))
	 (dims (if (and (= 1 (the fixnum (car (last dims))))
			(= 3 (length dims)))
		   (butlast dims)
		   dims))
	 (x1 (mgl-mat:reshape! (mgl-mat:copy-mat (data x)) dims))
	 (dims (case (data y)
		 (1 `(,@(list (car dims)) 1))
		 (0 `(1 ,@(cdr dims)))
		 (T (error "Sum only supports a 2d matrix")))))
    (let ((o (mgl-mat:make-mat dims :initial-element 0)))
      (mgl-mat:sum!     x1 o :axis (data y) :beta 1)
      (mgl-mat:reshape! o dims)
      (if (equal dims `(1 1))
	  (mgl-mat:mref o 0 0)
	  o))))

(defun mean-tensor (is-first-time-call? out x y) ; =sum????? dimのlengthで割る
  (declare (optimize (speed 3) (space 0) (safety 0))
           (type boolean is-first-time-call?)
           (type waffetensor out x y)
	   (ignore is-first-time-call? out))

  (let* ((dims (mgl-mat:mat-dimensions (data x)))
	 (dims (if (and (= 1 (the fixnum (car (last dims))))
			(= 3 (length dims)))
		   (butlast dims)
		   dims))
	 (x1 (mgl-mat:reshape! (mgl-mat:copy-mat (data x)) dims))
	 (dims (case (data y)
		 (1 `(,@(list (car dims)) 1))
		 (0 `(1 ,@(cdr dims)))
		 (T (error "Sum only supports a 2d matrix")))))
    (let ((o (mgl-mat:make-mat dims :initial-element 0)))
      (mgl-mat:sum! x1 o :axis (data y) :beta 1)
      (mgl-mat:reshape! o dims)
      (if (equal dims `(1 1))
	  (mgl-mat:mref o 0 0)
	  o))))

(declaim (ftype (function (boolean waffetensor waffetensor waffetensor) mgl-mat:mat) reshape-tensor))
(defun reshape-tensor (enable-optimize out x y)
  (declare (optimize (speed 3) (space 0) (safety 0))
	   (type boolean enable-optimize)
	   (type waffetensor out x y)
	   (ignore enable-optimize out))
  (let ((x1 (mgl-mat:copy-mat (data x))))
    (mgl-mat:reshape! x1 (data y))
    x1))

;(declaim (ftype (function (keyword boolean values waffetensor (or null waffetensor) cons) (or mgl-mat:mat cl-waffe:waffedatatype)) dispatch-kernel))
(defun dispatch-kernel (function is-first-time-call? destructable-tensor destructable-tensor1 args)
  (declare (optimize (speed 3) (space 0) (safety 0))
	   (type keyword function)
	   (type boolean is-first-time-call?)
	   (type waffetensor destructable-tensor)
	   (type cons args))
  (case function
    (:add    (add-tensor is-first-time-call? destructable-tensor destructable-tensor1 (data (car args)) (data (second args))))
    (:sub    (sub-tensor is-first-time-call? destructable-tensor destructable-tensor1 (data (car args)) (data (second args))))
    (:mul    (mul-tensor is-first-time-call? destructable-tensor destructable-tensor1 (data (car args)) (data (second args))))
    (:div    (div-tensor is-first-time-call? destructable-tensor destructable-tensor1 (car args) (second args)))
    (:dot    (dot-tensor is-first-time-call? destructable-tensor (car args) (second args)))
    (:matmul (matmul-tensor is-first-time-call? destructable-tensor (car args) (second args)))
    (:log    (log-tensor is-first-time-call? destructable-tensor (car args)))
    (:exp    (exp-tensor is-first-time-call? destructable-tensor (car args)))
    (:pow    (pow-tensor is-first-time-call? destructable-tensor (car args) (second args)))
    (:sqrt   (sqrt-tensor is-first-time-call? destructable-tensor (car args)))
    (:sum    (sum-tensor is-first-time-call? destructable-tensor (car args) (second args)))
    (:mean   (mean-tensor is-first-time-call? destructable-tensor (car args) (second args)))
    (:tanh    (tanh-tensor is-first-time-call? destructable-tensor (car args)))
    (:reshape (reshape-tensor is-first-time-call? destructable-tensor (car args) (second args)))
    (:<       (compare-tensor is-first-time-call? destructable-tensor (car args) (second args)))
    (:repeat  (mgl-repeat (data (car args)) (data (third args)) :axis (data (second args))))
    (:transpose (deliv-delay (data (car args)) (the function mgl-mat:transpose)))
    (T (error "~a is not yet implemented" ope))))

