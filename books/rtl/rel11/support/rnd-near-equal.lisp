(in-package "RTL")

(include-book "../rel9-rtl-pkg/lib/util")

(include-book "../rel9-rtl-pkg/lib/top")

(local (include-book "arithmetic-5/top" :dir :system))

;; The following lemmas from arithmetic-5 have given me trouble:

(local-in-theory #!acl2(disable |(mod (+ x y) z) where (<= 0 z)| |(mod (+ x (- (mod a b))) y)| |(mod (mod x y) z)| |(mod (+ x (mod a b)) y)|
                    simplify-products-gather-exponents-equal mod-cancel-*-const cancel-mod-+ reduce-additive-constant-<
                    |(floor x 2)| |(equal x (if a b c))| |(equal (if a b c) x)|))

(local-defthm rle-1
  (implies (and (rationalp x)
                (rationalp y)
                (natp n)
                (common-rounding-mode-p mode)
                (> n 0)
                (> x 0)
                (< y x))
           (<= (rnd y mode n) (rnd x mode n)))
  :rule-classes ()
  :hints (("Goal" :use ((:instance rnd-monotone (x y) (y x))))))

(local-defthm rle-2
  (implies (and (rationalp x)
                (rationalp y)
                (natp n)
                (> n 0)
                (> x 0)
                (not (exactp x (1+ n)))
                (< (trunc x n) y)
                (< y x))
           (<= (trunc x n) (trunc y n)))
  :rule-classes ()
  :hints (("Goal" :use (trunc-exactp-a
                        (:instance trunc-exactp-c (a (trunc x n)) (x y))))))

(local-defthm rle-3
  (implies (and (rationalp x)
                (rationalp y)
                (natp n)
                (> n 0)
                (> x 0)
                (not (exactp x (1+ n)))
                (< (trunc x n) y)
                (< y x))
           (<= (minf x n) (minf y n)))
  :rule-classes ()
  :hints (("Goal" :in-theory (enable minf)
                  :use (trunc-exactp-a
                        (:instance trunc-exactp-c (a (trunc x n)) (x y))))))

(local-defthm rle-4
  (implies (and (rationalp x)
                (rationalp y)
                (natp n)
                (> n 0)
                (> x 0)
                (not (exactp x (1+ n)))
                (< (trunc x n) y)
                (< y x))
           (and (< y (fp+ (trunc x n) n))
                (= (away x n) (fp+ (trunc x n) n))))
  :rule-classes ()
  :hints (("Goal" :in-theory (enable fp+ away-away)
                  :use (trunc-away
                        (:instance away-lower-pos (n (1+ n)))
                        (:instance away-lower-pos (x (away x (1+ n))))
                        (:instance exactp-<= (m n) (n (1+ n)))))))

(local-defthm rle-5
  (implies (and (rationalp x)
                (rationalp y)
                (natp n)
                (> n 0)
                (> x 0)
                (not (exactp x (1+ n)))
                (< (trunc x n) y)
                (< y x))
           (= (away x n) (away y n)))
  :rule-classes ()
  :hints (("Goal" :use (rle-4 trunc-exactp-a
                        (:instance away-monotone (x y) (y x))
                        (:instance away-lower-pos (x y))
                        (:instance away-exactp-a (x y))
                        (:instance fp+2 (y (away y n)) (x (trunc x n)))))))

(local-defthm rle-6
  (implies (and (rationalp x)
                (rationalp y)
                (natp n)
                (> n 0)
                (> x 0)
                (not (exactp x (1+ n)))
                (< (trunc x n) y)
                (< y x))
           (= (inf x n) (inf y n)))
  :rule-classes ()
  :hints (("Goal" :use (rle-5)
                  :in-theory (enable inf))))

(local-defthm rle-7
  (implies (and (rationalp x)
                (rationalp y)
                (natp n)
                (> n 0)
                (> x 0)
                (not (exactp x (1+ n)))
                (< (trunc x n) y)
                (< y x))
           (and (< y (fp+ (trunc x (1+ n)) (1+ n)))
                (= (away x (1+ n)) (fp+ (trunc x (1+ n)) (1+ n)))))
  :rule-classes ()
  :hints (("Goal" :in-theory (enable fp+ away-away)
                  :use ((:instance trunc-away (n (1+ n)))
                        (:instance away-lower-pos (n (1+ n)))
                        (:instance away-lower-pos (x (away x (1+ n))))))))

(local-defthm rle-8
  (implies (and (rationalp x)
                (natp n)
                (> n 0)
                (> x 0))
           (<= (trunc x n) (trunc x (1+ n))))
  :rule-classes ()
  :hints (("Goal" :in-theory (enable trunc-trunc)
                  :use ((:instance trunc-upper-pos (x (trunc x (1+ n))))))))

