(defpackage :factorisation-polynomials-modp
  (:nicknames :pfactp)
   (:shadowing-import-from :fractions :numerator :denominator)
  (:shadowing-import-from :generic-math :+ :- :* :/ := :expt :sqrt :summing)
  (:use :cl :ol :iterate
        :generic-math
        :polynomials
        :finite-fields
        :fractions)
  (:export))

(in-package :factorisation-polynomials-modp)

;;; todo verify these defaults
;;; todo move elsewhere perhaps??
(defmethod ggt ((a integer-mod) (b integer-mod)) 1)
(defmethod ggt ((a integer) (b integer-mod)) 1)
(defmethod ggt ((b integer-mod) (a integer)) 1)

(defmethod content ((a integer-mod)) 1)

;;; todo do we want a version without checking (for efficiency)
(defun get-prime (polynomial)
  "For a polynomial where all coefficients are of type INTEGER-MOD,
  find the modulus and check it is the same everywhere."
  (let ((p (modulus (leading-coefficient polynomial))))
    (if (every (lambda (x) (cl:= p (modulus x))) (coefficients polynomial))
        p
        (error "Different moduli in the coefficients of polynomial ~A" polynomial))))

;;; replacement of x^p with x
(defun poly-x->x^p (polynomial)
  "Evaluate poly at X^p"
  (let ((p (get-prime polynomial)))
    (make-instance 'polynomial :var (var polynomial)
                   :coefficients
                   (iter (for c in-vector (coefficients polynomial))
                         (unless (first-iteration-p)
                           (iter (repeat (cl:- p 1))
                                 (push (int% 0 p) coeffs)))
                         (collect c into coeffs
                                  at beginning result-type vector)))))

(defun poly-x^p->x (polynomial)
  "Assume that the coefficients vanish everywhere but at X^(n p),
  replace X^p by X."
  (let ((p (get-prime polynomial)))
    (make-instance 'polynomial :var (var polynomial)
                   :coefficients 
                   (iter (for i from 0 to (floor (degree polynomial) p))
                         (collect (nth-coefficient% polynomial (* p i))
                           at beginning result-type vector)))))


;;; the output of factorise is a list of conses, where the CAR is the
;;; factor and the CDR is the multiplicity
(defun merge-factors (factors-1 factors-2)
  "Merge all the FACTORS-1 destructively into FACTORS-2, may also be
used to remove duplicates from factors-1."
  ;; careful, this version is destructive on both arguments
  (if (null factors-1) factors-2
      ;; if the factor appears in factors-2, add the multiplicity
      (aif (assoc (caar factors-1) factors-2 :key #'car :test #'gm:=)
           (progn
             (incf (cdr it) (cdar factors-1))
             (merge-factors (rest factors-1) factors-2))
           (merge-factors (rest factors-1) (cons (car factors-1) factors-2)))))

(defun map-on-car (fn alist)
  "Call FN on every CAR of ALIST, preserving the CDR."
  (mapcar (lambda (x)
            (cons (funcall fn (car x))
                  (cdr x)))
          alist))

(defun factorise (polynomial)
  ;; TODO perhaps we move some normalisation here, and make result
  ;; prettier (sorting factors by degree might be useful)
  (factorise-prepare polynomial))

(defun constant-p  (polynomial)
  (or (not (typep polynomial 'polynomial))
      (cl:= (degree polynomial) 0)))

(defun non-constant-p (polynomial)
  (if (constant-p polynomial)
      nil
      polynomial))


(defun factorise-prepare (polynomial)
  (let* ((polynomial (make-monic polynomial))
         (derivative (derivative polynomial)))
    (acond
      ;; constant monic polys have no factors
      ((constant-p polynomial) nil)
      ;; if the derivative vanishes, we only have coeffs at X^(np)
      ((zero-p derivative)
       (map-on-car #'poly-x->x^p
                   (factorise-prepare (poly-x^p->x polynomial))))
      ;; if the gcd of poly and derivative is non-constant, we split
      ;; polynomial in two factors already
      ((non-constant-p (ggt polynomial derivative))
       (merge-factors (factorise-prepare it)
                      (factorise-prepare (/ polynomial it))))
      ;; otherwise, we know the polynomial is SQUAREFREE
      (t (factorise-squarefree-poly polynomial)))))

(defun factorise-squarefree-poly (polynomial)
  polynomial
  )
