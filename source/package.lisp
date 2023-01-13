
(in-package :cl-user)

(defpackage cl-waffe
  (:use :cl :mgl-mat)
  (:export #:waffetensor
           #:tensor
	   #:const
	   #:sysconst
	   
	   #:data
	   #:grad

	   #:waffedatatype
	   #:waffe-array

	   #:with-no-grad
	   #:*no-grad*

	   #:waffe-tensor-p
	   
	   #:defmodel
	   #:defnode
	   #:defoptimizer
	   #:deftrainer
	   #:defdataset
	   
	   #:step-model
	   #:predict
	   #:get-dataset
	   #:get-dataset-length

	   #:model
	   #:update
	   #:zero-grad

	   #:forward
	   #:backward
	   #:parameters
	   #:hide-from-tree

	   #:train
	   #:get-dataset
	   #:get-dataset-length
	   
	   #:parameter
	   #:call
	   #:backward

	   #:!set-batch
	   #:!reset-batch

	   #:waffetensor-destructively-calln
	   #:waffetensor-destructive?
	   #:waffetensor-is-data-destructed?
	   #:waffetensor-report-index
	   #:with-ignore-optimizer
	   #:*ignore-optimizer*

	   #:self

	   #:relu
	   #:sigmoid
	   #:wf-tanh

	   #:print-model

	   #:*default-backend*
	   #:extend-from
	   #:!zeros
	   #:!ones
	   #:!fill
	   #:!arange
	   #:!aref
	   #:!row-major-aref
	   #:!with-mgl-operation
	   #:!copy
	   #:!index
	   #:!where
	   #:!random
	   #:!random-with
	   #:!normal
	   #:!randn
	   #:!binomial
	   #:!beta
	   #:!gamma
	   #:!chisquare
	   #:!shape
	   #:!dims
	   #:!size
	   #:!size-1
	   #:!zeros-like
	   #:!ones-like
	   #:!full-like

	   #:!add
	   #:!sub
	   #:!mul
	   #:!div

	   #:!dot
	   #:!sum

	   #:!sqrt
	  
	   #:!pow
	   #:!mean
	   #:!log
	   #:!reshape
	   #:!transpose
	   #:!exp
	   #:!matmul
	   #:!repeats

	   #:!squeeze
	   #:!unsqueeze

	   #:!relu
	   #:!sigmoid
	   #:!tanh
	   #:!softmax
	   ))