(local-defthm rle-9
  (implies (and (rationalp x)
                (rationalp y)
                (natp n)
                (> n 0)
                (> x 0)
                (not (exactp x (1+ n)))
                (< (trunc x (1+ n)) y)
                (< y x))
           (<= (near x n) (near y n)))
  :rule-classes ()
  :hints (("Goal" :use (rle-7 rle-8
                        (:instance away-lower-pos (n (1+ n)))
                        (:instance near-near (y x) (x y) (k n) (a (trunc x (1+ n))))
                        (:instance trunc-exactp-a (n (1+ n)))))))

(local-defthm rle-10
  (implies (and (rationalp x)
                (rationalp y)
                (natp n)
                (> n 0)
                (> x 0)
                (not (exactp x (1+ n)))
                (< (trunc x (1+ n)) y)
                (< y x)
                ;; (:instance near+-near+ (y x) (x y) (k n) (a (trunc x (1+ n))))
                (implies (and (rationalp x)
		              (rationalp y)
		              (rationalp (trunc x (1+ n)))
	                      (integerp n)
		              (> n 0)
		              (< 0 (trunc x (1+ n)))
		              (< (trunc x (1+ n)) y)
		              (< 0 x)
		              (< x (fp+ (trunc x (1+ n)) (1+ n)))
		              (exactp (trunc x (1+ n)) (1+ n)))
	                 (<= (near+ x n) (near+ y n))))
           (<= (near+ x n) (near+ y n)))
  :rule-classes ()
  :hints (("Goal" :in-theory (enable common-rounding-mode-p)
                  :use (rle-7 rle-8
                        (:instance away-lower-pos (n (1+ n)))
                        (:instance trunc-exactp-a (n (1+ n)))))))

(defthm rnd<equal
  (implies (and (rationalp x)
                (rationalp y)
                (common-rounding-mode-p mode)
                (natp n)
                (> n 0)
                (> x 0)
                (not (exactp x (1+ n)))
                (< (trunc x (1+ n)) y)
                (< y x)
                ;; (:instance near+-near+ (y x) (x y) (k n) (a (trunc x (1+ n))))
                (implies (and (rationalp (trunc x (1+ n)))
                              (< 0 y)
		              (< 0 (trunc x (1+ n)))
		              (< (trunc x (1+ n)) y)
		              (< x (fp+ (trunc x (1+ n)) (1+ n)))
		              (exactp (trunc x (1+ n)) (1+ n)))
	                 (<= (near+ x n) (near+ y n))))
           (= (rnd x mode n) (rnd y mode n)))
  :rule-classes ()
  :hints (("Goal" :in-theory (e/d (rnd ieee-mode-p common-rounding-mode-p) (near-monotone near+-monotone))
                  :use (rle-1 rle-2 rle-3 rle-5 rle-6 rle-8 rle-9 rle-10))))

(local-defthm rge-1
  (implies (and (rationalp x)
                (rationalp y)
                (natp n)
                (common-rounding-mode-p mode)
                (> n 0)
                (> x 0)
                (> y x))
           (>= (rnd y mode n) (rnd x mode n)))
  :rule-classes ()
  :hints (("Goal" :use (rnd-monotone))))

(local-defthm rge-2
  (implies (and (rationalp x)
                (rationalp y)
                (natp n)
                (> n 0)
                (> x 0)
                (not (exactp x (1+ n)))
                (< y (away x (1+ n)))
                (< x y))
           (< y (away x n)))
  :rule-classes ()
  :hints (("Goal" :in-theory (enable away-away)
                  :use (away-lower-pos
                        (:instance away-lower-pos (x (away x (1+ n))))))))

(local-defthm rge-3
  (implies (and (rationalp x)
                (rationalp y)
                (natp n)
                (> n 0)
                (> x 0)
                (not (exactp x (1+ n)))
                (< y (away x (1+ n)))
                (< x y))
           (= (away x n) (fp+ (trunc x n) n)))
  :rule-classes ()
  :hints (("Goal" :in-theory (enable away-away)
                  :use (trunc-away
                        (:instance exactp-<= (m n) (n (1+ n)))))))

(local-defthm rge-4
  (implies (and (rationalp x)
                (rationalp y)
                (natp n)
                (> n 0)
                (> x 0)
                (not (exactp x (1+ n)))
                (< y (away x (1+ n)))
                (< x y))
           (<= (trunc y n) (trunc x n)))
  :rule-classes ()
  :hints (("Goal" :in-theory (enable away-away)
                  :use (rge-2 rge-3 trunc-exactp-a
                        (:instance trunc-upper-pos (x y))
                        (:instance trunc-exactp-a (x y))
                        (:instance fp+2 (x (trunc x n)) (y (trunc y n)))))))

