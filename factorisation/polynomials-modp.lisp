(defpackage :factorisation-polynomials-modp
  (:nicknames :pfactp)
  (:shadowing-import-from :fractions :numerator :denominator)
  (:shadowing-import-from :generic-math :+ :- :* :/ := :expt :sqrt :summing :^ :_)
  (:use :cl :ol :iterate
        :generic-math
        :polynomials
        :finite-fields
        :fractions)
  (:export
   #:get-prime
#:merge-factors
#:factorise
#:multiply-factors))

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


(defun factorise (polynomial)
  ;; TODO perhaps we move some normalisation here, and make result
  ;; prettier (sorting factors by degree might be useful)
  ;; TODO perhaps include leading coefficient in the factorisation?
  (factorise-generic-poly polynomial))

(defun factorise-generic-poly (polynomial)
  (let* ((polynomial (make-monic polynomial))
         (derivative (derivative polynomial)))
    (acond
      ;; constant monic polys have no factors
      ((constant-p polynomial) nil)
      ;; if the derivative vanishes, we only have coeffs at X^(np)
      ((zero-p derivative)
       (map-on-car #'poly-x->x^p
                   (factorise-generic-poly (poly-x^p->x polynomial))))
      ;; if the gcd of poly and derivative is non-constant, we split
      ;; polynomial in two factors already
      ((non-constant-p (ggt polynomial derivative))
       (merge-factors (factorise-generic-poly it)
                      (factorise-generic-poly (/ polynomial it))))
      ;; otherwise, we know the polynomial is SQUAREFREE
      (t (mapcar (lambda (x) (cons x 1))
                 (factorise-squarefree-poly polynomial))))))

(defun pad-vector-front (vector required-length)
  "add zeroes to the front of VECTOR, until it has REQUIRED-LENGTH."
  (let ((n (length vector))
        (new-vector (make-array required-length :initial-element 0)))
    (when (> n required-length)
      (error "vector is already too long, has length ~A when ~A is required." n required-length))
    (iter (for i from (- required-length n))
          (for el in-vector vector)
          (setf (aref new-vector i) el))
    new-vector))

(defun factorise-squarefree-poly (u)
  ;; use Berlekamp's algorithm
  (let* ((p (get-prime u))
         (n (degree u))
         (q (vectors:make-matrix-from-rows
             ;; counting k down, because our poly coeffs start with
             ;; leading coefficients.
             (iter (for k from (- n 1) downto 0)
                   (collect (pad-vector-front
                             ;; here the order of coefficients does
                             ;; not really matter
                             (coefficients (nth-value
                                            1
                                            (/ (make-monomial (* p k) (int% 1 p))
                                               u)))
                             n))))))
    ;; here we have to tranpose (Knuth has the vector on the left side
    ;; of the matrix)
    (multiple-value-bind (v r) (linsolve:nullspace (- (vectors:transpose q) (vectors:identity-matrix n)))
      (if (cl:= r 1)
          ;; polynomial is irreducible
          u
          ;; otherwise find factors
          (iter (for vcoeffs in v)
                (for factors first (splitting-helper p vcoeffs u)
                     then  (mapcan (lambda (w) (splitting-helper p vcoeffs w)) factors))
                (until (cl:<= r (length factors)))
                (finally (return (mapcar #'make-monic factors))))))))

(defun splitting-helper (p coeff-vector poly-to-split)
  ;; indexing of coefficients can simply be chosen to be consistent
  ;; with how we collect the 'rows' (rather cols) above.
  (let ((poly (simplify (make-instance 'polynomial :coefficients (vectors:entries coeff-vector)) :downgrade nil))
        (factors))
    (dotimes (s p)
      (aif (non-constant-p (ggt (gm:- poly (int% s p)) poly-to-split))
           (push it factors)))
    ;; either we found some (finer grained) factors, or we just keep
    ;; the factor
    (or factors
        (list poly-to-split))))

;; TODO move to more suitable place?
(defun multiply-factors (factors)
  "inverse to the FACTORISE function."
  (reduce #'generic-*
          factors :key (lambda (x) (destructuring-bind (factor . exp) x
                                (expt factor exp)))))
