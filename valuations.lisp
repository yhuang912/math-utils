(defpackage :valuations
  (:nicknames :vv)
  (:use :cl :ol :iterate )
  (:import-from :polynomials  #:polynomial #:coefficients #:degree #:ord-p/generic)
  (:import-from :power-series #:power-series #:constant-series #:constant-coefficient)
  (:import-from :infinite-math #:infinite-p #:i< #:infinity+)
  (:export
   #:valuate-exp
   #:bounded-search-limit
   #:bounded-count
   #:v-minimise))

(in-package :valuations)

;;; start off with exponential valuations for simplicity

(defun v-minimise (values &optional key)
  (reduce (lambda (a b) (if (i< b a) b a))
          values :key key))

(declaim (inline val))
(defun val (valuation)
  (lambda (x) (valuate-exp valuation x)))

(defgeneric valuate-exp (valuation object))

;;; for polynomials, we can just minimise the valuation on the
;;; coefficients (if the valuation is trivial on the variable!)
(defmethod valuate-exp (valuation (polynomial polynomial))
  (v-minimise (coefficients polynomial)
              (val valuation)))

;;; for power-series, we need to get a bit smarter -- unless the
;;; series is constant
(defmethod valuate-exp (valuation (constant-series constant-series))
  (valuate-exp valuation (constant-coefficient constant-series)))

;;; otherwise, we try to guess whether the power series is bounded
(defparameter bounded-count 10
  "The number of subsequent coefficients that need to be lower than
  the current bound before we hazard the guess that the series is
  bounded.")

(defparameter bounded-search-limit 50
  "The maximum number of coefficients we want to look at when
  searching for a bound of the coefficients of the power series.")

(defmethod valuate-exp (valuation (power-series power-series))
  ;; first consider the case of finite series
  (let ((coeff (coefficients power-series)))
    (aif (lazy-array-finite coeff)
         (values (v-minimise (lazy-array-take coeff it nil)
                             (val valuation))
                 :finite) 
         ;; in the other case, we have to guess
         (valuate-exp/power-series-infinite valuation coeff (degree power-series)))))

(defun valuate-exp/power-series-infinite (valuation coeffs &optional (degree 0))
  (do* ((index 0 (+ 1 index))
        (val #2=(valuate-exp valuation (lazy-aref coeffs index)) #2#)
        (bound val)
        (bound-index 0))
       ;; terminate if the last coeffs did not require increasing the bound
       ((or #1=(<= bounded-count (- index bound-index))
            ;; or we reached the end of our curiosity
            (> index bounded-search-limit))
        
        (values bound (if #1# bound-index :unbounded)))
    (when (i< val bound)
      (setf bound val
            bound-index index))))

;;; on fractions, we just take the difference
(defmethod valuate-exp (valuation (fraction fractions:fraction))
  (- (valuate-exp valuation (fractions:numerator fraction))
     (valuate-exp valuation (fractions:denominator fraction))))

;;; p-adic valuations on rationals
(defmethod valuate-exp ((p integer) (rational rational))
  ;; todo check that p is prime
  (if (zerop rational)
      infinity+
      (nt:ord-p p rational)))

;;; valuations from irreducible polynomials
(defmethod valuate-exp ((p polynomial) (polynomial polynomial))
  ;; todo check that p is irreducible
  ;; todo check that both polynomials have the same var
  (if (gm:zero-p polynomial)
      infinity+
      (ord-p/generic p polynomial)))
