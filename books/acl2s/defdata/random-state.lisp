#|$ACL2s-Preamble$;
(include-book ;; Newline to fool ACL2/cert.pl dependency scanner
 "../portcullis")
(begin-book t);$ACL2s-Preamble$|#

(in-package "DEFDATA")
(set-verify-guards-eagerness 2)

(include-book "random-state-basis1")
;(include-book "num-list-fns") ;defines acl2-number-listp,pos-listp,naturals-listp

;=====================================================================;
; 
; by Peter Dillinger &  Dimitris Vardoulakis
; Last Major Updates: 7 February 2008
; Tweaked:  11 November 2008
; Tweaked:  24 November 2008 by harshrc
; Modified: 10 March 2012 by harshrc -- type declarations
; Modified: [2016-04-03 Sun] harshrc -- reduce bias to small random numbers
;=====================================================================;

(defun random-boolean (state)
  (declare (xargs :stobjs (state)))
  (mv-let (num state)
          (genrandom-state 2 state)
          (mv (= 1 num) state)))

(defthm random-boolean-type
  (booleanp (car (random-boolean r)))
  :rule-classes :type-prescription)

(in-theory (disable random-boolean))


;generate naturals according to a pseudo-geometric distribution
;added strong type declarations for faster code

(defun random-natural-basemax1 (base maxdigits seed.)
  (declare (type (integer 1 16) base)
           (type (integer 0 9) maxdigits)
           (type (unsigned-byte 31) seed.)
           (xargs :guard (and (unsigned-byte-p 31 seed.)
                              (posp base)
                              (<= base 16) (> base 0) 
                              (natp maxdigits)
                              (< maxdigits 10) (>= maxdigits 0))))
  (if (zp maxdigits)
    (mv 0 seed.)
    (b* (((mv (the (integer 0 32) v) 
              (the (unsigned-byte 31) seed.))
          (genrandom-seed (acl2::*f 2 base) seed.)))
     (if (>= v base)
         (b* (((mv v2 seed.); can do better type information here TODO
                 (random-natural-basemax1 base 
                                         (1- maxdigits) seed.)))
             (mv (+ (- v base) 
                    (* base (nfix v2))) 
                 seed.))
      
       (mv v seed.)))))

(defun random-natural-seed/0.5 (seed.)
  (declare (type (unsigned-byte 31) seed.))
  (declare (xargs :guard (unsigned-byte-p 31 seed.)))
  (mbe :logic (if (unsigned-byte-p 31 seed.)
                    (random-natural-basemax1 10 6 seed.)
                  (random-natural-basemax1 10 6 1382728371)) ;random seed in random-state-basis1
       :exec  (random-natural-basemax1 10 6 seed.)))
      

(defun random-natural-basemax2 (base maxdigits seed.)
; less biased than random-natural-basemax1. rather than 0.5, use 0.25
  (declare (type (integer 1 16) base)
           (type (integer 0 10) maxdigits)
           (type (unsigned-byte 31) seed.)
           (xargs :guard (and (unsigned-byte-p 31 seed.)
                              (posp base)
                              (<= base 16) (> base 0) 
                              (natp maxdigits)
                              (< maxdigits 11) (>= maxdigits 0))))
  (if (zp maxdigits)
      (b* (((mv (the (integer 0 16) v) 
                (the (unsigned-byte 31) seed.))
            (genrandom-seed base seed.)))
        (mv v seed.))
    (b* (((mv (the (integer 0 64) v) 
              (the (unsigned-byte 31) seed.))
          (genrandom-seed (acl2::*f 4 base) seed.)))
     (if (>= v base)
         (b* (((mv v2 seed.); can do better type information here TODO
                 (random-natural-basemax2 base (1- maxdigits) seed.)))
             (mv (+ (- v base) (* base (nfix v2))) 
                 seed.))
      
       (mv v seed.)))))

(defun random-natural-seed/0.25 (seed.)
  (declare (type (unsigned-byte 31) seed.))
  (declare (xargs :guard (unsigned-byte-p 31 seed.)))
  (mbe :logic (if (unsigned-byte-p 31 seed.)
                    (random-natural-basemax2 10 6 seed.)
                  (random-natural-basemax2 10 6 1382728371)) ;random seed in random-state-basis1
       :exec  (random-natural-basemax2 10 6 seed.)))
      
