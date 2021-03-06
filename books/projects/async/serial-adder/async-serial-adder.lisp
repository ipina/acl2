;; Cuong Chau <ckcuong@cs.utexas.edu>
;; June 2017

(in-package "ADE")

(include-book "adder")
(include-book "async-serial-adder-control")
(include-book "link-joint")
(include-book "store-n")
(include-book "vector-module")

(local (include-book "arithmetic/top" :dir :system))
(local (include-book "centaur/gl/gl" :dir :system))

(local (in-theory (e/d (f-buf-delete-lemmas-1
                        f-buf-delete-lemmas-2)
                       (nth-of-bvp-is-booleanp
                        bvp-cvzbv))))

;; ======================================================================

;; One-Bit Full-Adder

(module-generator
 1-bit-adder* ()
 '1-bit-adder
 (list* 'a-act 'a-in 'b-act 'b-in 'dr-l-ci 's-act
        (sis 'go 0 2))
 '(empty-a- empty-b- ready-out s-out ci-out)
 '(l-a a l-b b l-ci ci l-s s l-co co)
 (list
  ;;; Links
  ;; L-A
  '(l-a (l-a-status) link-st (a-act add-act))
  '(a (a-out a-out~) latch (a-act a-in))

  ;; L-B
  '(l-b (l-b-status) link-st (b-act add-act))
  '(b (b-out b-out~) latch (b-act b-in))

  ;; L-CI
  '(l-ci (l-ci-status) link-st (carry-act comb-dr-l-ci))
  '(ci (ci-out ci-out~) latch (carry-act ci-in))

  ;; L-S
  '(l-s (l-s-status) link-st (add-act s-act))
  '(s (s-out s-out~) latch (add-act s-in))

  ;; L-CO
  '(l-co (l-co-status) link-st (add-act carry-act))
  '(co (co-out co-out~) latch (add-act co-in))

  ;;; Joints
  ;; Full-adder
  '(g0 (add-full-in) b-and3 (l-a-status l-b-status l-ci-status))
  '(g1 (add-empty-out) b-or (l-s-status l-co-status))
  (list 'j-add
        '(add-act)
        'joint-cntl
        (list 'add-full-in 'add-empty-out (si 'go 0)))
      
  '(h0 (s-in co-in) full-adder (a-out b-out ci-out))

  ;; CO to CI
  (list 'j-carry
        '(carry-act)
        'joint-cntl
        (list 'l-co-status 'l-ci-status (si 'go 1)))
      
  '(h1 (ci-in) b-buf (co-out))

  '(c0 (comb-dr-l-ci) b-or (add-act dr-l-ci))

  ;;; Status
  ;; '(s0 (l-a+b-status~) b-nand (l-a-status l-b-status))
  ;; '(empty--s (empty-) b-nand (l-ci-status l-a+b-status~))
  
  '(s0 (l-a-status~) b-not (l-a-status))
  '(in-status-a (empty-a-) b-nand (l-ci-status l-a-status~))

  '(s1 (l-b-status~) b-not (l-b-status))
  '(in-status-b (empty-b-) b-nand (l-ci-status l-b-status~))

  '(out-status (ready-out) b-and (l-ci-status l-s-status))
  )

 :guard t)

(defun 1-bit-adder$netlist ()
  (declare (xargs :guard t))
  (cons (1-bit-adder*)
        (union$ *link-st* *joint-cntl* *full-adder*
                :test 'equal)))

(defthmd 1-bit-adder$netlist-okp
  (and (net-syntax-okp (1-bit-adder$netlist))
       (net-arity-okp (1-bit-adder$netlist))))

(defund 1-bit-adder& (netlist)
  (declare (xargs :guard (alistp netlist)))
  (and (equal (assoc '1-bit-adder netlist)
              (1-bit-adder*))
       (b* ((netlist (delete-to-eq '1-bit-adder netlist)))
         (and (link-st& netlist)
              (joint-cntl& netlist)
              (full-adder& netlist)))))

(defund 1-bit-adder$empty-a- (st)
  (b* ((l-a  (nth 0 st))
       (l-ci (nth 4 st)))
    (f-nand (car (car l-ci))
            (f-not (car (car l-a))))))

(defund 1-bit-adder$empty-b- (st)
  (b* ((l-b  (nth 2 st))
       (l-ci (nth 4 st)))
    (f-nand (car (car l-ci))
            (f-not (car (car l-b))))))

(defund 1-bit-adder$ready-out (st)
  (b* ((l-ci (nth 4 st))
       (l-s  (nth 6 st)))
    (f-and (car (car l-ci))
           (car (car l-s)))))

(defthmd 1-bit-adder$value
  (b* ((st (list l-a a l-b b l-ci ci l-s s l-co co)))
    (implies (1-bit-adder& netlist)
             (equal (se '1-bit-adder inputs st netlist)
                    (list (1-bit-adder$empty-a- st)
                          (1-bit-adder$empty-b- st)
                          (1-bit-adder$ready-out st)
                          (f-buf (car s))
                          (f-buf (car ci))))))
  :hints (("Goal" :in-theory (e/d* (se-rules
                                    1-bit-adder&
                                    1-bit-adder*$destructure
                                    link-st$value
                                    joint-cntl$value
                                    full-adder$value
                                    1-bit-adder$ready-out
                                    1-bit-adder$empty-a-
                                    1-bit-adder$empty-b-)
                                   ((1-bit-adder*)
                                    (si)
                                    (sis)
                                    tv-disabled-rules)))))

(defun 1-bit-adder$state-fn (inputs st)
  (b* ((a-act    (nth 0 inputs))
       (a-in     (nth 1 inputs))
       (b-act    (nth 2 inputs))
       (b-in     (nth 3 inputs))
       (dr-l-ci  (nth 4 inputs))
       (s-act    (nth 5 inputs))
       (go-signals (nthcdr 6 inputs))
       
       (go-add   (nth 0 go-signals))
       (go-carry (nth 1 go-signals))
       
       (l-a  (nth 0 st))
       (a   (nth 1 st))
       (l-b  (nth 2 st))
       (b   (nth 3 st))
       (l-ci (nth 4 st))
       (ci  (nth 5 st))
       (l-s  (nth 6 st))
       (s   (nth 7 st))
       (l-co (nth 8 st))
       (co  (nth 9 st))
       
       (add-act (joint-act (f-and3 (caar l-a) (caar l-b) (caar l-ci))
                           (f-or (caar l-s) (caar l-co))
                           go-add))
       (carry-act (joint-act (caar l-co) (caar l-ci) go-carry)))
    
    (list (list
           (list
            (f-sr a-act add-act (caar l-a))))
          (list
           (f-if a-act a-in (car a)))
                         
          (list
           (list
            (f-sr b-act add-act (caar l-b))))
          (list
           (f-if b-act b-in (car b)))
                         
          (list
           (list
            (f-sr carry-act (f-or add-act dr-l-ci) (caar l-ci))))
          (list
           (f-if carry-act (car co) (car ci)))

          (list
           (list
            (f-sr add-act s-act (caar l-s))))
          (list
           (f-if add-act
                 (f-xor3 (car ci)
                         (f-if a-act a-in (car a))
                         (f-if b-act b-in (car b)))
                 (car s)))

          (list
           (list
            (f-sr add-act carry-act (caar l-co))))
          (list
           (f-if add-act
                 (f-or (f-and (f-if a-act a-in (car a))
                              (f-if b-act b-in (car b)))
                       (f-and (f-xor (f-if a-act a-in (car a))
                                     (f-if b-act b-in (car b)))
                              (car ci)))
                 (car co))))))

(defthm len-of-1-bit-adder$state-fn
  (equal (len (1-bit-adder$state-fn inputs st))
         10))

(defthmd 1-bit-adder$state
  (b* ((inputs (list* a-act a-in b-act b-in dr-l-ci s-act go-signals))
       (st (list l-a a l-b b l-ci ci l-s s l-co co)))
    (implies (and (1-bit-adder& netlist)
                  (>= (len go-signals) 2))
             (equal (de '1-bit-adder inputs st netlist)
                    (1-bit-adder$state-fn inputs st))))
  :hints (("Goal"
           :in-theory (e/d* (de-rules
                             1-bit-adder&
                             1-bit-adder*$destructure
                             link-st$value link-st$state
                             joint-cntl$value
                             full-adder$value)
                            ((1-bit-adder*)
                             (si)
                             (sis)
                             tv-disabled-rules)))))

(in-theory (disable 1-bit-adder$state-fn))

;; ======================================================================

;; 32-Bit Serial Adder

;; Two operands and the sum are stored in shift registers.

(module-generator
 serial-adder* ()
 'serial-adder
 (list* 'cntl-act 'bit-in 'result-act
        (sis 'go 0 5))
 (list* 'ready-in- 'ready-out
        (append (sis 'reg2-out 0 32) (list 'c-out)))
 '(l-reg0 reg0 l-reg1 reg1 l-reg2 reg2 bit-add-st)
 (list
  ;;; Links
  ;; L-REG0
  '(l-reg0 (l-reg0-status) link-st (cntl-act a-act))
  (list 'reg0 (sis 'reg0-out 0 32) 'shift-reg32 '(cntl-act bit-in))
  
  ;; L-REG1
  '(l-reg1 (l-reg1-status) link-st (cntl-act b-act))
  (list 'reg1 (sis 'reg1-out 0 32) 'shift-reg32 '(cntl-act bit-in))
  
  ;; L-REG2
  '(g (dr-l-reg2) b-or (cntl-act result-act))
  '(l-reg2 (l-reg2-status) link-st (s-act dr-l-reg2))
  (list 'reg2 (sis 'reg2-out 0 32) 'shift-reg32 '(s-act s-out))
  
  ;; BIT-ADD-ST
  (list 'bit-add-st
        '(bit-add-empty-a- bit-add-empty-b- bit-add-ready-out
                           s-out ci-out)
        '1-bit-adder
        (list* 'a-act 'a-in 'b-act 'b-in 'result-act 's-act
               (sis 'go 3 2)))
  '(carry-out (c-out) b-buf (ci-out))
  
  ;;; Joints
  ;; Fetch operand A
  (list 'j-a
        '(a-act)
        'joint-cntl
        (list 'l-reg0-status 'bit-add-empty-a- (si 'go 0)))
  
  (list 'h0 '(a-in) 'b-buf (list (si 'reg0-out 0)))
  
  ;; Fetch operand B
  (list 'j-b
        '(b-act)
        'joint-cntl
        (list 'l-reg1-status 'bit-add-empty-b- (si 'go 1)))
  
  (list 'h1 '(b-in) 'b-buf (list (si 'reg1-out 0)))
  
  ;; Write sum
  (list 'j-s
        '(s-act)
        'joint-cntl
        (list 'bit-add-ready-out 'l-reg2-status (si 'go 2)))
  
  ;;'(h2 (bit2-in) b-buf (s-out))
  
  ;;; Status
  '(s0 (l-reg2-status~) b-not (l-reg2-status))
  '(in-status (ready-in-) b-or3 (l-reg0-status l-reg1-status l-reg2-status~))
  '(out-status (ready-out) b-buf (l-reg2-status))
  )

 :guard t)

(defun serial-adder$netlist ()
  (declare (xargs :guard t))
  (cons (serial-adder*)
        (1-bit-adder$netlist)))

(defthmd serial-adder$netlist-okp
  (and (net-syntax-okp (serial-adder$netlist))
       (net-arity-okp (serial-adder$netlist))))

(defund serial-adder& (netlist)
  (declare (xargs :guard (alistp netlist)))
  (and (equal (assoc 'serial-adder netlist)
              (serial-adder*))
       (b* ((netlist (delete-to-eq 'serial-adder netlist)))
         (and (link-st& netlist)
              (joint-cntl& netlist)
              (1-bit-adder& netlist)))))

(defthm check-serial-adder$netlist
  (serial-adder& (serial-adder$netlist)))

(defund serial-adder$ready-in- (st)
  (b* ((l-reg0 (nth 0 st))
       (l-reg1 (nth 2 st))
       (l-reg2 (nth 4 st)))
    (f-or3 (car (car l-reg0))
           (car (car l-reg1))
           (f-not (car (car l-reg2))))))

(defund serial-adder$ready-out (st)
  (b* ((l-reg2 (nth 4 st)))
    (f-buf (car (car l-reg2)))))

(defthmd serial-adder$value
  (b* ((bit-add-st (list l-a a l-b b l-ci ci l-s s l-co co))
       (st (list l-reg0 reg0 l-reg1 reg1 l-reg2 reg2 bit-add-st)))
    (implies (and (serial-adder& netlist)
                  (true-listp (car reg2))
                  (equal (len (car reg2)) 32))
             (equal (se 'serial-adder inputs st netlist)
                    (list* (serial-adder$ready-in- st)
                           (serial-adder$ready-out st)
                           (append (car reg2)
                                   (list (f-buf (car ci))))))))
  :hints (("Goal" :in-theory (e/d (se-rules
                                   serial-adder&
                                   serial-adder*$destructure
                                   link-st$value
                                   joint-cntl$value
                                   1-bit-adder$value
                                   serial-adder$ready-out
                                   serial-adder$ready-in-)
                                  ((serial-adder*)
                                   (si)
                                   (sis)
                                   tv-disabled-rules)))))

(defun serial-adder$state-fn (inputs st)
  (b* ((cntl-act   (nth 0 inputs))
       (bit-in     (nth 1 inputs))
       (result-act (nth 2 inputs))
       (go-signals (nthcdr 3 inputs))
       
       (go-a       (nth 0 go-signals))
       (go-b       (nth 1 go-signals))
       (go-s       (nth 2 go-signals))
       (1-bit-adder$go-signals (nthcdr 3 go-signals))

       (l-reg0    (nth 0 st))
       (reg0     (nth 1 st))
       (l-reg1    (nth 2 st))
       (reg1     (nth 3 st))
       (l-reg2    (nth 4 st))
       (reg2     (nth 5 st))
       (bit-add-st (nth 6 st))
       
       (s   (nth 7 bit-add-st))

       (a-act (joint-act (caar l-reg0)
                         (1-bit-adder$empty-a- bit-add-st)
                         go-a))
       (a-in (f-buf (caar reg0)))
       (b-act (joint-act (caar l-reg1)
                         (1-bit-adder$empty-b- bit-add-st)
                         go-b))
       (b-in (f-buf (caar reg1)))
       (s-act (joint-act (1-bit-adder$ready-out bit-add-st)
                         (caar l-reg2)
                         go-s))
       (1-bit-adder$inputs (list* a-act a-in b-act b-in result-act s-act
                                  1-bit-adder$go-signals)))
    
    (list (list
            (list
             (f-sr cntl-act a-act (caar l-reg0))))
           (list
            (write-shift-reg cntl-act bit-in (car reg0)))
           
           (list
            (list
             (f-sr cntl-act b-act (caar l-reg1))))
           (list
            (write-shift-reg cntl-act bit-in (car reg1)))
           
           (list
            (list
             (f-sr s-act
                   (f-or cntl-act result-act)
                   (caar l-reg2))))
           (list
            (write-shift-reg s-act (car s) (car reg2)))
           
           (1-bit-adder$state-fn 1-bit-adder$inputs bit-add-st))))

(defthm len-of-serial-adder$state-fn
  (equal (len (serial-adder$state-fn inputs st))
         7))

(defthmd serial-adder$state
  (b* ((inputs (list* cntl-act bit-in result-act
                      go-signals))
       (bit-add-st (list l-a a l-b b l-ci ci l-s s l-co co))
       (st (list l-reg0 reg0 l-reg1 reg1 l-reg2 reg2 bit-add-st)))
    (implies (and (serial-adder& netlist)
                  
                  (true-listp go-signals)
                  (equal (len go-signals) 5)
                  
                  (equal (len (car reg0)) 32)
                  (equal (len (car reg1)) 32)
                  (equal (len (car reg2)) 32))
             (equal (de 'serial-adder inputs st netlist)
                    (serial-adder$state-fn inputs st))))
  :hints (("Goal"
           :in-theory (e/d* (de-rules
                             serial-adder&
                             serial-adder*$destructure
                             link-st$value link-st$state
                             joint-cntl$value
                             1-bit-adder$value
                             1-bit-adder$state
                             take-of-len-is-itself
                             assoc-eq-values-of-sis-pairlis$-sis)
                            ((serial-adder*)
                             (si)
                             (sis)
                             tv-disabled-rules)))))

(in-theory (disable serial-adder$state-fn))

;; ======================================================================

;; 32-Bit Asynchronous Serial Adder with Control

(module-generator
 async-adder* ()
 'async-adder
 (list* 'dr-l-result (sis 'go 0 8))
 (list* 'ready-in- 'ready-out (sis 'result-out 0 33))
 '(l-cntl cntl l-next-cntl next-cntl l-done- done- l-result result
          serial-add-st)
 
 (list
  ;;; Links
  ;; L-CNTL
  '(l-cntl (l-cntl-status) link-st (cntl-buf-act cntl-act))
  (list 'cntl
        (sis 'cntl-out 0 5)
        (si 'latch-n 5)
        (list* 'cntl-buf-act (sis 'cntl-in 0 5)))

  ;; L-NEXT-CNTL
  '(l-next-cntl (l-next-cntl-status) link-st (cntl-act cntl-buf-act))
  (list 'next-cntl
        (sis 'next-cntl-out 0 5)
        (si 'latch-n 5)
        (list* 'cntl-act (sis 'next-cntl-in 0 5)))

  ;; L-DONE-
  '(l-done- (l-done-status) link-st (cntl-act dr-l-done-))
  '(done- (done-out- done-out) latch (cntl-act done-in-))

  ;; L-RESULT
  '(l-result (l-result-status) link-st (result-act dr-l-result))
  (list 'result
        (sis 'result-out 0 33)
        (si 'latch-n 33)
        (list* 'result-act (append (sis 'sum 0 32) (list 'carry))))
      
  ;; SERIAL-ADD-ST
  (list 'serial-add-st
        (list* 'serial-add-ready-in- 'serial-add-ready-out
               (append (sis 'sum 0 32) (list 'carry)))
        'serial-adder
        (list* 'cntl-act 'low 'result-act (sis 'go 3 5)))

  ;;; Joints
  ;; Next control state
  '(g0 (cntl-ready) b-or3 (l-next-cntl-status l-done-status
                                              serial-add-ready-in-))
  (list 'j-next-state
        '(cntl-act)
        'joint-cntl
        (list 'l-cntl-status 'cntl-ready (si 'go 0)))
      
  (list 'h0
        (list* 'low 'done-in- (sis 'next-cntl-in 0 5))
        'next-cntl-state
        (sis 'cntl-out 0 5))

  ;; Buffer control state
  '(g1 (next-cntl-ready) b-and3 (l-next-cntl-status l-done-status done-out-))
  (list 'j-buf-state
        '(cntl-buf-act)
        'joint-cntl
        (list 'next-cntl-ready 'l-cntl-status (si 'go 1)))
  
  (list 'buf-state
        (sis 'cntl-in 0 5)
        (si 'v-buf 5)
        (sis 'next-cntl-out 0 5))

  ;; Store the result to RESULT register
  '(g2 (result-ready) b-and3 (serial-add-ready-out l-done-status done-out))
  (list 'j-result
        '(result-act)
        'joint-cntl
        (list 'result-ready 'l-result-status (si 'go 2)))

  '(j-done- (dr-l-done-) b-or (cntl-buf-act result-act))

;;; Status
  '(s0 (l-next-cntl-status~) b-not (l-next-cntl-status))
  '(in-status (ready-in-) b-or3 (l-next-cntl-status~
                                 l-done-status
                                 l-result-status))
  '(out-status (ready-out) b-buf (l-result-status))
  )

 :guard t)

(defun async-adder$netlist ()
  (declare (xargs :guard t))
  (cons (async-adder*)
        (union$ (latch-n$netlist 5)
                (latch-n$netlist 33)
                (v-buf$netlist 5)
                (serial-adder$netlist)
                (next-cntl-state$netlist)
                :test 'equal)))

(defthmd async-adder$netlist-okp
  (and (net-syntax-okp (async-adder$netlist))
       (net-arity-okp (async-adder$netlist))))

(defund async-adder& (netlist)
  (declare (xargs :guard (alistp netlist)))
  (and (equal (assoc 'async-adder netlist)
              (async-adder*))
       (b* ((netlist (delete-to-eq 'async-adder netlist)))
         (and (link-st& netlist)
              (joint-cntl& netlist)
              (latch-n& netlist 5)
              (latch-n& netlist 33)
              (v-buf& netlist 5)
              (serial-adder& netlist)
              (next-cntl-state& netlist)))))

(defthm check-async-adder$netlist
  (async-adder& (async-adder$netlist)))

(defund async-adder$ready-in- (st)
  (b* ((l-next-cntl (nth 2 st))
       (l-done-     (nth 4 st))
       (l-result    (nth 6 st)))
    (f-or3 (f-not (caar l-next-cntl))
           (caar l-done-)
           (caar l-result))))

(defund async-adder$ready-out (st)
  (b* ((l-result (nth 6 st)))
    (f-buf (caar l-result))))

(defthmd async-adder$value
  (b* ((bit-add-st (list l-a a l-b b l-ci ci l-s s l-co co))
       (serial-add-st (list l-reg0 reg0 l-reg1 reg1 l-reg2 reg2
                         bit-add-st))
       (st (list l-cntl cntl l-next-cntl next-cntl l-done- done-
                 l-result result
                 serial-add-st)))
    (implies (and (async-adder& netlist)
                  (true-listp result)
                  (equal (len result) 33)
                  (true-listp (car reg2))
                  (equal (len (car reg2)) 32))
             (equal (se 'async-adder inputs st netlist)
                    (list* (async-adder$ready-in- st)
                           (async-adder$ready-out st)
                           (v-threefix (strip-cars result))))))
  :hints (("Goal"
           :in-theory (e/d (se-rules
                            async-adder&
                            async-adder*$destructure
                            link-st$value
                            joint-cntl$value
                            latch-n$value
                            v-buf$value
                            next-cntl-state$value
                            serial-adder$value
                            async-adder$ready-out
                            async-adder$ready-in-)
                           ((async-adder*)
                            (si)
                            (sis)
                            open-v-threefix
                            tv-disabled-rules)))))

(defun async-adder$state-fn (inputs st)
  (b* ((dr-l-result (nth 0 inputs))
       (go-signals (nthcdr 1 inputs))
       
       (go-cntl     (nth 0 go-signals))
       (go-buf-cntl (nth 1 go-signals))
       (go-result   (nth 2 go-signals))
       (serial-adder$go-signals (nthcdr 3 go-signals))
       
       (l-cntl (nth 0 st))
       (cntl (nth 1 st))
       (l-next-cntl (nth 2 st))
       (next-cntl (nth 3 st))
       (l-done- (nth 4 st))
       (done- (nth 5 st))
       (l-result (nth 6 st))
       (result (nth 7 st))
       (serial-add-st (nth 8 st))
       
       (reg2 (nth 5 serial-add-st))
       (bit-add-st (nth 6 serial-add-st))
       
       (ci (nth 5 bit-add-st)))

    (list
     (list
      (list (f-sr (joint-act (f-and3 (car (car l-next-cntl))
                                     (car (car l-done-))
                                     (car done-))
                             (car (car l-cntl))
                             go-buf-cntl)
                  (joint-act (car (car l-cntl))
                             (f-or3 (car (car l-next-cntl))
                                    (car (car l-done-))
                                    (serial-adder$ready-in- serial-add-st))
                             go-cntl)
                  (car (car l-cntl)))))
     (pairlis$ (fv-if (joint-act (f-and3 (car (car l-next-cntl))
                                         (car (car l-done-))
                                         (car done-))
                                 (car (car l-cntl))
                                 go-buf-cntl)
                      (strip-cars next-cntl)
                      (strip-cars cntl))
               nil)
     (list
      (list (f-sr (joint-act (car (car l-cntl))
                             (f-or3 (car (car l-next-cntl))
                                    (car (car l-done-))
                                    (serial-adder$ready-in- serial-add-st))
                             go-cntl)
                  (joint-act (f-and3 (car (car l-next-cntl))
                                     (car (car l-done-))
                                     (car done-))
                             (car (car l-cntl))
                             go-buf-cntl)
                  (car (car l-next-cntl)))))
     (pairlis$
      (fv-if (joint-act (car (car l-cntl))
                        (f-or3 (car (car l-next-cntl))
                               (car (car l-done-))
                               (serial-adder$ready-in- serial-add-st))
                        go-cntl)
             (f$next-cntl-state (v-threefix (strip-cars cntl)))
             (strip-cars next-cntl))
      nil)
     (list
      (list (f-sr (joint-act (car (car l-cntl))
                             (f-or3 (car (car l-next-cntl))
                                    (car (car l-done-))
                                    (serial-adder$ready-in- serial-add-st))
                             go-cntl)
                  (f-or (joint-act (f-and3 (car (car l-next-cntl))
                                           (car (car l-done-))
                                           (car done-))
                                   (car (car l-cntl))
                                   go-buf-cntl)
                        (joint-act (f-and3 (serial-adder$ready-out serial-add-st)
                                           (car (car l-done-))
                                           (f-not (car done-)))
                                   (car (car l-result))
                                   go-result))
                  (car (car l-done-)))))
     (list (f-if (joint-act (car (car l-cntl))
                            (f-or3 (car (car l-next-cntl))
                                   (car (car l-done-))
                                   (serial-adder$ready-in- serial-add-st))
                            go-cntl)
                 (compute-done- (v-threefix (strip-cars cntl)))
                 (car done-)))
     (list (list (f-sr (joint-act (f-and3 (serial-adder$ready-out serial-add-st)
                                          (car (car l-done-))
                                          (f-not (car done-)))
                                  (car (car l-result))
                                  go-result)
                       dr-l-result (car (car l-result)))))
     (pairlis$ (fv-if (joint-act (f-and3 (serial-adder$ready-out serial-add-st)
                                         (car (car l-done-))
                                         (f-not (car done-)))
                                 (car (car l-result))
                                 go-result)
                      (append (car reg2)
                              (list (f-buf (car ci))))
                      (strip-cars result))
               nil)
     (serial-adder$state-fn
      (list* (joint-act (car (car l-cntl))
                        (f-or3 (car (car l-next-cntl))
                               (car (car l-done-))
                               (serial-adder$ready-in- serial-add-st))
                        go-cntl)
             nil
             (joint-act (f-and3 (serial-adder$ready-out serial-add-st)
                                (car (car l-done-))
                                (f-not (car done-)))
                        (car (car l-result))
                        go-result)
             serial-adder$go-signals)
      serial-add-st))))

(defthm len-of-async-adder$state-fn
  (equal (len (async-adder$state-fn inputs st))
         9))

(defthmd async-adder$state
 (b* ((inputs (list* dr-l-result go-signals))
      (bit-add-st (list l-a a l-b b l-ci ci l-s s l-co co))
      (serial-add-st (list l-reg0 reg0 l-reg1 reg1 l-reg2 reg2 bit-add-st))
      (st (list l-cntl cntl l-next-cntl next-cntl l-done- done-
                l-result result
                serial-add-st)))
   (implies (and (async-adder& netlist)
                 
                 (true-listp go-signals)
                 (equal (len go-signals) 8)
                 
                 (len-1-true-listp cntl)
                 (equal (len cntl) 5)
                 (len-1-true-listp next-cntl)
                 (equal (len next-cntl) 5)
                 (true-listp result)
                 (equal (len result) 33)
                 (equal (len (car reg0)) 32)
                 (equal (len (car reg1)) 32)
                 (true-listp (car reg2))
                 (equal (len (car reg2)) 32))
            (equal (de 'async-adder inputs st netlist)
                   (async-adder$state-fn inputs st))))
 :hints (("Goal"
          :in-theory (e/d* (de-rules
                            async-adder&
                            async-adder*$destructure
                            link-st$value link-st$state
                            joint-cntl$value
                            latch-n$value latch-n$state
                            v-buf$value
                            next-cntl-state$value
                            serial-adder$value
                            serial-adder$state
                            take-of-len-is-itself
                            assoc-eq-values-of-sis-pairlis$-sis
                            open-nthcdr
                            list-rewrite-5
                            len-1-true-listp)
                           (nth
                            nthcdr
                            (async-adder*)
                            (si)
                            (sis)
                            open-v-threefix
                            tv-disabled-rules)))))

(in-theory (disable async-adder$state-fn))

;; ======================================================================

;; Prove the state invariant of the async serial adder for one iteration.

(defund async-adder$go-cntl (inputs)
  (declare (xargs :guard (true-listp inputs)))
  (b* ((go-signals (nthcdr 1 inputs)))
    (nth 0 go-signals)))

(defund async-adder$go-buf-cntl (inputs)
  (declare (xargs :guard (true-listp inputs)))
  (b* ((go-signals (nthcdr 1 inputs)))
    (nth 1 go-signals)))

(defund async-adder$go-result (inputs)
  (declare (xargs :guard (true-listp inputs)))
  (b* ((go-signals (nthcdr 1 inputs)))
    (nth 2 go-signals)))

(defund async-adder$go-a (inputs)
  (declare (xargs :guard (true-listp inputs)))
  (b* ((go-signals (nthcdr 1 inputs))
       (serial-adder$go-signals (nthcdr 3 go-signals)))
    (nth 0 serial-adder$go-signals)))

(defund async-adder$go-b (inputs)
  (declare (xargs :guard (true-listp inputs)))
  (b* ((go-signals (nthcdr 1 inputs))
       (serial-adder$go-signals (nthcdr 3 go-signals)))
    (nth 1 serial-adder$go-signals)))

(defund async-adder$go-s (inputs)
  (declare (xargs :guard (true-listp inputs)))
  (b* ((go-signals (nthcdr 1 inputs))
       (serial-adder$go-signals (nthcdr 3 go-signals)))
    (nth 2 serial-adder$go-signals)))

(defund async-adder$go-add (inputs)
  (declare (xargs :guard (true-listp inputs)))
  (b* ((go-signals (nthcdr 1 inputs))
       (serial-adder$go-signals (nthcdr 3 go-signals))
       (1-bit-adder$go-signals (nthcdr 3 serial-adder$go-signals)))
    (nth 0 1-bit-adder$go-signals)))

(defund async-adder$go-carry (inputs)
  (declare (xargs :guard (true-listp inputs)))
  (b* ((go-signals (nthcdr 1 inputs))
       (serial-adder$go-signals (nthcdr 3 go-signals))
       (1-bit-adder$go-signals (nthcdr 3 serial-adder$go-signals)))
    (nth 1 1-bit-adder$go-signals)))

(deftheory async-adder$go-signals
  '(async-adder$go-cntl
    async-adder$go-buf-cntl
    async-adder$go-result
    async-adder$go-a
    async-adder$go-b
    async-adder$go-s
    async-adder$go-add
    async-adder$go-carry))

(defund async-adder$input-format (inputs)
  (declare (xargs :guard (true-listp inputs)))
  (b* ((dr-l-result (nth 0 inputs))
       (go-signals (nthcdr 1 inputs)))
    (and
     (equal dr-l-result nil)
     (true-listp go-signals)
     (equal (len go-signals) 8)
     (equal inputs
            (list* dr-l-result go-signals)))))

(input-format-n-gen async-adder)

(defthmd async-adder$state-alt
 (b* ((l-cntl (nth 0 st))
      (cntl (nth 1 st))
      (l-next-cntl (nth 2 st))
      (next-cntl (nth 3 st))
      (l-done- (nth 4 st))
      (done- (nth 5 st))
      (l-result (nth 6 st))
      (result (nth 7 st))
      (serial-add-st (nth 8 st))
       
      (l-reg0 (nth 0 serial-add-st))
      (reg0 (nth 1 serial-add-st))
      (l-reg1 (nth 2 serial-add-st))
      (reg1 (nth 3 serial-add-st))
      (l-reg2 (nth 4 serial-add-st))
      (reg2 (nth 5 serial-add-st))
      (bit-add-st (nth 6 serial-add-st))
       
      (l-a (nth 0 bit-add-st))
      (a (nth 1 bit-add-st))
      (l-b (nth 2 bit-add-st))
      (b (nth 3 bit-add-st))
      (l-ci (nth 4 bit-add-st))
      (ci (nth 5 bit-add-st))
      (l-s (nth 6 bit-add-st))
      (s (nth 7 bit-add-st))
      (l-co (nth 8 bit-add-st))
      (co (nth 9 bit-add-st)))
   (implies (and (async-adder& netlist)
                 (async-adder$input-format inputs)
                 (equal st (list l-cntl cntl l-next-cntl
                                 next-cntl l-done- done- l-result result
                                 (list l-reg0 reg0 l-reg1 reg1 l-reg2 reg2
                                       (list l-a a l-b b l-ci ci l-s s l-co co))))
                 (len-1-true-listp cntl)
                 (equal (len cntl) 5)
                 (len-1-true-listp next-cntl)
                 (equal (len next-cntl) 5)
                 (true-listp result)
                 (equal (len result) 33)
                 (equal (len (car reg0)) 32)
                 (equal (len (car reg1)) 32)
                 (true-listp (car reg2))
                 (equal (len (car reg2)) 32))
            (equal (de 'async-adder inputs st netlist)
                   (async-adder$state-fn inputs st))))
 :hints (("Goal"
           :in-theory (enable async-adder$input-format)
           :use (:instance async-adder$state
                           (dr-l-result (nth 0 inputs))
                           (go-signals (nthcdr 1 inputs))

                           (l-cntl (nth 0 st))
                           (cntl (nth 1 st))
                           (l-next-cntl (nth 2 st))
                           (next-cntl (nth 3 st))
                           (l-done- (nth 4 st))
                           (done- (nth 5 st))
                           (l-result (nth 6 st))
                           (result (nth 7 st))
                           
                           (l-reg0 (nth 0 (nth 8 st)))
                           (reg0 (nth 1 (nth 8 st)))
                           (l-reg1 (nth 2 (nth 8 st)))
                           (reg1 (nth 3 (nth 8 st)))
                           (l-reg2 (nth 4 (nth 8 st)))
                           (reg2 (nth 5 (nth 8 st)))
      
                           (l-a (nth 0 (nth 6 (nth 8 st))))
                           (a (nth 1 (nth 6 (nth 8 st))))
                           (l-b (nth 2 (nth 6 (nth 8 st))))
                           (b (nth 3 (nth 6 (nth 8 st))))
                           (l-ci (nth 4 (nth 6 (nth 8 st))))
                           (ci (nth 5 (nth 6 (nth 8 st))))
                           (l-s (nth 6 (nth 6 (nth 8 st))))
                           (s (nth 7 (nth 6 (nth 8 st))))
                           (l-co (nth 8 (nth 6 (nth 8 st))))
                           (co (nth 9 (nth 6 (nth 8 st))))))))

(defun async-adder$state-fn-n (inputs-lst st n)
  (if (zp n)
      st
    (async-adder$state-fn-n
     (cdr inputs-lst)
     (async-adder$state-fn (car inputs-lst) st)
     (1- n))))

(defthm open-async-adder$state-fn-n
  (and
   (implies (zp n)
            (equal (async-adder$state-fn-n inputs-lst st n)
                   st))
   (implies (not (zp n))
            (equal (async-adder$state-fn-n inputs-lst st n)
                   (async-adder$state-fn-n
                    (cdr inputs-lst)
                    (async-adder$state-fn (car inputs-lst) st)
                    (1- n))))))

(defthm async-adder$state-fn-m+n
  (implies (and (natp m)
                (natp n))
           (equal (async-adder$state-fn-n inputs-lst st (+ m n))
                  (async-adder$state-fn-n
                   (nthcdr m inputs-lst)
                   (async-adder$state-fn-n inputs-lst st m)
                   n)))
  :hints (("Goal" :induct (async-adder$state-fn-n inputs-lst st m))))

(in-theory (disable async-adder$state-fn-n))

(defthmd de-sim-n$async-adder
  (b* ((l-cntl (nth 0 st))
       (cntl (nth 1 st))
       (l-next-cntl (nth 2 st))
       (next-cntl (nth 3 st))
       (l-done- (nth 4 st))
       (done- (nth 5 st))
       (l-result (nth 6 st))
       (result (nth 7 st))
       (serial-add-st (nth 8 st))
       
       (l-reg0 (nth 0 serial-add-st))
       (reg0 (nth 1 serial-add-st))
       (l-reg1 (nth 2 serial-add-st))
       (reg1 (nth 3 serial-add-st))
       (l-reg2 (nth 4 serial-add-st))
       (reg2 (nth 5 serial-add-st))
       (bit-add-st (nth 6 serial-add-st))
       
       (l-a (nth 0 bit-add-st))
       (a (nth 1 bit-add-st))
       (l-b (nth 2 bit-add-st))
       (b (nth 3 bit-add-st))
       (l-ci (nth 4 bit-add-st))
       (ci (nth 5 bit-add-st))
       (l-s (nth 6 bit-add-st))
       (s (nth 7 bit-add-st))
       (l-co (nth 8 bit-add-st))
       (co (nth 9 bit-add-st)))
    (implies (and (async-adder& netlist)
                  (async-adder$input-format-n inputs-lst n)
                  (equal st (list l-cntl cntl l-next-cntl
                                  next-cntl l-done- done- l-result result
                                  (list l-reg0 reg0 l-reg1 reg1 l-reg2 reg2
                                        (list l-a a l-b b l-ci ci l-s s l-co co))))
                  (len-1-true-listp cntl)
                  (equal (len cntl) 5)
                  (len-1-true-listp next-cntl)
                  (equal (len next-cntl) 5)
                  (true-listp result)
                  (equal (len result) 33)
                  (equal (len (car reg0)) 32)
                  (equal (len (car reg1)) 32)
                  (true-listp (car reg2))
                  (equal (len (car reg2)) 32))
             (equal (de-sim-n 'async-adder inputs-lst st netlist n)
                    (async-adder$state-fn-n inputs-lst st n))))
  :hints (("Goal"
           :do-not '(preprocess)
           :induct (de-sim-n 'async-adder inputs-lst st netlist n)
           :in-theory (e/d (de-sim-n
                            async-adder$state-alt
                            async-adder$state-fn
                            serial-adder$state-fn
                            list-rewrite-10)
                           (nth
                            nthcdr
                            pairlis$
                            strip-cars
                            true-listp)))))

(defund async-adder$inv-st (st)
  (b* ((l-cntl (nth 0 st))
       (cntl (nth 1 st))
       (l-next-cntl (nth 2 st))
       (next-cntl (nth 3 st))
       (l-done- (nth 4 st))
       (done- (nth 5 st))
       (l-result (nth 6 st))
       (result (nth 7 st))
       (serial-add-st (nth 8 st))
       
       (l-reg0 (nth 0 serial-add-st))
       (reg0 (nth 1 serial-add-st))
       (l-reg1 (nth 2 serial-add-st))
       (reg1 (nth 3 serial-add-st))
       (l-reg2 (nth 4 serial-add-st))
       (reg2 (nth 5 serial-add-st))
       (bit-add-st (nth 6 serial-add-st))
       
       (l-a (nth 0 bit-add-st))
       (?a (nth 1 bit-add-st))
       (l-b (nth 2 bit-add-st))
       (?b (nth 3 bit-add-st))
       (l-ci (nth 4 bit-add-st))
       (?ci (nth 5 bit-add-st))
       (l-s (nth 6 bit-add-st))
       (?s (nth 7 bit-add-st))
       (l-co (nth 8 bit-add-st))
       (?co (nth 9 bit-add-st)))
    
    (and (emptyp l-cntl)
         (len-1-true-listp cntl)
         (equal (len cntl) 5)
                    
         (fullp l-next-cntl)
         (len-1-true-listp next-cntl)
         (equal (len next-cntl) 5)
         (bvp (strip-cars next-cntl))
                    
         (fullp l-done-)
         (equal (car done-) t)
                    
         (emptyp l-result)
         (true-listp result)
         (equal (len result) 33)
          
         (fullp l-reg0)
         (equal (len (car reg0)) 32)
         (fullp l-reg1)
         (equal (len (car reg1)) 32)
         (emptyp l-reg2)
         (true-listp (car reg2))
         (equal (len (car reg2)) 32)
                    
         (emptyp l-a)
         (emptyp l-b)
         (fullp l-ci)
         (emptyp l-s)
         (emptyp l-co))))

(defconst *async-adder-interleavings*
  (prepend-rec
   (interleave-rec2 '(async-adder$go-buf-cntl)
                    (prepend-rec (interleave '(async-adder$go-a)
                                             '(async-adder$go-b))
                                 '(async-adder$go-add
                                   async-adder$go-carry
                                   async-adder$go-s)))
   '(async-adder$go-cntl)))

(defconst *async-adder-independ-lst*
  '((async-adder$go-buf-cntl async-adder$go-a async-adder$go-b)
    (async-adder$go-buf-cntl async-adder$go-add)
    (async-adder$go-buf-cntl async-adder$go-carry)
    (async-adder$go-buf-cntl async-adder$go-s)))

(make-event `,(st-trans-fn 'async-adder
                           *async-adder-interleavings*
                           *async-adder-independ-lst*))

(defund extract-async-adder-result-status (st)
  (nth 6 st))

(defund extract-async-adder-result-value (st)
  (strip-cars (nth 7 st)))

(defun async-adder$result-empty-n (inputs-lst st n)
  (declare (xargs :measure (acl2-count n)))
  (if (zp n)
      t
    (and (emptyp (extract-async-adder-result-status st))
         (async-adder$result-empty-n
          (cdr inputs-lst)
          (async-adder$state-fn (car inputs-lst) st)
          (1- n)))))

(defthm open-async-adder$result-empty-n
  (and
   (implies (zp n)
            (equal (async-adder$result-empty-n inputs-lst st n)
                   t))
   (implies (not (zp n))
            (equal (async-adder$result-empty-n inputs-lst st n)
                   (and (emptyp (extract-async-adder-result-status st))
                        (async-adder$result-empty-n
                         (cdr inputs-lst)
                         (async-adder$state-fn (car inputs-lst) st)
                         (1- n)))))))

(defthm async-adder$result-emptyp-m+n
  (implies (and (natp m)
                (natp n))
           (equal (async-adder$result-empty-n inputs-lst st (+ m n))
                  (and (async-adder$result-empty-n inputs-lst st m)
                       (async-adder$result-empty-n
                        (nthcdr m inputs-lst)
                        (async-adder$state-fn-n inputs-lst st m)
                        n))))
  :hints (("Goal"
           :induct (async-adder$result-empty-n inputs-lst st m))))

(defthm async-adder$result-empty-n-lemma
  (implies (and (async-adder$result-empty-n inputs-lst st n)
                (natp m)
                (natp n)
                (< m n))
           (emptyp (extract-async-adder-result-status
                    (async-adder$state-fn-n inputs-lst st m))))
  :hints (("Goal"
           :in-theory (enable async-adder$state-fn-n))))

(in-theory (disable async-adder$result-empty-n))

(defthm consp-fv-shift-right
  (implies (consp a)
           (consp (fv-shift-right a si)))
  :hints (("Goal" :in-theory (enable fv-shift-right)))
  :rule-classes :type-prescription)

;; This function produces two lemmas:

;; (1) The emptyness property of the result register's status.

;; (2) The state of the async serial adder is preserved after running it a
;; certain number of DE steps (Note that the number of DE steps to be executed
;; is varied due to different interleavings of GO signals). We prove that this
;; property holds for all possible interleavings of GO signals specified in
;; *ASYNC-ADDER-INTERLEAVINGS*.

(defun async-adder-invariant-gen (n)
  (declare (xargs :guard (natp n)))
  (b* ((st '((bit-add-st (list l-a a l-b b l-ci ci l-s s l-co co))
             (serial-add-st (list l-reg0 reg0 l-reg1 reg1 l-reg2 reg2
                                bit-add-st))
             (st (list l-cntl cntl l-next-cntl next-cntl l-done- done-
                       l-result result
                       serial-add-st))))
       (hyps
        '((async-adder$inv-st st)))
       (concl1
        '(async-adder$result-empty-n inputs-lst st n))
       (concl2
        '(equal
          (async-adder$state-fn-n inputs-lst st n)
          (list '((nil))
                next-cntl
                '((t))
                (pairlis$ (next-cntl-state (strip-cars next-cntl))
                          nil)
                '((t))
                (list (compute-done- (strip-cars next-cntl)))
                '((nil))
                (pairlis$ (v-threefix (strip-cars result))
                          nil)
                (list '((t))
                      (list (fv-shift-right (car reg0) nil))
                      '((t))
                      (list (fv-shift-right (car reg1) nil))
                      '((nil))
                      (list (fv-shift-right (car reg2)
                                            (f-xor3 (car ci)
                                                    (car (car reg0))
                                                    (car (car reg1)))))
                      (list '((nil))
                            (list (f-buf (car (car reg0))))
                            '((nil))
                            (list (f-buf (car (car reg1))))
                            '((t))
                            (list (f-or (f-and (car (car reg0))
                                               (car (car reg1)))
                                        (f-and (f-xor (car (car reg0))
                                                      (car (car reg1)))
                                               (car ci))))
                            '((nil))
                            (list (f-xor3 (car ci)
                                          (car (car reg0))
                                          (car (car reg1))))
                            '((nil))
                            (list (f-or (f-and (car (car reg0))
                                               (car (car reg1)))
                                        (f-and (f-xor (car (car reg0))
                                                      (car (car reg1)))
                                               (car ci)))))))
          )))
    (if (zp n)
        `((defthmd async-adder$invalid-result
            (b* ,st
              (implies
               (and ,@hyps
                    (async-adder$st-trans inputs-lst)
                    (equal n (async-adder$st-trans->numsteps inputs-lst))
                    (async-adder$input-format-n inputs-lst n))
               ,concl1))
            :hints (("Goal"
                     :in-theory (e/d* (async-adder$st-trans
                                       async-adder$st-trans->numsteps)
                                      (open-async-adder$result-empty-n
                                       fullp emptyp posp
                                       open-async-adder$input-format-n)))))
          
          (defthmd async-adder$state-invariant
            (b* ,st
              (implies
               (and ,@hyps
                    (async-adder$st-trans inputs-lst)
                    (equal n (async-adder$st-trans->numsteps inputs-lst))
                    (async-adder$input-format-n inputs-lst n))
               ,concl2))
            :hints (("Goal"
                     :in-theory (e/d* (async-adder$st-trans
                                       async-adder$st-trans->numsteps)
                                      (open-async-adder$state-fn-n
                                       fullp emptyp
                                       open-async-adder$input-format-n)))))
          )
    
      (b* ((lemma-name-1 (intern$ (concatenate
                                   'string
                                   "ASYNC-ADDER$INVALID-RESULT-"
                                   (str::natstr (1- n)))
                                  "ADE"))
           (lemma-name-2 (intern$ (concatenate
                                   'string
                                   "ASYNC-ADDER$STATE-INVARIANT-"
                                   (str::natstr (1- n)))
                                  "ADE"))
           (st-trans (intern$ (concatenate
                               'string
                               "ASYNC-ADDER$ST-TRANS-"
                               (str::natstr (1- n)))
                              "ADE"))
           (st-trans->numsteps (intern$ (concatenate
                                         'string
                                         "*ASYNC-ADDER$ST-TRANS-"
                                         (str::natstr (1- n))
                                         "->NUMSTEPS*")
                                        "ADE")))

        (append
         `((local
            (defthm ,lemma-name-1
              (b* ,st
                (implies
                 (and ,@hyps
                      (,st-trans inputs-lst)
                      (equal n ,st-trans->numsteps)
                      (async-adder$input-format-n inputs-lst n))
                 ,concl1))
              :hints (("Goal"
                       :do-not-induct t
                       :in-theory (e/d* (extract-async-adder-result-status
                                         async-adder$st-trans-rules
                                         async-adder$input-format
                                         async-adder$go-signals
                                         async-adder$state
                                         async-adder$state-fn
                                         serial-adder$state-fn
                                         serial-adder$ready-out
                                         serial-adder$ready-in-
                                         1-bit-adder$state-fn
                                         1-bit-adder$ready-out
                                         1-bit-adder$empty-a-
                                         1-bit-adder$empty-b-
                                         async-adder$inv-st)
                                        (nth
                                         nthcdr
                                         take-redefinition
                                         open-v-threefix
                                         car-cdr-elim))))))

           (local
            (defthm ,lemma-name-2
              (b* ,st
                (implies
                 (and ,@hyps
                      (,st-trans inputs-lst)
                      (equal n ,st-trans->numsteps)
                      (async-adder$input-format-n inputs-lst n))
                 ,concl2))
              :hints (("Goal"
                       :do-not '(preprocess)
                       :do-not-induct t
                       :in-theory (e/d* (async-adder$st-trans-rules
                                         async-adder$input-format
                                         async-adder$go-signals
                                         async-adder$state
                                         async-adder$state-fn
                                         serial-adder$state-fn
                                         serial-adder$ready-out
                                         serial-adder$ready-in-
                                         1-bit-adder$state-fn
                                         1-bit-adder$ready-out
                                         1-bit-adder$empty-a-
                                         1-bit-adder$empty-b-
                                         write-shift-reg
                                         async-adder$inv-st)
                                        (nth
                                         nthcdr
                                         take-redefinition
                                         open-v-threefix
                                         car-cdr-elim)))))))

         (async-adder-invariant-gen (1- n)))))))

(make-event
 `(encapsulate
    ()
    ,@(async-adder-invariant-gen
       (len *async-adder-interleavings*))))

(defund last-round-st (st)
  (b* ((l-cntl (nth 0 st))
       (cntl (nth 1 st))
       (l-next-cntl (nth 2 st))
       (next-cntl (nth 3 st))
       (l-done- (nth 4 st))
       (done- (nth 5 st))
       (l-result (nth 6 st))
       (result (nth 7 st))
       (serial-add-st (nth 8 st))
       
       (l-reg0 (nth 0 serial-add-st))
       (reg0 (nth 1 serial-add-st))
       (l-reg1 (nth 2 serial-add-st))
       (reg1 (nth 3 serial-add-st))
       (l-reg2 (nth 4 serial-add-st))
       (reg2 (nth 5 serial-add-st))
       (bit-add-st (nth 6 serial-add-st))
       
       (l-a (nth 0 bit-add-st))
       (?a (nth 1 bit-add-st))
       (l-b (nth 2 bit-add-st))
       (?b (nth 3 bit-add-st))
       (l-ci (nth 4 bit-add-st))
       (?ci (nth 5 bit-add-st))
       (l-s (nth 6 bit-add-st))
       (?s (nth 7 bit-add-st))
       (l-co (nth 8 bit-add-st))
       (?co (nth 9 bit-add-st)))
    
    (and (emptyp l-cntl)
         (len-1-true-listp cntl)
         (equal (len cntl) 5)
         (bvp (strip-cars cntl))
          
         (fullp l-next-cntl)
         (len-1-true-listp next-cntl)
         (equal (len next-cntl) 5)
         (bvp (strip-cars next-cntl))

         (fullp l-done-)
         (equal (car done-) nil) ;; Done

         (emptyp l-result)
         (true-listp result)
         (equal (len result) 33)
                  
         (fullp l-reg0)
         (equal (len (car reg0)) 32)
         (fullp l-reg1)
         (equal (len (car reg1)) 32)
         (emptyp l-reg2)
         (true-listp (car reg2))
         (equal (len (car reg2)) 32)
          
         (emptyp l-a)
         (emptyp l-b)
         (fullp l-ci)
         (emptyp l-s)
         (emptyp l-co))))

(defconst *async-adder-last-round-interleavings*
  (prepend-rec (interleave '(async-adder$go-a) '(async-adder$go-b))
               '(async-adder$go-add
                 async-adder$go-carry
                 async-adder$go-s
                 async-adder$go-result)))

(defconst *async-adder-last-round-independ-lst*
  '((async-adder$go-a async-adder$go-b)))

(make-event `,(st-trans-fn 'async-adder-last-round
                           *async-adder-last-round-interleavings*
                           *async-adder-last-round-independ-lst*))

;; This function produces two lemmas:

;; (1) The emptyness property of the result register's status in the last
;; iteration.

;; (2) The state of the async serial adder after running it the last iteration,
;; i.e., DONE- signal is NIL (enabled). This lemma holds for all possible
;; interleavings of GO signals specified in
;; *ASYNC-ADDER-LAST-ROUND-INTERLEAVINGS*.

(defun async-adder-last-round-gen (n)
  (declare (xargs :guard (natp n)))
  (b* ((st '((bit-add-st (list l-a a l-b b l-ci ci l-s s l-co co))
             (serial-add-st (list l-reg0 reg0 l-reg1 reg1 l-reg2 reg2
                                bit-add-st))
             (st (list l-cntl cntl l-next-cntl next-cntl l-done- done-
                       l-result result
                       serial-add-st))))
       (hyps
        '((last-round-st st)))
       (concl1
        '(async-adder$result-empty-n inputs-lst st n))
       (concl2
        '(equal
          (async-adder$state-fn-n inputs-lst st n)
          (list '((nil))
                cntl
                '((t))
                next-cntl
                '((nil))
                '(nil) ;; Done
                '((t))
                (pairlis$
                 (append (fv-shift-right (car reg2)
                                         (f-xor3 (car ci)
                                                 (car (car reg0))
                                                 (car (car reg1))))
                         (list (f-or (f-and (car (car reg0))
                                            (car (car reg1)))
                                     (f-and (f-xor (car (car reg0))
                                                   (car (car reg1)))
                                            (car ci)))))
                 nil)
                (list '((nil))
                      (list (car reg0))
                      '((nil))
                      (list (car reg1))
                      '((nil))
                      (list (fv-shift-right (car reg2)
                                            (f-xor3 (car ci)
                                                    (car (car reg0))
                                                    (car (car reg1)))))
                      (list '((nil))
                            (list (f-buf (car (car reg0))))
                            '((nil))
                            (list (f-buf (car (car reg1))))
                            '((nil))
                            (list (f-or (f-and (car (car reg0))
                                               (car (car reg1)))
                                        (f-and (f-xor (car (car reg0))
                                                      (car (car reg1)))
                                               (car ci))))
                            '((nil))
                            (list (f-xor3 (car ci)
                                          (car (car reg0))
                                          (car (car reg1))))
                            '((nil))
                            (list (f-or (f-and (car (car reg0))
                                               (car (car reg1)))
                                        (f-and (f-xor (car (car reg0))
                                                      (car (car reg1)))
                                               (car ci)))))))
          )))
    (if (zp n)
        `((defthmd async-adder-last-round$invalid-result
            (b* ,st
              (implies
               (and ,@hyps
                    (async-adder-last-round$st-trans inputs-lst)
                    (equal n (async-adder-last-round$st-trans->numsteps
                              inputs-lst))
                    (async-adder$input-format-n inputs-lst n))
               ,concl1))
            :hints (("Goal"
                     :in-theory (e/d* (async-adder-last-round$st-trans
                                       async-adder-last-round$st-trans->numsteps)
                                      (open-async-adder$result-empty-n
                                       fullp emptyp posp
                                       open-async-adder$input-format-n)))))

          (defthmd async-adder-last-round$sim
            (b* ,st
              (implies
               (and ,@hyps
                    (async-adder-last-round$st-trans inputs-lst)
                    (equal n (async-adder-last-round$st-trans->numsteps
                              inputs-lst))
                    (async-adder$input-format-n inputs-lst n))
               ,concl2))
            :hints (("Goal"
                     :in-theory (e/d* (async-adder-last-round$st-trans
                                       async-adder-last-round$st-trans->numsteps)
                                      (open-async-adder$state-fn-n
                                       fullp emptyp
                                       open-async-adder$input-format-n)))))
          )
    
      (b* ((lemma-name-1
            (intern$ (concatenate
                      'string
                      "ASYNC-ADDER-LAST-ROUND$INVALID-RESULT-"
                      (str::natstr (1- n)))
                     "ADE"))
           (lemma-name-2 (intern$ (concatenate
                                   'string
                                   "ASYNC-ADDER-LAST-ROUND$SIM-"
                                   (str::natstr (1- n)))
                                  "ADE"))
           (st-trans (intern$ (concatenate
                               'string
                               "ASYNC-ADDER-LAST-ROUND$ST-TRANS-"
                               (str::natstr (1- n)))
                              "ADE"))
           (st-trans->numsteps (intern$ (concatenate
                                         'string
                                         "*ASYNC-ADDER-LAST-ROUND$ST-TRANS-"
                                         (str::natstr (1- n))
                                         "->NUMSTEPS*")
                                        "ADE")))

        (append
         `((local
            (defthm ,lemma-name-1
              (b* ,st
                (implies
                 (and ,@hyps
                      (,st-trans inputs-lst)
                      (equal n ,st-trans->numsteps)
                      (async-adder$input-format-n inputs-lst n))
                 ,concl1))
              :hints (("Goal"
                       :do-not-induct t
                       :in-theory (e/d* (extract-async-adder-result-status
                                         async-adder-last-round$st-trans-rules
                                         async-adder$input-format
                                         async-adder$go-signals
                                         async-adder$state
                                         async-adder$state-fn
                                         serial-adder$state-fn
                                         serial-adder$ready-out
                                         serial-adder$ready-in-
                                         1-bit-adder$state-fn
                                         1-bit-adder$ready-out
                                         1-bit-adder$empty-a-
                                         1-bit-adder$empty-b-
                                         last-round-st
                                         v-threefix-append)
                                        (nth
                                         nthcdr
                                         take-redefinition
                                         append-v-threefix
                                         car-cdr-elim))))))

           (local
            (defthm ,lemma-name-2
              (b* ,st
                (implies
                 (and ,@hyps
                      (,st-trans inputs-lst)
                      (equal n ,st-trans->numsteps)
                      (async-adder$input-format-n inputs-lst n))
                 ,concl2))
              :hints (("Goal"
                       :do-not '(preprocess)
                       :do-not-induct t
                       :in-theory (e/d* (async-adder-last-round$st-trans-rules
                                         async-adder$input-format
                                         async-adder$go-signals
                                         async-adder$state
                                         async-adder$state-fn
                                         serial-adder$state-fn
                                         serial-adder$ready-out
                                         serial-adder$ready-in-
                                         1-bit-adder$state-fn
                                         1-bit-adder$ready-out
                                         1-bit-adder$empty-a-
                                         1-bit-adder$empty-b-
                                         write-shift-reg
                                         last-round-st
                                         v-threefix-append)
                                        (nth
                                         nthcdr
                                         take-redefinition
                                         append-v-threefix
                                         car-cdr-elim)))))))

         (async-adder-last-round-gen (1- n)))))))

(make-event
 `(encapsulate
    ()
    ,@(async-adder-last-round-gen
       (len *async-adder-last-round-interleavings*))))

(local
 (defthmd async-adder$state-fixpoint-instance
   (b* ((st (list '((nil))
                  cntl
                  '((t))
                  next-cntl
                  '((nil))
                  '(nil) ;; Done
                  '((t))
                  (pairlis$
                   (append (fv-shift-right (car reg2)
                                           (f-xor3 (car ci)
                                                   (car (car reg0))
                                                   (car (car reg1))))
                           (list (f-or (f-and (car (car reg0))
                                              (car (car reg1)))
                                       (f-and (f-xor (car (car reg0))
                                                     (car (car reg1)))
                                              (car ci)))))
                   nil)
                  (list '((nil))
                        (list (car reg0))
                        '((nil))
                        (list (car reg1))
                        '((nil))
                        (list (fv-shift-right (car reg2)
                                              (f-xor3 (car ci)
                                                      (car (car reg0))
                                                      (car (car reg1)))))
                        (list '((nil))
                              (list (f-buf (car (car reg0))))
                              '((nil))
                              (list (f-buf (car (car reg1))))
                              '((nil))
                              (list (f-or (f-and (car (car reg0))
                                                 (car (car reg1)))
                                          (f-and (f-xor (car (car reg0))
                                                        (car (car reg1)))
                                                 (car ci))))
                              '((nil))
                              (list (f-xor3 (car ci)
                                            (car (car reg0))
                                            (car (car reg1))))
                              '((nil))
                              (list (f-or (f-and (car (car reg0))
                                                 (car (car reg1)))
                                          (f-and (f-xor (car (car reg0))
                                                        (car (car reg1)))
                                                 (car ci)))))))))
     (implies
      (and (async-adder$input-format inputs)
       
           (len-1-true-listp cntl)
           (equal (len cntl) 5)
           (bvp (strip-cars cntl))
           
           (len-1-true-listp next-cntl)
           (equal (len next-cntl) 5)
           (bvp (strip-cars next-cntl))
           
           (equal (len (car reg0)) 32)
           (equal (len (car reg1)) 32)
           (true-listp (car reg2))
           (equal (len (car reg2)) 32))
      (equal (async-adder$state-fn inputs st)
             st)))
   :hints (("Goal" :in-theory (e/d* (async-adder$input-format
                                     async-adder$state-fn
                                     serial-adder$state-fn
                                     1-bit-adder$state-fn
                                     1-bit-adder$ready-out
                                     write-shift-reg
                                     v-threefix-append)
                                    (append-v-threefix))))))

(defthmd async-adder$state-fixpoint
  (b* ((st (list '((nil))
                 cntl
                 '((t))
                 next-cntl
                 '((nil))
                 '(nil) ;; Done
                 '((t))
                 (pairlis$
                  (append (fv-shift-right (car reg2)
                                          (f-xor3 (car ci)
                                                  (car (car reg0))
                                                  (car (car reg1))))
                          (list (f-or (f-and (car (car reg0))
                                             (car (car reg1)))
                                      (f-and (f-xor (car (car reg0))
                                                    (car (car reg1)))
                                             (car ci)))))
                  nil)
                 (list '((nil))
                       (list (car reg0))
                       '((nil))
                       (list (car reg1))
                       '((nil))
                       (list (fv-shift-right (car reg2)
                                             (f-xor3 (car ci)
                                                     (car (car reg0))
                                                     (car (car reg1)))))
                       (list '((nil))
                             (list (f-buf (car (car reg0))))
                             '((nil))
                             (list (f-buf (car (car reg1))))
                             '((nil))
                             (list (f-or (f-and (car (car reg0))
                                                (car (car reg1)))
                                         (f-and (f-xor (car (car reg0))
                                                       (car (car reg1)))
                                                (car ci))))
                             '((nil))
                             (list (f-xor3 (car ci)
                                           (car (car reg0))
                                           (car (car reg1))))
                             '((nil))
                             (list (f-or (f-and (car (car reg0))
                                                (car (car reg1)))
                                         (f-and (f-xor (car (car reg0))
                                                       (car (car reg1)))
                                                (car ci)))))))))
    (implies
     (and (async-adder$input-format-n inputs-lst n)
          
          (len-1-true-listp cntl)
          (equal (len cntl) 5)
          (bvp (strip-cars cntl))
          
          (len-1-true-listp next-cntl)
          (equal (len next-cntl) 5)
          (bvp (strip-cars next-cntl))

          (equal (len (car reg0)) 32)
          (equal (len (car reg1)) 32)
          (true-listp (car reg2))
          (equal (len (car reg2)) 32))
     (equal (async-adder$state-fn-n inputs-lst st n)
            st)))
  :hints (("Goal"
           :in-theory (e/d (async-adder$state-fn-n
                            async-adder$input-format-n
                            async-adder$state-fixpoint-instance)
                           (car-cdr-elim)))))

(defthmd async-adder$sim-last-round-to-fixpoint
  (b* ((bit-add-st (list l-a a l-b b l-ci ci l-s s l-co co))
       (serial-add-st (list l-reg0 reg0 l-reg1 reg1 l-reg2 reg2
                         bit-add-st))
       (st (list l-cntl cntl l-next-cntl next-cntl l-done- done-
                 l-result result
                 serial-add-st)))
    (implies
     (and (async-adder-last-round$st-trans inputs-lst)
          (natp n)
          (<= (async-adder-last-round$st-trans->numsteps inputs-lst)
              n)
          (async-adder$input-format-n inputs-lst n)
          (last-round-st st))
     (equal (async-adder$state-fn-n inputs-lst st n)
            (list '((nil))
                  cntl
                  '((t))
                  next-cntl
                  '((nil))
                  '(nil) ;; Done
                  '((t))
                  (pairlis$
                   (append (fv-shift-right (car reg2)
                                           (f-xor3 (car ci)
                                                   (car (car reg0))
                                                   (car (car reg1))))
                           (list (f-or (f-and (car (car reg0))
                                              (car (car reg1)))
                                       (f-and (f-xor (car (car reg0))
                                                     (car (car reg1)))
                                              (car ci)))))
                   nil)
                  (list '((nil))
                        (list (car reg0))
                        '((nil))
                        (list (car reg1))
                        '((nil))
                        (list (fv-shift-right (car reg2)
                                              (f-xor3 (car ci)
                                                      (car (car reg0))
                                                      (car (car reg1)))))
                        (list '((nil))
                              (list (f-buf (car (car reg0))))
                              '((nil))
                              (list (f-buf (car (car reg1))))
                              '((nil))
                              (list (f-or (f-and (car (car reg0))
                                                 (car (car reg1)))
                                          (f-and (f-xor (car (car reg0))
                                                        (car (car reg1)))
                                                 (car ci))))
                              '((nil))
                              (list (f-xor3 (car ci)
                                            (car (car reg0))
                                            (car (car reg1))))
                              '((nil))
                              (list (f-or (f-and (car (car reg0))
                                                 (car (car reg1)))
                                          (f-and (f-xor (car (car reg0))
                                                        (car (car reg1)))
                                                 (car ci)))))))
            )))
  :hints (("Goal"
           :use ((:instance
                  async-adder$input-format-m+n
                  (m (async-adder-last-round$st-trans->numsteps inputs-lst))
                  (n (- n
                        (async-adder-last-round$st-trans->numsteps inputs-lst))))
                 (:instance
                  async-adder$state-fn-m+n
                  (m (async-adder-last-round$st-trans->numsteps inputs-lst))
                  (n (- n
                        (async-adder-last-round$st-trans->numsteps inputs-lst)))
                  (st (list l-cntl cntl l-next-cntl next-cntl
                            l-done- done- l-result result
                            (list l-reg0 reg0 l-reg1 reg1 l-reg2 reg2
                                  (list l-a a l-b b l-ci ci
                                        l-s s l-co co))))))
           :in-theory (e/d (async-adder-last-round$sim
                            async-adder$state-fixpoint
                            last-round-st)
                           (open-async-adder$state-fn-n
                            async-adder$input-format-m+n
                            async-adder$state-fn-m+n
                            car-cdr-elim)))))

;; ======================================================================

;; Prove the loop state-invariant of the async serial adder.

(defun fv-shift-right-nil-n (a n)
  (declare (xargs :guard (natp n)))
  (if (zp n)
      a
    (fv-shift-right-nil-n (fv-shift-right a nil)
                          (1- n))))

(defthm len-fv-shift-right-nil-n
  (equal (len (fv-shift-right-nil-n a n))
         (len a)))

(defthm open-fv-shift-right-nil-n
  (and
   (implies (zp n)
            (equal (fv-shift-right-nil-n a n)
                   a))
   (implies (not (zp n))
            (equal (fv-shift-right-nil-n a n)
                   (fv-shift-right-nil-n (fv-shift-right a nil)
                                         (1- n))))))

(in-theory (disable fv-shift-right-nil-n))

(defun fv-serial-sum (c a b n acc)
  (declare (xargs :measure (acl2-count n)
                  :guard (and (true-listp b)
                              (natp n))))
  (if (or (zp n) (atom a))
      acc
    (b* ((acc (fv-shift-right acc (f-xor3 c (car a) (car b)))))
      (fv-serial-sum (f-or (f-and (car a) (car b))
                           (f-and (f-xor (car a) (car b)) c))
                     (fv-shift-right a nil)
                     (fv-shift-right b nil)
                     (1- n)
                     acc))))

(defthm open-fv-serial-sum
  (and
   (implies (or (zp n) (atom a))
            (equal (fv-serial-sum c a b n acc)
                   acc))
   (implies (not (or (zp n) (atom a)))
            (equal (fv-serial-sum c a b n acc)
                   (b* ((acc (fv-shift-right acc
                                             (f-xor3 c (car a) (car b)))))
                     (fv-serial-sum (f-or (f-and (car a) (car b))
                                          (f-and (f-xor (car a) (car b))
                                                 c))
                                    (fv-shift-right a nil)
                                    (fv-shift-right b nil)
                                    (1- n)
                                    acc))))))

(in-theory (disable fv-serial-sum))

(defun fv-serial-carry (c a b n)
  (declare (xargs :measure (acl2-count n)
                  :guard (and (true-listp b)
                              (natp n))))
  (if (or (zp n) (atom a))
      c
    (fv-serial-carry (f-or (f-and (car a) (car b))
                           (f-and (f-xor (car a) (car b)) c))
                     (fv-shift-right a nil)
                     (fv-shift-right b nil)
                     (1- n))))

(defthm open-fv-serial-carry
  (and
   (implies (or (zp n) (atom a))
            (equal (fv-serial-carry c a b n)
                   c))
   (implies (not (or (zp n) (atom a)))
            (equal (fv-serial-carry c a b n)
                   (fv-serial-carry (f-or (f-and (car a) (car b))
                                          (f-and (f-xor (car a) (car b))
                                                 c))
                                    (fv-shift-right a nil)
                                    (fv-shift-right b nil)
                                    (1- n))))))

(in-theory (disable fv-serial-carry))

(defund fv-serial-adder (c a b n acc)
  (declare (xargs :guard (and (true-listp acc)
                              (true-listp b)
                              (natp n))))
  (append (fv-serial-sum c a b n acc)
          (list (fv-serial-carry c a b n))))

(defun next-cntl-state-n (st n)
  (declare (xargs :guard (and (true-listp st)
                              (natp n))))
  (if (zp n)
      st
    (next-cntl-state-n (next-cntl-state st)
                       (1- n))))

(defthm open-next-cntl-state-n
  (and
   (implies (zp n)
            (equal (next-cntl-state-n st n) st))
   (implies (not (zp n))
            (equal (next-cntl-state-n st n)
                   (next-cntl-state-n (next-cntl-state st)
                                      (1- n))))))

(in-theory (disable next-cntl-state-n))

(defun simulate-async-adder-loop-induct (inputs-lst st n count)
  (if (zp count)
      (list st n)
    (simulate-async-adder-loop-induct
     (nthcdr (async-adder$st-trans->numsteps inputs-lst)
             inputs-lst)
     (async-adder$state-fn-n inputs-lst
                             st
                             (async-adder$st-trans->numsteps inputs-lst))
     (- n (async-adder$st-trans->numsteps inputs-lst))
     (1- count))))

(defthmd async-adder$invalid-result-alt
  (b* ((l-cntl (nth 0 st))
       (cntl (nth 1 st))
       (l-next-cntl (nth 2 st))
       (next-cntl (nth 3 st))
       (l-done- (nth 4 st))
       (done- (nth 5 st))
       (l-result (nth 6 st))
       (result (nth 7 st))
       (serial-add-st (nth 8 st))
       
       (l-reg0 (nth 0 serial-add-st))
       (reg0 (nth 1 serial-add-st))
       (l-reg1 (nth 2 serial-add-st))
       (reg1 (nth 3 serial-add-st))
       (l-reg2 (nth 4 serial-add-st))
       (reg2 (nth 5 serial-add-st))
       (bit-add-st (nth 6 serial-add-st))
       
       (l-a (nth 0 bit-add-st))
       (a (nth 1 bit-add-st))
       (l-b (nth 2 bit-add-st))
       (b (nth 3 bit-add-st))
       (l-ci (nth 4 bit-add-st))
       (ci (nth 5 bit-add-st))
       (l-s (nth 6 bit-add-st))
       (s (nth 7 bit-add-st))
       (l-co (nth 8 bit-add-st))
       (co (nth 9 bit-add-st)))
    (implies
     (and (async-adder$st-trans inputs-lst)
          (equal n (async-adder$st-trans->numsteps inputs-lst))
          (async-adder$input-format-n inputs-lst n)
          (equal st (list l-cntl cntl l-next-cntl
                          next-cntl l-done- done- l-result result
                          (list l-reg0 reg0 l-reg1 reg1 l-reg2 reg2
                                (list l-a a l-b b l-ci ci l-s s l-co co))))
          (async-adder$inv-st st))
     (async-adder$result-empty-n inputs-lst st n)))
  :hints (("Goal"
           :in-theory (union-theories
                       '(async-adder$invalid-result)
                       (theory 'minimal-theory)))))

(defthmd async-adder$state-invariant-alt
  (b* ((l-cntl (nth 0 st))
       (cntl (nth 1 st))
       (l-next-cntl (nth 2 st))
       (next-cntl (nth 3 st))
       (l-done- (nth 4 st))
       (done- (nth 5 st))
       (l-result (nth 6 st))
       (result (nth 7 st))
       (serial-add-st (nth 8 st))
       
       (l-reg0 (nth 0 serial-add-st))
       (reg0 (nth 1 serial-add-st))
       (l-reg1 (nth 2 serial-add-st))
       (reg1 (nth 3 serial-add-st))
       (l-reg2 (nth 4 serial-add-st))
       (reg2 (nth 5 serial-add-st))
       (bit-add-st (nth 6 serial-add-st))
       
       (l-a (nth 0 bit-add-st))
       (a (nth 1 bit-add-st))
       (l-b (nth 2 bit-add-st))
       (b (nth 3 bit-add-st))
       (l-ci (nth 4 bit-add-st))
       (ci (nth 5 bit-add-st))
       (l-s (nth 6 bit-add-st))
       (s (nth 7 bit-add-st))
       (l-co (nth 8 bit-add-st))
       (co (nth 9 bit-add-st)))
    (implies
     (and (async-adder$st-trans inputs-lst)
          (equal n (async-adder$st-trans->numsteps inputs-lst))
          (async-adder$input-format-n inputs-lst n)
          (equal st (list l-cntl cntl l-next-cntl
                          next-cntl l-done- done- l-result result
                          (list l-reg0 reg0 l-reg1 reg1 l-reg2 reg2
                                (list l-a a l-b b l-ci ci l-s s l-co co))))
          (async-adder$inv-st st))
     (equal (async-adder$state-fn-n inputs-lst st n)
            (list
             '((nil))
             next-cntl '((t))
             (pairlis$ (next-cntl-state (strip-cars next-cntl))
                       nil)
             '((t))
             (list (compute-done- (strip-cars next-cntl)))
             '((nil))
             (pairlis$ (v-threefix (strip-cars result))
                       nil)
             (list '((t))
                   (list (fv-shift-right (car reg0) nil))
                   '((t))
                   (list (fv-shift-right (car reg1) nil))
                   '((nil))
                   (list (fv-shift-right (car reg2)
                                         (f-xor3 (car ci)
                                                 (car (car reg0))
                                                 (car (car reg1)))))
                   (list '((nil))
                         (list (f-buf (car (car reg0))))
                         '((nil))
                         (list (f-buf (car (car reg1))))
                         '((t))
                         (list (f-or (f-and (car (car reg0))
                                            (car (car reg1)))
                                     (f-and (f-xor (car (car reg0))
                                                   (car (car reg1)))
                                            (car ci))))
                         '((nil))
                         (list (f-xor3 (car ci)
                                       (car (car reg0))
                                       (car (car reg1))))
                         '((nil))
                         (list (f-or (f-and (car (car reg0))
                                            (car (car reg1)))
                                     (f-and (f-xor (car (car reg0))
                                                   (car (car reg1)))
                                            (car ci))))))))))
  :hints (("Goal"
           :in-theory (union-theories '(async-adder$state-invariant)
                                      (theory 'minimal-theory)))))

(local
 (defthmd pos-len=>consp
   (implies (< 0 (len x))
            (consp x))))

(encapsulate
  ()
  
  (local
   (defthm simulate-async-adder-loop-aux-1
     (implies (and (natp x)
                   (<= 30 x)
                   (posp y)
                   (< (+ x y) 32))
              (equal y 1))
     :rule-classes nil))

  (local
   (defthm simulate-async-adder-loop-aux-2
     (implies
      (and (posp count)
           (not
            (equal
             (async-adder$st-trans-n->numsteps
              (nthcdr (async-adder$st-trans->numsteps inputs-lst)
                      inputs-lst)
              (+ -1 count))
             (+ (async-adder$st-trans->numsteps
                 (nthcdr (async-adder$st-trans->numsteps inputs-lst)
                         inputs-lst))
                (async-adder$st-trans-n->numsteps
                 (nthcdr (+ (async-adder$st-trans->numsteps inputs-lst)
                            (async-adder$st-trans->numsteps
                             (nthcdr (async-adder$st-trans->numsteps
                                      inputs-lst)
                                     inputs-lst)))
                         inputs-lst)
                 (+ -2 count))))))
      (equal count 1))
     :rule-classes nil))
  
  ;; The emptyness property of the result register's status. Prove by
  ;; induction.

  (defthmd simulate-async-adder-loop-invalid-result
    (b* ((l-cntl (nth 0 st))
         (cntl (nth 1 st))
         (l-next-cntl (nth 2 st))
         (next-cntl (nth 3 st))
         (l-done- (nth 4 st))
         (done- (nth 5 st))
         (l-result (nth 6 st))
         (result (nth 7 st))
         (serial-add-st (nth 8 st))
      
         (l-reg0 (nth 0 serial-add-st))
         (reg0 (nth 1 serial-add-st))
         (l-reg1 (nth 2 serial-add-st))
         (reg1 (nth 3 serial-add-st))
         (l-reg2 (nth 4 serial-add-st))
         (reg2 (nth 5 serial-add-st))
         (bit-add-st (nth 6 serial-add-st))
      
         (l-a (nth 0 bit-add-st))
         (a (nth 1 bit-add-st))
         (l-b (nth 2 bit-add-st))
         (b (nth 3 bit-add-st))
         (l-ci (nth 4 bit-add-st))
         (ci (nth 5 bit-add-st))
         (l-s (nth 6 bit-add-st))
         (s (nth 7 bit-add-st))
         (l-co (nth 8 bit-add-st))
         (co (nth 9 bit-add-st)))
      (implies
       (and (posp count)
            (< (+ (v-to-nat (strip-cars next-cntl))
                  count)
               32)
            (async-adder$st-trans-n inputs-lst count)
            (equal n (async-adder$st-trans-n->numsteps inputs-lst count))
            (async-adder$input-format-n inputs-lst n)
            (equal st (list l-cntl cntl l-next-cntl
                            next-cntl l-done- done- l-result result
                            (list l-reg0 reg0 l-reg1 reg1 l-reg2 reg2
                                  (list l-a a l-b b l-ci ci l-s s l-co co))))
            (async-adder$inv-st st))
       (async-adder$result-empty-n inputs-lst st n)))
    :hints (("Goal"
             :induct
             (simulate-async-adder-loop-induct inputs-lst st n count)
             :in-theory (e/d (async-adder$invalid-result-alt
                              async-adder$state-invariant-alt
                              async-adder$inv-st
                              async-adder$st-trans-n)
                             (open-async-adder$input-format-n
                              open-async-adder$result-empty-n
                              open-async-adder$state-fn-n
                              open-async-adder$st-trans-n
                              open-v-threefix
                              fullp
                              emptyp
                              nth
                              nthcdr
                              car-cdr-elim
                              (:type-prescription bvp-cvzbv)
                              true-listp
                              bvp-is-true-listp
                              fv-shift-right=v-shift-right
                              f-gates=b-gates
                              strip-cars)))
            ("Subgoal *1/2"
             :use (simulate-async-adder-loop-aux-2
                   (:instance simulate-async-adder-loop-aux-1
                              (x (v-to-nat (strip-cars (nth 3 st))))
                              (y count)))
             )))

  ;; The loop state-invariant of the async serial adder. Prove by induction.

  (defthmd simulate-async-adder-loop
    (b* ((l-cntl (nth 0 st))
         (cntl (nth 1 st))
         (l-next-cntl (nth 2 st))
         (next-cntl (nth 3 st))
         (l-done- (nth 4 st))
         (done- (nth 5 st))
         (l-result (nth 6 st))
         (result (nth 7 st))
         (serial-add-st (nth 8 st))
      
         (l-reg0 (nth 0 serial-add-st))
         (reg0 (nth 1 serial-add-st))
         (l-reg1 (nth 2 serial-add-st))
         (reg1 (nth 3 serial-add-st))
         (l-reg2 (nth 4 serial-add-st))
         (reg2 (nth 5 serial-add-st))
         (bit-add-st (nth 6 serial-add-st))
      
         (l-a (nth 0 bit-add-st))
         (a (nth 1 bit-add-st))
         (l-b (nth 2 bit-add-st))
         (b (nth 3 bit-add-st))
         (l-ci (nth 4 bit-add-st))
         (ci (nth 5 bit-add-st))
         (l-s (nth 6 bit-add-st))
         (s (nth 7 bit-add-st))
         (l-co (nth 8 bit-add-st))
         (co (nth 9 bit-add-st)))
      (implies
       (and (posp count)
            (< (+ (v-to-nat (strip-cars next-cntl))
                  count)
               32)
            (async-adder$st-trans-n inputs-lst count)
            (equal n (async-adder$st-trans-n->numsteps inputs-lst count))
            (async-adder$input-format-n inputs-lst n)
            (equal st (list l-cntl cntl l-next-cntl
                            next-cntl l-done- done- l-result result
                            (list l-reg0 reg0 l-reg1 reg1 l-reg2 reg2
                                  (list l-a a l-b b l-ci ci l-s s l-co co))))
            (async-adder$inv-st st))
       (equal
        (async-adder$state-fn-n inputs-lst st n)
        (list
         '((nil))
         (pairlis$ (next-cntl-state-n (strip-cars next-cntl)
                                      (1- count))
                   nil)
         '((t))
         (pairlis$ (next-cntl-state-n (strip-cars next-cntl)
                                      count)
                   nil)
         '((t))
         (list (compute-done- (next-cntl-state-n (strip-cars next-cntl)
                                                 (1- count))))
         '((nil))
         (pairlis$ (v-threefix (strip-cars result))
                   nil)
         (list '((t))
               (list (fv-shift-right-nil-n (car reg0) count))
               '((t))
               (list (fv-shift-right-nil-n (car reg1) count))
               '((nil))
               (list
                (fv-serial-sum (car ci) (car reg0) (car reg1)
                               count
                               (car reg2)))
               (list '((nil))
                     (list (f-buf (car (fv-shift-right-nil-n
                                        (car reg0)
                                        (1- count)))))
                     '((nil))
                     (list (f-buf (car (fv-shift-right-nil-n
                                        (car reg1)
                                        (1- count)))))
                     '((t))
                     (list (fv-serial-carry (car ci)
                                            (car reg0)
                                            (car reg1)
                                            count))
                     '((nil))
                     (list (f-xor3 (fv-serial-carry (car ci)
                                                    (car reg0)
                                                    (car reg1)
                                                    (1- count))
                                   (car (fv-shift-right-nil-n
                                         (car reg0)
                                         (1- count)))
                                   (car (fv-shift-right-nil-n
                                         (car reg1)
                                         (1- count)))))
                     '((nil))
                     (list (fv-serial-carry (car ci)
                                            (car reg0)
                                            (car reg1)
                                            count))))))))
    :hints (("Goal"
             :induct
             (simulate-async-adder-loop-induct inputs-lst st n count)
             :in-theory (e/d (async-adder$state-invariant-alt
                              async-adder$inv-st
                              pos-len=>consp
                              async-adder$st-trans-n
                              next-cntl-state-n)
                             (open-async-adder$input-format-n
                              open-async-adder$st-trans-n
                              open-v-threefix
                              fullp
                              emptyp
                              nth
                              nthcdr
                              car-cdr-elim
                              (:type-prescription bvp-cvzbv)
                              true-listp
                              bvp-is-true-listp
                              fv-shift-right=v-shift-right
                              f-gates=b-gates
                              strip-cars)))
            ("Subgoal *1/2"
             :use (:instance simulate-async-adder-loop-aux-1
                             (x (v-to-nat (strip-cars (nth 3 st))))
                             (y count)))))
  )

(encapsulate
  ()

  (local
   (defthm 3vp-of-car-v-threefix
     (3vp (car (v-threefix x)))
     :hints (("Goal" :in-theory (enable 3vp v-threefix)))))

  (defthm f-buf-of-car-fv-shift-right-canceled
    (equal (f-buf (car (fv-shift-right a si)))
           (car (fv-shift-right a si)))
    :hints (("Goal" :in-theory (enable fv-shift-right))))

  (defthm f-buf-of-car-fv-shift-right-nil-n-canceled
    (implies (posp n)
             (equal (f-buf (car (fv-shift-right-nil-n a n)))
                    (car (fv-shift-right-nil-n a n))))
    :hints (("Goal" :in-theory (enable fv-shift-right-nil-n
                                       fv-shift-right)))))

(defun async-adder$init-st (st)
  (b* ((l-cntl (nth 0 st))
       (cntl (nth 1 st))
       (l-next-cntl (nth 2 st))
       (next-cntl (nth 3 st))
       (l-done- (nth 4 st))
       (done- (nth 5 st))
       (l-result (nth 6 st))
       (result (nth 7 st))
       (serial-add-st (nth 8 st))
                           
       (l-reg0 (nth 0 serial-add-st))
       (reg0 (nth 1 serial-add-st))
       (l-reg1 (nth 2 serial-add-st))
       (reg1 (nth 3 serial-add-st))
       (l-reg2 (nth 4 serial-add-st))
       (reg2 (nth 5 serial-add-st))
       (bit-add-st (nth 6 serial-add-st))
                           
       (l-a (nth 0 bit-add-st))
       (?a (nth 1 bit-add-st))
       (l-b (nth 2 bit-add-st))
       (?b (nth 3 bit-add-st))
       (l-ci (nth 4 bit-add-st))
       (?ci (nth 5 bit-add-st))
       (l-s (nth 6 bit-add-st))
       (?s (nth 7 bit-add-st))
       (l-co (nth 8 bit-add-st))
       (?co (nth 9 bit-add-st)))
    
    (and (emptyp l-cntl)
         (len-1-true-listp cntl)
         (equal (len cntl) 5)
          
         (fullp l-next-cntl)
         (equal next-cntl '((nil) (nil) (nil) (nil) (nil)))

         (fullp l-done-)
         (equal (car done-) t)

         (emptyp l-result)
         (true-listp result)
         (equal (len result) 33)
                  
         (fullp l-reg0)
         (equal (len (car reg0)) 32)
         (fullp l-reg1)
         (equal (len (car reg1)) 32)
         (emptyp l-reg2)
         (true-listp (car reg2))
         (equal (len (car reg2)) 32)
          
         (emptyp l-a)
         (emptyp l-b)
         (fullp l-ci)
         (emptyp l-s)
         (emptyp l-co))))

(defthmd async-adder$init-st=>inv-st
  (implies (async-adder$init-st st)
           (async-adder$inv-st st))
  :hints (("Goal" :in-theory (enable async-adder$inv-st))))

(in-theory (disable async-adder$init-st))

(local
 (defthmd open-nth-3-async-adder-st
   (b* ((bit-add-st (list l-a a l-b b l-ci ci l-s s l-co co))
        (serial-add-st (list l-reg0 reg0 l-reg1 reg1 l-reg2 reg2
                           bit-add-st))
        (st (list l-cntl cntl l-next-cntl next-cntl l-done- done-
                  l-result result
                  serial-add-st)))
     (equal (nth 3 st) next-cntl))))

(defthmd simulate-async-adder-loop-invalid-result-instance
  (b* ((l-cntl (nth 0 st))
       (cntl (nth 1 st))
       (l-next-cntl (nth 2 st))
       (next-cntl (nth 3 st))
       (l-done- (nth 4 st))
       (done- (nth 5 st))
       (l-result (nth 6 st))
       (result (nth 7 st))
       (serial-add-st (nth 8 st))
      
       (l-reg0 (nth 0 serial-add-st))
       (reg0 (nth 1 serial-add-st))
       (l-reg1 (nth 2 serial-add-st))
       (reg1 (nth 3 serial-add-st))
       (l-reg2 (nth 4 serial-add-st))
       (reg2 (nth 5 serial-add-st))
       (bit-add-st (nth 6 serial-add-st))
      
       (l-a (nth 0 bit-add-st))
       (a (nth 1 bit-add-st))
       (l-b (nth 2 bit-add-st))
       (b (nth 3 bit-add-st))
       (l-ci (nth 4 bit-add-st))
       (ci (nth 5 bit-add-st))
       (l-s (nth 6 bit-add-st))
       (s (nth 7 bit-add-st))
       (l-co (nth 8 bit-add-st))
       (co (nth 9 bit-add-st)))
    (implies
     (and (equal count 31)
          (async-adder$st-trans-n inputs-lst count)
          (equal n (async-adder$st-trans-n->numsteps inputs-lst count))
          (async-adder$input-format-n inputs-lst n)
          (equal st (list l-cntl cntl l-next-cntl
                          next-cntl l-done- done- l-result result
                          (list l-reg0 reg0 l-reg1 reg1 l-reg2 reg2
                                (list l-a a l-b b l-ci ci l-s s l-co co))))
          (async-adder$init-st st))
     (async-adder$result-empty-n inputs-lst st n)))
  :hints (("Goal"
           :do-not-induct t
           :use simulate-async-adder-loop-invalid-result
           :in-theory (union-theories
                       '(async-adder$init-st
                         async-adder$init-st=>inv-st
                         open-nth-3-async-adder-st
                         posp
                         v-to-nat
                         len-1-true-listp
                         len-1-listp
                         len
                         bvp
                         true-list-listp
                         booleanp
                         strip-cars)
                       (theory 'minimal-theory)))))

(defthmd simulate-async-adder-loop-instance
  (b* ((l-cntl (nth 0 st))
       (cntl (nth 1 st))
       (l-next-cntl (nth 2 st))
       (next-cntl (nth 3 st))
       (l-done- (nth 4 st))
       (done- (nth 5 st))
       (l-result (nth 6 st))
       (result (nth 7 st))
       (serial-add-st (nth 8 st))
      
       (l-reg0 (nth 0 serial-add-st))
       (reg0 (nth 1 serial-add-st))
       (l-reg1 (nth 2 serial-add-st))
       (reg1 (nth 3 serial-add-st))
       (l-reg2 (nth 4 serial-add-st))
       (reg2 (nth 5 serial-add-st))
       (bit-add-st (nth 6 serial-add-st))
      
       (l-a (nth 0 bit-add-st))
       (a (nth 1 bit-add-st))
       (l-b (nth 2 bit-add-st))
       (b (nth 3 bit-add-st))
       (l-ci (nth 4 bit-add-st))
       (ci (nth 5 bit-add-st))
       (l-s (nth 6 bit-add-st))
       (s (nth 7 bit-add-st))
       (l-co (nth 8 bit-add-st))
       (co (nth 9 bit-add-st)))
    (implies
     (and (equal count 31)
          (async-adder$st-trans-n inputs-lst count)
          (equal n (async-adder$st-trans-n->numsteps inputs-lst count))
          (async-adder$input-format-n inputs-lst n)
          (equal st (list l-cntl cntl l-next-cntl
                          next-cntl l-done- done- l-result result
                          (list l-reg0 reg0 l-reg1 reg1 l-reg2 reg2
                                (list l-a a l-b b l-ci ci l-s s l-co co))))
          (async-adder$init-st st))
     (equal (async-adder$state-fn-n inputs-lst st n)
            (list
             '((nil))
             '((nil) (t) (t) (t) (t))
             '((t))
             '((nil) (nil) (nil) (nil) (nil))
             '((t))
             '(nil) ;; Done
             '((nil))
             (pairlis$ (v-threefix (strip-cars result))
                       nil)
             (list '((t))
                   (list (fv-shift-right-nil-n (car reg0) count))
                   '((t))
                   (list (fv-shift-right-nil-n (car reg1) count))
                   '((nil))
                   (list
                    (fv-serial-sum (car ci) (car reg0) (car reg1)
                                   count
                                   (car reg2)))
                   (list '((nil))
                         (list (car (fv-shift-right-nil-n
                                     (car reg0)
                                     (1- count))))
                         '((nil))
                         (list (car (fv-shift-right-nil-n
                                     (car reg1)
                                     (1- count))))
                         '((t))
                         (list (fv-serial-carry (car ci)
                                                (car reg0)
                                                (car reg1)
                                                count))
                         '((nil))
                         (list (f-xor3 (fv-serial-carry (car ci)
                                                        (car reg0)
                                                        (car reg1)
                                                        (1- count))
                                       (car (fv-shift-right-nil-n
                                             (car reg0)
                                             (1- count)))
                                       (car (fv-shift-right-nil-n
                                             (car reg1)
                                             (1- count)))))
                         '((nil))
                         (list (fv-serial-carry (car ci)
                                                (car reg0)
                                                (car reg1)
                                                count))))))))
  :hints (("Goal"
           :do-not-induct t
           :use simulate-async-adder-loop
           :in-theory (union-theories
                       '(async-adder$init-st
                         async-adder$init-st=>inv-st
                         open-nth-3-async-adder-st
                         v-to-nat
                         compute-done-
                         len-1-true-listp
                         len-1-listp
                         len
                         bvp
                         posp
                         true-list-listp
                         booleanp
                         pairlis$
                         strip-cars
                         (f-nand4)
                         (next-cntl-state-n)
                         f-buf-of-car-fv-shift-right-nil-n-canceled)
                       (theory 'minimal-theory)))))

;; ======================================================================

;; Prove that the state of the async serial adder will eventually reach a fixed
;; point. We show that the result register stays empty until the fixed point is
;; reached. At that fixed point, the result register becomes full and its value
;; complies with the serial adder spec.

(defthm consp-fv-serial-sum
  (implies (consp acc)
           (consp (fv-serial-sum c a b n acc)))
  :hints (("Goal" :in-theory (enable fv-serial-sum)))
  :rule-classes :type-prescription)

(defthm true-listp-fv-serial-sum
  (implies (true-listp acc)
           (true-listp (fv-serial-sum c a b n acc)))
  :hints (("Goal" :in-theory (enable fv-serial-sum)))
  :rule-classes :type-prescription)

(defthm len-fv-serial-sum
  (equal (len (fv-serial-sum c a b n acc))
         (len acc))
  :hints (("Goal" :in-theory (enable fv-serial-sum))))

(defthm fv-serial-sum-simplified
  (implies (and (natp n)
                (consp a))
           (equal (fv-shift-right (fv-serial-sum c a b n acc)
                                  (f-xor3 (fv-serial-carry c a b n)
                                          (car (fv-shift-right-nil-n a n))
                                          (car (fv-shift-right-nil-n b n))))
                  (fv-serial-sum c a b (1+ n) acc)))
  :hints (("Goal"
           :in-theory (enable fv-serial-sum
                              fv-serial-carry
                              fv-shift-right-nil-n))))

(defthm f-buf-of-fv-serial-carry-canceled
  (implies (and (posp n)
                (consp a))
           (equal (f-buf (fv-serial-carry c a b n))
                  (fv-serial-carry c a b n)))
  :hints (("Goal" :in-theory (enable f-buf fv-serial-carry))))

(defthm fv-serial-carry-simplified
  (implies (and (natp n)
                (consp a))
           (equal (f-or (f-and (car (fv-shift-right-nil-n a n))
                               (car (fv-shift-right-nil-n b n)))
                        (f-and (f-xor (car (fv-shift-right-nil-n a n))
                                      (car (fv-shift-right-nil-n b n)))
                               (fv-serial-carry c a b n)))
                  (fv-serial-carry c a b (1+ n))))
  :hints (("Goal"
           :in-theory (enable fv-serial-carry
                              fv-shift-right-nil-n))))

(defund async-adder-interleavings (inputs-lst operand-size)
  (declare (xargs :guard (and (true-list-listp inputs-lst)
                              (posp operand-size))))
  (b* ((inv-steps (async-adder$st-trans-n->numsteps inputs-lst
                                                    (1- operand-size)))
       (remained-inputs-lst (nthcdr inv-steps inputs-lst)))
    (and (async-adder$st-trans-n inputs-lst (1- operand-size))
         (async-adder-last-round$st-trans remained-inputs-lst))))

(defund async-adder-numsteps (inputs-lst operand-size)
  (declare (xargs :guard (and (true-list-listp inputs-lst)
                              (posp operand-size))))
  (b* ((inv-steps (async-adder$st-trans-n->numsteps inputs-lst
                                                    (1- operand-size)))
       (remained-inputs-lst (nthcdr inv-steps inputs-lst)))
    (+ inv-steps
       (async-adder-last-round$st-trans->numsteps remained-inputs-lst))))

(defthmd simulate-async-adder-invalid-result
  (b* ((bit-add-st (list l-a a l-b b l-ci ci l-s s l-co co))
       (serial-add-st (list l-reg0 reg0 l-reg1 reg1 l-reg2 reg2
                          bit-add-st))
       (st (list l-cntl cntl l-next-cntl next-cntl l-done- done-
                 l-result result
                 serial-add-st)))
    (implies
     (and (equal operand-size 32)
          (async-adder-interleavings inputs-lst operand-size)
          (equal n (async-adder-numsteps inputs-lst operand-size))
          (async-adder$input-format-n inputs-lst n)
          (async-adder$init-st st))
     (async-adder$result-empty-n inputs-lst st n)))
  :hints (("Goal"
           :do-not-induct t
           :use ((:instance
                  async-adder$result-emptyp-m+n
                  (m (async-adder$st-trans-n->numsteps
                      inputs-lst
                      (1- operand-size)))
                  (n (- n (async-adder$st-trans-n->numsteps
                           inputs-lst
                           (1- operand-size))))
                  (st (list l-cntl cntl l-next-cntl next-cntl l-done- done-
                            l-result result
                            (list l-reg0 reg0
                                  l-reg1 reg1
                                  l-reg2 reg2
                                  (list l-a a
                                        l-b b
                                        l-ci ci
                                        l-s s
                                        l-co co)))))
                 (:instance
                  async-adder$input-format-m+n
                  (m (async-adder$st-trans-n->numsteps
                      inputs-lst
                      (1- operand-size)))
                  (n (- n (async-adder$st-trans-n->numsteps
                           inputs-lst
                           (1- operand-size))))))
           :in-theory (e/d (simulate-async-adder-loop-invalid-result-instance
                            simulate-async-adder-loop-instance
                            async-adder-last-round$invalid-result
                            async-adder-interleavings
                            async-adder-numsteps
                            async-adder$init-st
                            last-round-st)
                           (async-adder$result-emptyp-m+n
                            async-adder$input-format-m+n
                            open-async-adder$result-empty-n
                            open-async-adder$input-format-n
                            open-async-adder$st-trans-n
                            open-async-adder$st-trans-n->numsteps
                            open-fv-shift-right-nil-n
                            open-fv-serial-sum
                            open-fv-serial-carry
                            open-v-threefix
                            fullp
                            emptyp
                            car-cdr-elim)))))

(defthmd simulate-async-adder-to-fixpoint
  (b* ((bit-add-st (list l-a a l-b b l-ci ci l-s s l-co co))
       (serial-add-st (list l-reg0 reg0 l-reg1 reg1 l-reg2 reg2
                          bit-add-st))
       (st (list l-cntl cntl l-next-cntl next-cntl l-done- done-
                 l-result result
                 serial-add-st)))
    (implies
     (and (equal operand-size 32)
          (async-adder-interleavings inputs-lst operand-size)
          (natp n)
          (>= n (async-adder-numsteps inputs-lst operand-size))
          (async-adder$input-format-n inputs-lst n)
          (async-adder$init-st st))
     (equal (async-adder$state-fn-n inputs-lst st n)
            (list
             '((nil))
             '((nil) (t) (t) (t) (t))
             '((t))
             '((nil) (nil) (nil) (nil) (nil))
             '((nil))
             '(nil) ;; Done
             '((t))
             ;; Final result
             (pairlis$
              (fv-serial-adder (car ci) (car reg0) (car reg1)
                               operand-size
                               (car reg2))
              nil)
             (list '((nil))
                   (list (fv-shift-right-nil-n (car reg0)
                                               (1- operand-size)))
                   '((nil))
                   (list (fv-shift-right-nil-n (car reg1)
                                               (1- operand-size)))
                   '((nil))
                   (list
                    (fv-serial-sum (car ci) (car reg0) (car reg1)
                                   operand-size
                                   (car reg2)))
                   (list '((nil))
                         (list (car (fv-shift-right-nil-n
                                     (car reg0)
                                     (1- operand-size))))
                         '((nil))
                         (list (car (fv-shift-right-nil-n
                                     (car reg1)
                                     (1- operand-size))))
                         '((nil))
                         ;; Carry
                         (list (fv-serial-carry (car ci)
                                                (car reg0)
                                                (car reg1)
                                                operand-size))
                         '((nil))
                         (list (f-xor3 (fv-serial-carry (car ci)
                                                        (car reg0)
                                                        (car reg1)
                                                        (1- operand-size))
                                       (car (fv-shift-right-nil-n
                                             (car reg0)
                                             (1- operand-size)))
                                       (car (fv-shift-right-nil-n
                                             (car reg1)
                                             (1- operand-size)))))
                         '((nil))
                         (list (fv-serial-carry (car ci)
                                                (car reg0)
                                                (car reg1)
                                                operand-size))))))))
  :hints (("Goal"
           :do-not-induct t
           :use ((:instance
                  async-adder$state-fn-m+n
                  (m (async-adder$st-trans-n->numsteps
                      inputs-lst
                      (1- operand-size)))
                  (n (- n (async-adder$st-trans-n->numsteps
                           inputs-lst
                           (1- operand-size))))
                  (st (list l-cntl cntl l-next-cntl next-cntl l-done- done-
                            l-result result
                            (list l-reg0 reg0
                                  l-reg1 reg1
                                  l-reg2 reg2
                                  (list l-a a
                                        l-b b
                                        l-ci ci
                                        l-s s
                                        l-co co)))))
                 (:instance
                  async-adder$input-format-m+n
                  (m (async-adder$st-trans-n->numsteps
                      inputs-lst
                      (1- operand-size)))
                  (n (- n (async-adder$st-trans-n->numsteps
                           inputs-lst
                           (1- operand-size))))))
           :in-theory (e/d (simulate-async-adder-loop-instance
                            async-adder$sim-last-round-to-fixpoint
                            async-adder$init-st
                            last-round-st
                            async-adder-interleavings
                            async-adder-numsteps
                            fv-serial-adder
                            pos-len=>consp)
                           (async-adder$state-fn-m+n
                            async-adder$input-format-m+n
                            open-async-adder$state-fn-n
                            open-async-adder$input-format-n
                            open-async-adder$st-trans-n
                            open-async-adder$st-trans-n->numsteps
                            open-fv-shift-right-nil-n
                            open-fv-serial-sum
                            open-fv-serial-carry
                            open-v-threefix
                            fullp
                            emptyp
                            car-cdr-elim)))))

;; ======================================================================

;; Prove (using GL) that the serial adder produces the same result with the
;; ripple-carry adder.

(defthm v-to-nat-upper-bound
  (< (v-to-nat x)
     (expt 2 (len x)))
  :hints (("Goal" :in-theory (enable v-to-nat)))
  :rule-classes :linear)

(encapsulate
  ()

  (local (include-book "arithmetic-5/top" :dir :system))

  (defthm nat-to-v-of-v-to-nat
    (implies (and (bvp x)
                  (equal (len x) n))
             (equal (nat-to-v (v-to-nat x) n)
                    x))
    :hints (("Goal" :in-theory (enable bvp
                                       nat-to-v
                                       v-to-nat)))))

(encapsulate
  ()

  (local
   (def-gl-thm fv-serial-adder=fv-adder-32-aux
     :hyp (and (booleanp c)
               (natp a)
               (natp b)
               (natp acc)
               (< a (expt 2 32))
               (< b (expt 2 32))
               (< acc (expt 2 32)))
     :concl (equal (fv-serial-adder c (nat-to-v a 32) (nat-to-v b 32)
                                   32
                                   (nat-to-v acc 32))
                   (fv-adder c (nat-to-v a 32) (nat-to-v b 32)))
     :g-bindings `((c (:g-boolean . 0))
                   (a ,(gl::g-int 1 2 33))
                   (b ,(gl::g-int 2 2 33))
                   (acc ,(gl::g-int 67 1 33)))))

  (local
   (defthm v-to-nat-upper-bound-instance
     (implies (equal (len x) 32)
              (< (v-to-nat x) 4294967296))
     :hints (("Goal" :use v-to-nat-upper-bound))
     :rule-classes :linear))

  (defthm fv-serial-adder=fv-adder-32
    (implies (and (equal n 32)
                  (booleanp c)
                  (bvp a)
                  (equal (len a) n)
                  (bvp b)
                  (equal (len b) n)
                  (bvp acc)
                  (equal (len acc) n))
             (equal (fv-serial-adder c a b n acc)
                    (fv-adder c a b)))
    :hints (("Goal"
             :use (:instance fv-serial-adder=fv-adder-32-aux
                             (a (v-to-nat a))
                             (b (v-to-nat b))
                             (acc (v-to-nat acc))))))
  )

;; Prove that the async serial adder indeed performs the addition.

(defthmd async-adder$input-format-n-lemma
 (implies (and (async-adder$input-format-n inputs-lst n)
               (natp n)
               (<= m n))
          (async-adder$input-format-n inputs-lst m))
 :hints (("Goal" :in-theory (enable async-adder$input-format-n))))

(defthmd async-adder$empty-result
 (b* ((bit-add-st (list l-a a l-b b l-ci ci l-s s l-co co))
      (serial-add-st (list l-reg0 reg0 l-reg1 reg1 l-reg2 reg2
                           bit-add-st))
      (st (list l-cntl cntl l-next-cntl next-cntl l-done- done-
                l-result result
                serial-add-st)))
   (implies
    (and (async-adder& netlist)
         (equal operand-size 32)
         (async-adder-interleavings inputs-lst operand-size)
         (natp m)
         (< m n)
         (equal n (async-adder-numsteps inputs-lst operand-size))
         (async-adder$input-format-n inputs-lst n)
         (async-adder$init-st st))
    (b* ((final-st (de-sim-n 'async-adder inputs-lst st netlist m)))
      (emptyp (extract-async-adder-result-status final-st)))))
 :hints (("Goal"
          :use (:instance
                async-adder$result-empty-n-lemma
                (st (list l-cntl cntl l-next-cntl
                          next-cntl l-done- done- l-result result
                          (list l-reg0 reg0 l-reg1 reg1 l-reg2 reg2
                                (list l-a a l-b b l-ci ci l-s s l-co co)))))
          :in-theory (e/d (de-sim-n$async-adder
                           async-adder$input-format-n-lemma
                           async-adder$init-st
                           simulate-async-adder-invalid-result)
                          (async-adder$result-empty-n-lemma
                           open-async-adder$result-empty-n
                           fullp
                           emptyp
                           open-de-sim-n
                           open-async-adder$state-fn-n
                           open-async-adder$input-format-n
                           car-cdr-elim)))))

;; Termination theorem

(defthmd async-adder$termination
  (b* ((bit-add-st (list l-a a l-b b l-ci ci l-s s l-co co))
       (serial-add-st (list l-reg0 reg0 l-reg1 reg1 l-reg2 reg2
                            bit-add-st))
       (st (list l-cntl cntl l-next-cntl next-cntl l-done- done-
                 l-result result
                 serial-add-st)))
    (implies
     (and (async-adder& netlist)
          (equal operand-size 32)
          (async-adder-interleavings inputs-lst operand-size)
          (natp n)
          (>= n (async-adder-numsteps inputs-lst operand-size))
          (async-adder$input-format-n inputs-lst n)
          (async-adder$init-st st))
     (b* ((final-st (de-sim-n 'async-adder inputs-lst st netlist n)))
       (and
        (fullp (extract-async-adder-result-status final-st)) ;; Terminate
        (implies (and (bvp (car reg0))
                      (bvp (car reg1))
                      (bvp (car reg2))
                      (booleanp (car ci)))
                 (equal (v-to-nat
                         (extract-async-adder-result-value final-st))
                        (+ (bool->bit (car ci))
                           (v-to-nat (car reg0))
                           (v-to-nat (car reg1)))))))))
  :hints (("Goal"
           :do-not-induct t
           :in-theory (e/d (de-sim-n$async-adder
                            simulate-async-adder-to-fixpoint
                            extract-async-adder-result-status
                            extract-async-adder-result-value
                            async-adder$init-st)
                           (fullp
                            emptyp
                            open-de-sim-n
                            open-async-adder$state-fn-n
                            open-async-adder$input-format-n
                            open-fv-shift-right-nil-n
                            open-fv-serial-sum
                            open-fv-serial-carry
                            car-cdr-elim)))))

(encapsulate
  ()
  
  (local
   (defthm empty=>not-full
     (implies (emptyp x)
              (not (fullp x)))))

  ;; Partial correctness theorem

  (defthmd async-adder$partial-correct
    (b* ((bit-add-st (list l-a a l-b b l-ci ci l-s s l-co co))
         (serial-add-st (list l-reg0 reg0 l-reg1 reg1 l-reg2 reg2
                              bit-add-st))
         (st (list l-cntl cntl l-next-cntl next-cntl l-done- done-
                   l-result result
                   serial-add-st)))
      (implies
       (and (async-adder& netlist)
            (equal operand-size 32)
            (async-adder-interleavings inputs-lst operand-size)
            (natp m)
            (equal n (async-adder-numsteps inputs-lst operand-size))
            (async-adder$input-format-n inputs-lst (max m n))
            (async-adder$init-st st))
       (b* ((final-st (de-sim-n 'async-adder inputs-lst st netlist m)))
         (implies (and (fullp (extract-async-adder-result-status final-st))
                       (bvp (car reg0))
                       (bvp (car reg1))
                       (bvp (car reg2))
                       (booleanp (car ci)))
                  (equal (v-to-nat
                          (extract-async-adder-result-value final-st))
                         (+ (bool->bit (car ci))
                            (v-to-nat (car reg0))
                            (v-to-nat (car reg1))))))))
    :hints (("Goal"
             :cases ((< m n))
             :in-theory (e/d (async-adder$empty-result
                              async-adder$termination)
                             (fullp
                              emptyp
                              open-de-sim-n
                              open-async-adder$state-fn-n
                              open-async-adder$input-format-n
                              open-fv-shift-right-nil-n
                              open-fv-serial-sum
                              open-fv-serial-carry
                              car-cdr-elim))))))

