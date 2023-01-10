
(in-package :cl-waffe.optimizers)

(defoptimizer SGD (params &key (lr 1e-3))
  :parameters ((params params) (lr lr))
  :update (()
	   (dolist (p (self params))
	     ; W(n+1) = W(n) - n * grad
	     (mgl-mat:copy! (warranty (!sub p (!mul (self lr) (grad p)))) (data p)))))

(defoptimizer Momentum (params &key (momentum 0.9) (lr 1e-3))
  :parameters ((params params) (lr lr) (momentum momentum) (velocities T))
  :update (()
	   (if (equal (self velocities) T)
	       (progn
		 (setf (self velocities) `())
		 (dolist (i (self params))
		   (push 0 (self velocities)))))
	   (dotimes (i (length (self params)))
	     ; v(n+1) = momentum*v(n) - grad*lr
	     ; w(n+1) = w(n) + v(n+1)
	     (setf (nth i (self velocities)) (warranty (!sub (!mul (self momentum) (nth i (self velocities)))
							     (!mul (self lr) (grad (nth i (self params)))))))
	     (mgl-mat:copy! (warranty (!add (nth i (self velocities))
					    (nth i (self params))))
			    (data (nth i (self params)))))))

(defoptimizer AdaGrad (params &key (lr 1e-3) (epsilon 1e-7))
  :parameters ((params params) (lr lr) (h T) (epsilon epsilon))
  :update (()
	   (if (equal (self h) T)
	       (dolist (i (self params))
		 (push 0 (self h))))
	   (dotimes (i (length (self params)))
	     ; h(t+1) = h(t) + (grad * grad)
             ; w(t+1) = w(t) - {lr * grad}/sqrt(h(t+1))
	     (setf (nth i (self h)) (warranty (!add (nth i (self h))
						    (!mul (grad (nth i (self params)))
							  (grad (nth i (self params)))))))
	     (mgl-mat:copy! (warranty (!sub (data (nth i (self params)))
					    (!div (!mul (self lr) (grad (nth i (self params))))
						  (!add (!sqrt (nth i (self h))) (self epsilon)))))
			    (data (nth i (self params)))))))

(defoptimizer RMSProp (params &key (lr 1e-3) (epsilon 1e-7) (decay-rate 0.99))
  :parameters ((params params) (lr lr) (h T) (epsilon epsilon) (decay-rate 0.99))
  :update (()
	   (if (equal (self h) T)
	       (dolist (i (self params))
		 (push 0 (self h))))
	   (dotimes (i (length (self params)))
             (setf (nth i (self h)) (warranty (!mul (nth i (self h)) (self decay-rate))))
	     (setf (nth i (self h)) (warranty (!add (nth i (self h))
						    (!mul (!mul (!sub 1.0 (self decay-rate))
								(grad (nth i (self params))))
							  (grad (nth i (self params)))))))
	     (mgl-mat:copy! (warranty (!sub (data (nth i (self params)))
					   (!div (!mul (self lr) (grad (nth i (self params))))
						 (!add (!sqrt (nth i (self h))) (self epsilon)))))
			    (data (nth i (self params)))))))

(defoptimizer Adam (params &key (lr 1e-3) (epsilon 1e-7) (beta1 0.9) (beta2 0.999))
  :parameters ((params params) (lr lr) (m T) (v T) (i 0) (epsilon epsilon) (beta1 beta1) (beta2 beta2))
  :update (()
	   (if (equal (self m) T)
	       (dolist (i (self params))
		 (push 0 (self m))
		 (push 0 (self v))))
	   (incf (self i) 1)
	   (let ((lr-t (!mul (self lr) (!div (!sqrt (!sub 1.0 (!pow (self beta2) (self i))))
					     (!sub 1.0 (!pow (self beta1) (self i)))))))
	     (dotimes (i (length (self params)))
	       (setf (nth i (self m)) (warranty (!add (nth i (self m))
						      (!mul (!sub 1 (self beta1))
							    (!sub (grad (nth i (self params)))
								  (nth i (self m)))))))
	       (setf (nth i (self v)) (warranty (!add (nth i (self v))
						      (!mul (!sub 1 (self beta2))
							    (!sub (!pow (grad (nth i (self params))) 2)
								  (nth i (self v)))))))
	       (mgl-mat:copy! (data
				  (!sub (nth i (self params))
					(!mul lr-t (!div
						    (nth i (self m))
						    (!add (!sqrt (nth i (self v))) (self epsilon))))))
			      (data (nth i (self params))))))))