;(defstub (random-natural-seed *) => (mv * *) :formals (seed.) :guard (unsigned-byte-p 31 seed.))
(encapsulate
 (((random-natural-seed *) => (mv * *) :formals (seed.) :guard (unsigned-byte-p 31 seed.)))
 (local (defun random-natural-seed (seed.)
          (declare (xargs :guard (unsigned-byte-p 31 seed.)))
          (mbe :logic (if (unsigned-byte-p 31 seed.)
                          (mv 0 seed.)
                        (mv 0 1382728371))
               :exec (mv 0 seed.))))

(defthm random-natural-seed-type-consp
  (consp (random-natural-seed r))
  :rule-classes (:type-prescription))

 (defthm random-natural-seed-type-car
  (implies (unsigned-byte-p 31 r)
           (natp (car (random-natural-seed r))))
  :rule-classes (:type-prescription))

(defthm random-natural-seed-type-car-type
  (implies (natp r)
           (and (integerp (car (random-natural-seed r)))
                (>= (car (random-natural-seed r)) 0)))
  :rule-classes :type-prescription)

(defthm random-natural-seed-type-cadr
  (implies (unsigned-byte-p 31 r)
           (unsigned-byte-p 31 (mv-nth 1 (random-natural-seed r))))
  :rule-classes (:type-prescription))

(defthm random-natural-seed-type-cadr-linear
  (and (<= 0 (mv-nth 1 (random-natural-seed r)))
       (< (mv-nth 1 (random-natural-seed r)) 2147483648))
  :rule-classes (:linear :tau-system))

(defthm random-natural-seed-type-cadr-type
  (and (integerp (mv-nth 1 (random-natural-seed r)))
       (>= (mv-nth 1 (random-natural-seed r)) 0))
  :rule-classes (:type-prescription))

 )


(defun random-small-natural-seed (seed.)
  (declare (type (unsigned-byte 31) seed.))
  (declare (xargs :guard (unsigned-byte-p 31 seed.)))
  (mbe :logic (if (unsigned-byte-p 31 seed.)
                  (random-natural-basemax1 10 3 seed.)
                (random-natural-basemax1 10 3 1382728371)) ;random seed in random-state-basis1
       :exec  (random-natural-basemax1 10 3 seed.)))