(local-defthm rge-5
  (implies (and (rationalp x)
                (rationalp y)
                (natp n)
                (> n 0)
                (> x 0)
                (not (exactp x (1+ n)))
                (< y (away x (1+ n)))
                (< x y))
           (<= (away y n) (away x n)))
  :rule-classes ()
  :hints (("Goal" :use (rge-2 trunc-exactp-a
                        (:instance away-exactp-c (x y) (a (away x n)))))))

(local-defthm rge-6
  (implies (and (rationalp x)
                (rationalp y)
                (natp n)
                (> n 0)
                (> x 0)
                (not (exactp x (1+ n)))
                (< y (away x (1+ n)))
                (< x y))
           (<= (near y n) (near x n)))
  :rule-classes ()
  :hints (("Goal" :use (rge-2 trunc-upper-pos
                        (:instance trunc-upper-pos (n (1+ n)))
                        (:instance near-near (k n) (a (trunc x (1+ n))))
                        (:instance trunc-exactp-a (n (1+ n)))
                        (:instance trunc-away (n (1+ n)))
                        (:instance exactp-<= (m n) (n (1+ n)))))))

(local-defthm rge-7
  (implies (and (rationalp x)
                (rationalp y)
                (natp n)
                (> n 0)
                (> x 0)
                (not (exactp x (1+ n)))
                (< y (away x (1+ n)))
                (< x y)
                (implies (and (rationalp x)
		              (rationalp y)
                              (< 0 y)
		              (rationalp (trunc x (1+ n)))
		              (integerp n)
		              (< 0 (trunc x (1+ n)))
		              (< (trunc x (1+ n)) x)
		              (< 0 y)
		              (< y (fp+ (trunc x (1+ n)) (1+ n)))
		              (exactp (trunc x (1+ n)) (1+ n)))
	                 (<= (near+ y n) (near+ x n))))
           (<= (near+ y n) (near+ x n)))
  :rule-classes ()
  :hints (("Goal" :use (rge-2 trunc-upper-pos
                        (:instance trunc-upper-pos (n (1+ n)))
                        (:instance trunc-exactp-a (n (1+ n)))
                        (:instance trunc-away (n (1+ n)))
                        (:instance exactp-<= (m n) (n (1+ n)))))))

(defthm rnd>equal
  (implies (and (rationalp x)
                (rationalp y)
                (common-rounding-mode-p mode)
                (natp n)
                (> n 0)
                (> x 0)
                (not (exactp x (1+ n)))
                (< y (away x (1+ n)))
                (< x y)
                ;; (:instance near+-near+ (k n) (a (trunc x (1+ n))))
                (implies (and (rationalp (trunc x (1+ n)))
                              (< 0 y)
		              (< 0 (trunc x (1+ n)))
		              (< (trunc x (1+ n)) x)
		              (< y (fp+ (trunc x (1+ n)) (1+ n)))
		              (exactp (trunc x (1+ n)) (1+ n)))
	                 (<= (near+ y n) (near+ x n))))
           (= (rnd x mode n) (rnd y mode n)))
  :rule-classes ()
  :hints (("Goal" :in-theory (e/d (rnd inf minf ieee-mode-p common-rounding-mode-p) (near-monotone near+-monotone))
                  :use (rge-1 rge-4 rge-5 rge-6 rge-7))))


(defthm rnd-near-equal
  (implies (and (rationalp x)
                (rationalp y)
                (natp n)
                (common-rounding-mode-p mode)
                (> n 0)
                (> x 0)
                (not (exactp x (1+ n)))
                ;; (:instance near+-near+ (y x) (x y) (k n) (a (trunc x (1+ n))))
                (implies (and (rationalp (trunc x (1+ n)))
                              (< 0 y)
		              (< 0 (trunc x (1+ n)))
		              (< (trunc x (1+ n)) y)
		              (< x (fp+ (trunc x (1+ n)) (1+ n)))
		              (exactp (trunc x (1+ n)) (1+ n)))
	                 (<= (near+ x n) (near+ y n)))
                ;; (:instance near+-near+ (k n) (a (trunc x (1+ n))))
                (implies (and (rationalp (trunc x (1+ n)))
                              (< 0 y)
		              (< 0 (trunc x (1+ n)))
		              (< (trunc x (1+ n)) x)
		              (< y (fp+ (trunc x (1+ n)) (1+ n)))
		              (exactp (trunc x (1+ n)) (1+ n)))
	                 (<= (near+ y n) (near+ x n))))
           (let ((d (min (- x (trunc x (1+ n))) (- (away x (1+ n)) x))))
             (and (> d 0)
                  (implies (< (abs (- x y)) d)
                           (= (rnd y mode n) (rnd x mode n))))))
  :rule-classes ()
  :hints (("Goal" :use (rnd<equal rnd>equal
                        (:instance trunc-upper-pos (n (1+ n)))
                        (:instance away-lower-pos (n (1+ n)))
                        (:instance trunc-exactp-b (n (1+ n)))
                        (:instance away-exactp-b (n (1+ n)))))))
