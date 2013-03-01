(defpackage :number-theory
  (:nicknames :nt)
  (:use :cl )
  (:export
   :xgcd
   :divides-p
   :divisible-p
   :prime-p
   :factorise
   :ord-p))

(in-package :number-theory)