(defmacro random-index-seed (max seed.)
  `(genrandom-seed ,max ,seed.))


(defthm random-natural-basemax1-type-car
  (implies (and (posp b) (natp d) (natp r))
           (and (integerp (car (random-natural-basemax1 b d r)))
                (>= (car (random-natural-basemax1 b d r)) 0)))
  :rule-classes (:type-prescription))


(defthm random-natural-basemax1-type-cadr
  (implies (and (posp b) (natp d) (unsigned-byte-p 31 r))
           (unsigned-byte-p 31 (mv-nth 1 (random-natural-basemax1 b d r))))
  :rule-classes  :type-prescription)

(defthm random-natural-basemax1-type-cadr-0
  (implies (and (posp b) (natp d) (unsigned-byte-p 31 r))
           (and (<= 0 (mv-nth 1 (random-natural-basemax1 b d r)))
                (< (mv-nth 1 (random-natural-basemax1 b d r)) 2147483648)))
  :rule-classes (:linear :type-prescription))

(defthm random-natural-basemax1-type-cadr-type
  (implies (and (posp b) (natp d) (natp r))
           (and (integerp (mv-nth 1 (random-natural-basemax1 b d r)))
                (>= (mv-nth 1 (random-natural-basemax1 b d r)) 0)))
  :rule-classes (:type-prescription))



(defthm random-natural-basemax2-type-car
  (implies (and (posp b) (natp d) (natp r))
           (and (integerp (car (random-natural-basemax2 b d r)))
                (>= (car (random-natural-basemax2 b d r)) 0)))
  :rule-classes (:type-prescription))


(defthm random-natural-basemax2-type-cadr
  (implies (and (posp b) (natp d) (unsigned-byte-p 31 r))
           (unsigned-byte-p 31 (mv-nth 1 (random-natural-basemax2 b d r))))
  :rule-classes  :type-prescription)

(defthm random-natural-basemax2-type-cadr-0
  (implies (and (posp b) (natp d) (unsigned-byte-p 31 r))
           (and (<= 0 (mv-nth 1 (random-natural-basemax2 b d r)))
                (< (mv-nth 1 (random-natural-basemax2 b d r)) 2147483648)))
  :rule-classes (:linear :type-prescription))

(defthm random-natural-basemax2-type-cadr-type
  (implies (and (posp b) (natp d) (natp r))
           (and (integerp (mv-nth 1 (random-natural-basemax2 b d r)))
                (>= (mv-nth 1 (random-natural-basemax2 b d r)) 0)))
  :rule-classes (:type-prescription))







(defthm random-natural-seed-type/0.5-car
  (implies (unsigned-byte-p 31 r)
           (natp (car (random-natural-seed/0.5 r))))
  :rule-classes (:type-prescription))

(defthm random-natural-seed-type/0.5-car-type
  (implies (natp r)
           (and (integerp (car (random-natural-seed/0.5 r)))
                (>= (car (random-natural-seed/0.5 r)) 0)))
  :rule-classes :type-prescription)

(defthm random-natural-seed-type/0.5-cadr
  (implies (unsigned-byte-p 31 r)
           (unsigned-byte-p 31 (mv-nth 1 (random-natural-seed/0.5 r))))
  :rule-classes (:type-prescription))

(defthm random-natural-seed-type/0.5-cadr-linear
;  (implies (unsigned-byte-p 31 r)
  (and (<= 0 (mv-nth 1 (random-natural-seed/0.5 r)))
       (< (mv-nth 1 (random-natural-seed/0.5 r)) 2147483648))
;)
  :rule-classes (:linear :tau-system))

(defthm random-natural-seed-type/0.5-cadr-type
;  (implies (natp r)
           (and (integerp (mv-nth 1 (random-natural-seed/0.5 r)))
                (>= (mv-nth 1 (random-natural-seed/0.5 r)) 0))
;)
  :rule-classes (:type-prescription))







(defthm random-natural-seed-type/0.25-car
  (implies (unsigned-byte-p 31 r)
           (natp (car (random-natural-seed/0.25 r))))
  :rule-classes (:type-prescription))

(defthm random-natural-seed-type/0.25-car-type
  (implies (natp r)
           (and (integerp (car (random-natural-seed/0.25 r)))
                (>= (car (random-natural-seed/0.25 r)) 0)))
  :rule-classes :type-prescription)

(defthm random-natural-seed-type/0.25-cadr
  (implies (unsigned-byte-p 31 r)
           (unsigned-byte-p 31 (mv-nth 1 (random-natural-seed/0.25 r))))
  :rule-classes (:type-prescription))

(defthm random-natural-seed-type/0.25-cadr-linear
;  (implies (unsigned-byte-p 31 r)
  (and (<= 0 (mv-nth 1 (random-natural-seed/0.25 r)))
       (< (mv-nth 1 (random-natural-seed/0.25 r)) 2147483648))
;)
  :rule-classes (:linear :tau-system))

(defthm random-natural-seed-type/0.25-cadr-type
;  (implies (natp r)
           (and (integerp (mv-nth 1 (random-natural-seed/0.25 r)))
                (>= (mv-nth 1 (random-natural-seed/0.25 r)) 0))
;)
  :rule-classes (:type-prescription))


(defattach random-natural-seed random-natural-seed/0.25)
(in-theory (disable random-natural-basemax1
                    random-natural-seed/0.25
                    random-natural-seed/0.5
                    ))


(defun random-index-list-seed (k max seed.)
  (declare (type (unsigned-byte 31) seed.))
  (declare (xargs :verify-guards nil
                  :guard (unsigned-byte-p 31 seed.)))
  (if (zp k)
      (mv '() seed.)
    (b* (((mv rest seed.) (random-index-list-seed (1- k) max seed.))
         ((mv n1 seed.)   (if (zp max) (mv 0 seed.) (random-index-seed max seed.))))
      (mv (cons n1 rest) seed.))))

(defun random-natural-list-seed (k seed.)
  (declare (type (unsigned-byte 31) seed.))
  (declare (xargs :verify-guards nil
                  :guard (unsigned-byte-p 31 seed.)))
  (if (zp k)
      (mv '() seed.)
    (b* (((mv rest seed.) (random-natural-list-seed (1- k) seed.))
         ((mv n1 seed.)   (random-natural-seed seed.)))
      (mv (cons n1 rest) seed.))))

; pseudo-uniform rational between 0 and 1 (inclusive)
;optimize later (copied from below but simplified)
(defun random-probability-seed (seed.)
  (declare (type (unsigned-byte 31) seed.))
  (declare (xargs :verify-guards nil ;TODO
                  :guard (unsigned-byte-p 31 seed.)))
  (mbe :logic (if (unsigned-byte-p 31 seed.)
                  (mv-let (a seed.)
                          (random-natural-seed seed.)
                          ;; try to bias this to get more of small probabilities (close to 1)
                          (let ((denom (if (int= a 0)
                                           (1+ a)
                                         a)))
                            (mv-let (numer seed.)
                                    (genrandom-seed (1+ denom) seed.)
                                    (mv (/ numer denom) seed.))))
                (mv 0 seed.))
       :exec (mv-let (a seed.)
                     (random-natural-seed seed.)
                     (let ((denom (if (int= a 0)
                                           (1+ a)
                                         a)))
                       (mv-let (numer seed.)
                               (genrandom-seed (1+ denom) seed.)
                               (mv (/ numer denom) seed.))))))
                

;optimize later (copied from below)
(defun random-rational-between-seed (lo hi seed.)
  (declare (type (unsigned-byte 31) seed.))
  (declare (xargs :verify-guards nil
                  :guard (unsigned-byte-p 31 seed.)))
  (mv-let (p seed.)
          (random-probability-seed seed.)
          (mv (rfix (+ lo (* p (- hi lo)))) seed.)))


(defun random-integer-seed (seed.)
  (declare (type (unsigned-byte 31) seed.))
  (declare (xargs :guard (unsigned-byte-p 31 seed.)))
  (mv-let (num seed.)
          (genrandom-seed 2 seed.)
          (mv-let (nat seed.)
                  (random-natural-seed seed.)
                  (mv (if (int= num 0) nat (- nat))
                      seed.))))

(defun random-integer-between-seed (lo hi seed.)
  (declare (type (unsigned-byte 31) seed.)
           (type (signed-byte 30) lo)
           (type (signed-byte 30) hi))
  (declare (xargs :guard (and (unsigned-byte-p 31 seed.)
                              (integerp lo)
                              (integerp hi)
                              (signed-byte-p 30 lo)
                              (signed-byte-p 30 hi)
                              (posp (- hi lo)))))
  (mv-let (num seed.)
          (genrandom-seed (1+ (- hi lo)) seed.)
          (mv (+ lo num) seed.)))

(defun random-complex-rational-between-seed (lo hi seed.)
  (declare (xargs :verify-guards nil
                  :guard (unsigned-byte-p 31 seed.)))
  (declare (type (unsigned-byte 31) seed.))
  (b* (((mv rp seed.) (random-rational-between-seed (realpart lo) (realpart hi) seed.))
       ((mv ip seed.) (random-rational-between-seed (imagpart lo) (imagpart hi) seed.)))
    (mv (complex rp ip) seed.)))

(defun random-acl2-number-between-seed (lo hi seed.)
  (declare (xargs :verify-guards nil
                  :guard (unsigned-byte-p 31 seed.)))
  (b* (((mv choice seed.)
        (random-index-seed 6 seed.)))
    (case choice
          (0 (random-integer-between-seed lo hi seed.))
          (1 (random-rational-between-seed lo hi seed.))
          (5 (random-complex-rational-between-seed lo hi seed.))
          (t (random-integer-between-seed lo hi seed.)))))

(defun random-number-between-seed-fn (lo hi seed. type)
  (declare (xargs :verify-guards nil
                  :guard (unsigned-byte-p 31 seed.)))
  (case type
    (acl2s::integer (random-integer-between-seed lo hi seed.))
    (acl2s::rational (random-rational-between-seed lo hi seed.))
    (acl2s::complex-rational (random-complex-rational-between-seed lo hi seed.))
    (t (random-acl2-number-between-seed lo hi seed.))))

(defmacro random-number-between-seed (lo hi seed. &key type)
  `(random-number-between-seed-fn ,lo ,hi ,seed. (or ,type 'acl2s::acl2-number)))
