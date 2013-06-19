; XDOC Documentation System for ACL2
; Copyright (C) 2009-2011 Centaur Technology
;
; Contact:
;   Centaur Technology Formal Verification Group
;   7600-C N. Capital of Texas Highway, Suite 300, Austin, TX 78731, USA.
;   http://www.centtech.com/
;
; This program is free software; you can redistribute it and/or modify it under
; the terms of the GNU General Public License as published by the Free Software
; Foundation; either version 2 of the License, or (at your option) any later
; version.  This program is distributed in the hope that it will be useful but
; WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
; FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
; more details.  You should have received a copy of the GNU General Public
; License along with this program; if not, write to the Free Software
; Foundation, Inc., 51 Franklin Street, Suite 500, Boston, MA 02110-1335, USA.
;
; Original author: Jared Davis <jared@centtech.com>

; base.lisp -- This file is only intended mainly to avoid a circular dependence
; between top.lisp and topics.lisp.  Ordinary users should include top.lisp
; instead.

(in-package "XDOC")

#!ACL2
(defmacro lnfix (x)
  "Logical NFIX"
  ;; BOZO this very much doesn't belong here, but I want it everywhere.
  `(mbe :logic (nfix ,x) :exec ,x))

#!ACL2
(defmacro lifix (x)
  "Logical IFIX"
  ;; BOZO this very much doesn't belong here, but I want it everywhere.
  `(mbe :logic (ifix ,x) :exec ,x))


(make-event
 `(defconst *xdoc-dir* ,(cbd)))

(table xdoc 'doc nil)

(defun get-xdoc-table (world)
  (declare (xargs :mode :program))
  (cdr (assoc-eq 'doc (table-alist 'xdoc world))))

(defun guard-for-defxdoc (name parents short long)
  (declare (xargs :guard t))
  (and (or (symbolp name)
           (cw "name is not a symbol!~%"))
       (or (symbol-listp parents)
           (cw ":parents are not a symbol list~%"))
       (or (not short)
           (stringp short)
           (cw ":short is not a string (or nil)~%"))
       (or (not long)
           (stringp long)
           (cw ":long is not a string (or nil)~%"))))

(defmacro defxdoc (name &key parents short long)
  (declare (xargs :guard (guard-for-defxdoc name parents short long)))
  `(make-event
    (let* ((pkg   (acl2::f-get-global 'current-package state))
           (entry (list (cons :name ',name)
                        (cons :base-pkg (acl2::pkg-witness pkg))
                        (cons :parents ',parents)
                        (cons :short ',short)
                        (cons :long ',long))))
     `(table xdoc 'doc
             (cons ',entry (get-xdoc-table world))))))

(defun defxdoc-raw-fn (name parents short long)
  (declare (xargs :guard t)
           (ignore name parents short long))
  (er hard? 'defxdoc-raw-fn
      "Under-the-hood definition of defxdoc-raw-fn not installed.  You ~
       probably need to load the defxdoc-raw book."))

(defmacro defxdoc-raw (name &key parents short long)
  (declare (xargs :guard (guard-for-defxdoc name parents short long)))
  `(defxdoc-raw-fn ',name ',parents ',short ',long))

(defun find-topic (name x)
  (declare (xargs :mode :program))

; Look up a particular topic by name in the list of topics.

  (if (atom x)
      nil
    (if (equal (cdr (assoc :name (car x))) name)
        (car x)
      (find-topic name (cdr x)))))