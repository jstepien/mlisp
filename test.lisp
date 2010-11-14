(defun asseq (x y)
  (assert (eq x y)))
(defun assequal (x y)
  (assert (equal x y)))
(assert 5)
(assert (quote (1 2)))
(assert "asdf")
(assert 'symbol)
(assert (not '()))
(asseq (car (cons 4 (quote (5 6)))) 4)
(asseq (cadr (cons 4 (quote (5 6)))) 5)
(asseq (caddr (cons 4 (quote (5 6)))) 6)
(asseq (cadar (quote ((1 3) 2))) 3)
(asseq (cadr (quote (foo bar))) 'bar)
(asseq (caddr (cons (quote asdf) (quote (1337 bar)))) 'bar)
(assert (atom 'a))
(assert (not (atom '(a))))
(assert (not (eq 6 3)))
(asseq 5 5)
(assert (not (eq 'a 'b)))
(asseq 'b 'b)
(assert (not (eq 'a (atom '(a)))))
(asseq (eq 4 2) (atom '(a)))
(asseq 'asdf (cond ((eq 4 2) (car '(foo)))
                   ((atom 'x) (car '(asdf)))))
(asseq 'ok (cond ((eq 4 2) 'foobar)
                 ('true 'ok)))
(assequal '(a b) ((lambda (x) (cons x '(b))) 'a))
(assert (not (equal '(a c) ((lambda (x) (cons x '(b))) 'a))))
(asseq 'it-is-an-atom ((lambda (x)
                         (cond
                           ((atom x) 'it-is-an-atom)
                           ('t 'it-is-not-an-atom)))
                       'it-looks-like-an-atom))
(asseq 'second ((lambda (a b) (cond (a b))) 'first 'second))
(assequal '(second first)
          ((lambda (x y) (cons y (cons x '()))) 'first 'second))
(asseq 'thats-better (cond
                       ('() 'true-is-false)
                       ((atom '()) 'thats-better)
                       ('t 'foobar)))
(defun double (a) (cons a (cons a '())))
(assequal '(b b) (double 'b))
(defun transpose (a b) (cons b (cons a '())))
(assequal '(y x) (transpose 'x 'y))
(assequal '((y x) (y x)) (double (transpose 'x 'y)))
(assequal '((x) (1 2 3)) (list (list 'x) (list 1 2 3)))
(assequal '((a z) () ())
          (list (and 1 '(a z)) (and 'foo '()) (and '() '())))
(assequal '(() () t ())
          (list (null 'a) (null 4) (null '()) (null (quote (3 4 1)))))
(assequal '(() () t ())
          (list (not 'a) (not 4) (not '()) (not (quote (3 4 1)))))
(assequal '(1 2 3 a b c) (append '(1 2 3) '(a b c)))
(defun zip (a b)
  (cond ((or (null a) (null b)) '())
        ('t (cons (list (car a) (car b)) (zip (cdr a) (cdr b))))))
(assequal '(2 b) (assoc 2 (zip '(1 2 3 2) '(a b c d))))
(assequal "o hai" (car '("o hai")))
(assequal '(foo "foo") (list 'foo "foo"))
(assert (> 7 6))
(assert (and (>= 7 6) (>= 7 7)))
(asseq 'true (or '() 'true))
(asseq 'true (or 'true 'also-true))
(defun fact (x)
  (cond
    ((> x 1) (* x (fact (- x 1))))
    ('t 1)))
(assequal '(120 1 1) (list (fact 5) (fact 0) (fact 1)))
(assequal 2 (/ 16 8))
(assequal 8 (+ 5 3))
(assequal 15 (* 5 3))
(assequal 7 (- 11 4))
(assequal 105 (* 3 5 7))
(assequal 20 (+ 5 9 2 4))
(assequal 10 (- 20 4 5 1))
(assequal 7 (/ 105 5 3))
