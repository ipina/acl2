;; AUTHOR:
;; Shilpi Goel <shigoel@cs.utexas.edu>

(in-package "X86ISA")

(include-book "add")
(include-book "sub")
(include-book "or")
(include-book "and")
(include-book "xor")

;; ======================================================================

(defun gpr-arith/logic-spec-gen-fn (operand-size)

  (declare (type (member 1 2 4 8) operand-size)
	   (xargs :verify-guards nil))

  (b* ((fn-name          (mk-name "gpr-arith/logic-spec-" operand-size))
       (gpr-add-spec-fn  (mk-name "gpr-add-spec-"   operand-size))
       (gpr-adc-spec-fn  (mk-name "gpr-adc-spec-"   operand-size))
       (?gpr-sub-spec-fn  (mk-name "gpr-sub-spec-"   operand-size))
       (?gpr-sbb-spec-fn  (mk-name "gpr-sbb-spec-"   operand-size))
       (?gpr-cmp-spec-fn  (mk-name "gpr-cmp-spec-"   operand-size))
       (?gpr-or-spec-fn   (mk-name "gpr-or-spec-"    operand-size))
       (?gpr-and-spec-fn  (mk-name "gpr-and-spec-"   operand-size))
       (?gpr-xor-spec-fn  (mk-name "gpr-xor-spec-"   operand-size))
       (?gpr-test-spec-fn (mk-name "gpr-test-spec-"  operand-size)))

      `(define ,fn-name
	 ((operation :type (member #.*OP-ADD* #.*OP-ADC* #.*OP-SUB*
				   #.*OP-SBB* #.*OP-CMP* #.*OP-OR*
				   #.*OP-AND* #.*OP-XOR* #.*OP-TEST*))
	  (dst          :type (unsigned-byte ,(ash operand-size 3)))
	  (src          :type (unsigned-byte ,(ash operand-size 3)))
	  (input-rflags :type (unsigned-byte 32)))

	 :parents (gpr-arith/logic-spec)
	 :enabled t
	 (case operation
	   (#.*OP-ADD* ;; 0
	    (,gpr-add-spec-fn dst src input-rflags))
	   (#.*OP-OR* ;; 1
	    (,gpr-or-spec-fn dst src input-rflags))
	   (#.*OP-ADC* ;; 2
	    (,gpr-adc-spec-fn dst src input-rflags))
	   (#.*OP-AND* ;; 3
	    (,gpr-and-spec-fn dst src input-rflags))
	   (#.*OP-SUB* ;; 4
	    (,gpr-sub-spec-fn dst src input-rflags))
	   (#.*OP-XOR* ;; 5
	    (,gpr-xor-spec-fn dst src input-rflags))
	   (#.*OP-SBB* ;; 6
	    (,gpr-sbb-spec-fn dst src input-rflags))
	   (#.*OP-TEST* ;; 7
	    ;; We will re-use the AND specification here.
	    (,gpr-and-spec-fn dst src input-rflags))
	   (#.*OP-CMP* ;; 8
	    ;; We will re-use the SUB specification here.
	    (,gpr-sub-spec-fn dst src input-rflags))
	   (otherwise
	    ;; The guard will prevent us from reaching here.
	    (mv 0 0 0))))))

(make-event (gpr-arith/logic-spec-gen-fn  1))
(make-event (gpr-arith/logic-spec-gen-fn  2))
(make-event (gpr-arith/logic-spec-gen-fn  4))
(make-event (gpr-arith/logic-spec-gen-fn  8))

(defsection gpr-arith/logic-spec

  :parents (x86-instruction-semantics)
  :short "Semantics of general-purpose arithmetic and logical instructions"
  :long "<p>These instructions are:</p>
<ul>
<li>@('ADD')</li>
<li>@('ADC')</li>
<li>@('SUB')</li>
<li>@('SBB')</li>
<li>@('CMP')</li>
<li>@('OR')</li>
<li>@('AND')</li>
<li>@('XOR')</li>
<li>@('TEST')</li>
</ul>

@(def gpr-arith/logic-spec)"

  (defmacro gpr-arith/logic-spec
    (operand-size operation dst src input-rflags)
    `(case ,operand-size
       (1 (gpr-arith/logic-spec-1 ,operation ,dst ,src ,input-rflags))
       (2 (gpr-arith/logic-spec-2 ,operation ,dst ,src ,input-rflags))
       (4 (gpr-arith/logic-spec-4 ,operation ,dst ,src ,input-rflags))
       (otherwise
	(gpr-arith/logic-spec-8 ,operation ,dst ,src ,input-rflags)))))

;; ======================================================================
