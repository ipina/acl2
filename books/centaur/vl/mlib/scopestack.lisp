; VL Verilog Toolkit
; Copyright (C) 2008-2011 Centaur Technology
;
; Contact:
;   Centaur Technology Formal Verification Group
;   7600-C N. Capital of Texas Highway, Suite 300, Austin, TX 78731, USA.
;   http://www.centtech.com/
;
; License: (An MIT/X11-style license)
;
;   Permission is hereby granted, free of charge, to any person obtaining a
;   copy of this software and associated documentation files (the "Software"),
;   to deal in the Software without restriction, including without limitation
;   the rights to use, copy, modify, merge, publish, distribute, sublicense,
;   and/or sell copies of the Software, and to permit persons to whom the
;   Software is furnished to do so, subject to the following conditions:
;
;   The above copyright notice and this permission notice shall be included in
;   all copies or substantial portions of the Software.
;
;   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
;   FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
;   DEALINGS IN THE SOFTWARE.
;
; Original authors: Jared Davis <jared@centtech.com>
;                   Sol Swords <sswords@centtech.com>

(in-package "VL")
(include-book "blocks")
(include-book "find")
(local (include-book "tools/templates" :dir :system))
(local (include-book "std/lists/acl2-count" :dir :system))
(local (in-theory (disable acl2-count)))
(local (std::add-default-post-define-hook :fix))

(defxdoc scopestack
  :parents (mlib)
  :short "Scopestacks deal with namespaces in SystemVerilog by tracking the
bindings of names in scopes.  They provide a straightforward, correct way to
look up identifiers."

  :long "<h3>Namespaces in SystemVerilog</h3>

<p>SystemVerilog has a complicated system of namespaces, but it mostly boils
down to a few categories of names for things:</p>

<ul>

<li><b>items,</b> (our name), including nets/variables, parameters,
instances (of modules, gates, UDPs, and interfaces), typedefs, functions,
tasks, and named generate blocks;</li>

<li><b>definitions,</b> including module, UDP, interface, and program
declarations;</li>

<li><b>ports</b>;</li>

<li>and <b>packages</b>.</li>

</ul>

<p>The items are the most complicated.  Packages occur only at the global
scope.  Ports only occur in modules and interfaces.  In principle the
SystemVerilog spec allows for nested modules and interfaces, but most
implementations don't support this and neither do we, so definitions can only
occur at the global scope.  In contrast, to look for an item, we first look in
the most local scope; if it isn't found there, we search subsequent nested
scopes until we get to the global scope.</p>


<h3>Scopestacks</h3>

<p>A scopestack is a structure that holds representations of nested scopes.
Each scope may be one of several types, namely the types on the left-hand
column of the table @(see *vl-scopes->items*):</p>

@(`(:code (alist-keys *vl-scopes->items*))`)

<p>Whenever we search a scope, we call a @(see memoize)d function that turns
that scope representation into a fast alist, in which we look up the name.
That way, subsequent lookups in the same scope will be constant-time.  This
design means that you may occasionally need to free up memory associated with
scopestacks; see @(see vl-scopestack-free).</p>


<h5>Construction and Maintenance</h5>

<ul>
<li>@('nil') is an empty scopestack (without even the global design scope).</li>

<li>@('(vl-scopestack-init design)') creates a scopestack with only the global
scope of the design visible.</li>

<li>@('(vl-scopestack-push scope ss)') pushes a new nested scope onto the
scopestack.  Typically you will need to call this function as you \"enter\" a
new scope, e.g., as your analysis or transformation descends into a particular
module, function, etc.</li>

<li>@('(vl-scopestack-pop ss)') removes the innermost scope from the
scopestack, but this is <b>rarely needed</b> because scopestacks are
applicative.</li>

<li>@('(vl-scopestacks-free)') clears the memoization tables associated with
scopestacks, which in CCL also will allow their associated fast-alists to be
garbage collected.  We don't currently have a mechanism free these fast alists
otherwise.</li>

</ul>


<h5>Accessing Items</h5>

<p>The interface for accessing items is more complex than for definitions and
packages because items may be found in multiple scopes.</p>

<ul>

<li>@('(vl-scopestack-find-item name ss)') searches the scopestack for the
given name (a string).  The declaration of the item is returned as a @(see
vl-scopeitem).  The more specific type of the declaration, e.g., @(see
vl-vardecl), @(see vl-modinst), etc., can be determined by examining its
tag.</li>

<li>@('(vl-scopestack-find-item/ss name ss)') returns @('(mv item new-ss)'),
where item is the same as returned by @('vl-scopestack-find-item') and
@('new-ss') is the scopestack visible from that item's declaration.  For
instance, if you are deep within a bunch of nested begin/end blocks, the
@('new-ss') you get back might be for some superior block, the whole module, or
the scopestack for some entirely different package where the @('item') is
declared..</li>

<li>@('(vl-scopestack-find-item/context name ss)') returns @('(mv item ctx-ss
package)').  Here @('item') is the same as above.  The @('ctx-ss') is similar
to the @('new-ss') above <b>but</b> packages are handled differently.  In
particular, @('ctx-ss') here is always the scopestack for some superior scope
where the item was found.  If @('item') is imported from a package, then
 <ul>
    <li>@('ctx-ss') refers to, e.g., the module where the item was imported into, whereas</li>
    <li>@('new-ss') refers to the package that the item was imported from</li>
 </ul>
The separate @('package') return value is a maybe-string that gives the name
of the package where the item was imported from, if applicable.</li>

</ul>


<h5>Accessing Non-Items</h5>

<ul>

<li>@('(vl-scopestack-find-definition name ss)') is similar to -find-item, but
finds a definition instead of an item.  The @('definition/ss') and
@('definition/context') versions also exist, but aren't as informative since
the definition can (currently) only exist at the global scope.</li>

<li>@('(vl-scopestack-find-package name ss)'), similar.</li>

<li>@('(vl-scope-find-portdecl-fast name scope)') is similar, but acts only on a
scope, not a stack of them, since searching beyond the local module for a port
doesn't make much sense.</li>

</ul>")


(defsection scopestack-constants
  :parents (scopestack)
  :short "Meta-information about the kinds of scopes and the kinds of elements
they can contain."

  :long "<p>These tables are used to generate most of the scopestack code.  The
format for each entry is:</p>

@({
     (scope-name  feature-list  element-list)
})

<p>The @('feature-list') is a list of keywords that are used in the templates.</p>

<p>The @('element-list') contains information about the items.  Its entries can
be as simple as field names, or can be lists of the form @('(name [keyword
options])'), where the options account for various kinds of departures from
convention.  Current keywords:</p>

<ul>

<li>@(':name foo') denotes that the accessor for the name of the item is
@('vl-itemtype->foo'), rather than the default @('vl-itemtype->name').</li>

<li>@(':acc foo') denotes that the accessor for the items within the scope is
@('vl-scopetype->foo'), rather than the default @('vl-scopetype->items').</li>

<li>@(':maybe-stringp t') denotes that the name accessor might return @('nil'),
rather than a string.</li>

<li>@(':sum-type t') denotes that the item actually encompasses two or more
item types.</li>

<li>@(':transsum t') denotes that the item is a transparent (tag-based) sum
type.</li>

</ul>"

  (local (xdoc::set-default-parents scopestack-constants))

  (defval *vl-scopes->pkgs*
    :short "Information about which scopes can contain packages."
    :long "<p>This is kind of silly because packages can only occur at the design
level.  If for some reason we ever wanted to allow packages to be nested in
other kinds of scopes (e.g., compilation units?) we could add them here.</p>"
    '((design       ()
                    package)))

  (defval *vl-scopes->items*
    :short "Information about the kinds of items in each scope."
    :long "<p>Note that this is only for items, i.e., it's not for definitions,
  ports, packages, etc."
    '((interface    (:import)
                    paramdecl vardecl modport)
      (module       (:import)
                    paramdecl vardecl fundecl taskdecl
                    (modinst :name instname :maybe-stringp t)
                    (gateinst :maybe-stringp t)
                    (genelement :name blockname :maybe-stringp t :sum-type t :acc generates)
                    (interfaceport :acc ifports))
      (genblob      (:import)
                    vardecl paramdecl fundecl taskdecl typedef
                    (modinst :name instname :maybe-stringp t)
                    (gateinst :maybe-stringp t)
                    (genelement :name blockname :maybe-stringp t :sum-type t :acc generates)
                    (interfaceport :acc ifports))

      ;; fwdtypedefs could be included here, but we hope to have resolved them all
      ;;             to proper typedefs by the end of loading, so we omit them.

      ;; Functions, Tasks, and Statements are all grouped together into Blockscopes.
      ;; These have no imports.
      (blockscope   ()
                    (blockitem :acc decls :sum-type t :transsum t))

      (design       (:import)
                    paramdecl vardecl fundecl taskdecl typedef)
      (package      (:import)
                    paramdecl vardecl fundecl taskdecl typedef)))

  (defval *vl-scopes->defs*
    :short "Information about the kinds of definitions in each scope."
    :long "<p>This is kind of silly because we currently only support definitions
at the top level.  However, if we ever want to allow, e.g., nested modules,
then we will need to extend this.</p>"
    '((design ()
              (module :acc mods) udp interface program)))

  (defval *vl-scopes->portdecls*
    :parents (scopestack-constants)
    :short "Information about the kinds of scopes that have port declarations."
    :long "<p>BOZO do we want to add function/task ports here?</p>"
    '((interface () portdecl)
      (module    () portdecl)
      (genblob   () portdecl))))



(defprod vl-blockscope
  :short "Abstract representation of a scope that just has @(see vl-blockitem)s
in it, such as a function, task, or block statement."
  :parents (scopestack)
  :tag :vl-blockscope
  :layout :tree
  ((decls vl-blockitemlist-p)))

(define vl-fundecl->blockscope ((x vl-fundecl-p))
  :returns (scope vl-blockscope-p)
  :parents (vl-blockscope vl-scopestack-push)
  (make-vl-blockscope :decls (vl-fundecl->decls x)))

(define vl-taskdecl->blockscope ((x vl-taskdecl-p))
  :returns (scope vl-blockscope-p)
  :parents (vl-blockscope vl-scopestack-push)
  (make-vl-blockscope :decls (vl-taskdecl->decls x)))

(define vl-blockstmt->blockscope ((x vl-stmt-p))
  :guard (eq (vl-stmt-kind x) :vl-blockstmt)
  :returns (scope vl-blockscope-p)
  :parents (vl-blockscope vl-scopestack-push)
  (make-vl-blockscope :decls (vl-blockstmt->decls x)))




;; Notes on name spaces -- from SV spec 3.13
;; SV spec lists 8 namespaces:

;; a) Definitions name space:
;;      module
;;      primitive
;;      program
;;      interface
;; declarations outside all other declarations
;; (meaning: not in a package? as well as not nested.
;; Global across compilation units.

;; b) Package name space: all package IDs.  Global across compilation units.

;; c) Compilation-unit scope name space:
;;     functions
;;     tasks
;;     checkers
;;     parameters
;;     named events
;;     netdecls
;;     vardecls
;;     typedefs
;;  defined outside any other containing scope.  Local to compilation-unit
;;  scope (as the name suggests).

;; d) Text macro namespace: local to compilation unit, global within it.
;;    This works completely differently from the others; we'll ignore it here
;;    since we take care of them in the preprocessor.

;; e) Module name space:
;;     modules
;;     interfaces
;;     programs
;;     checkers
;;     functions
;;     tasks
;;     named blocks
;;     instance names
;;     parameters
;;     named events
;;     netdecls
;;     vardecls
;;     typedefs
;;  defined within the scope of a particular
;;     module
;;     interface
;;     package
;;     program
;;     checker
;;     primitive.

;; f) Block namespace:
;;     named blocks
;;     functions
;;     tasks
;;     parameters
;;     named events
;;     vardecl (? "variable type of declaration")
;;     typedefs
;;  within
;;     blocks (named or unnamed)
;;     specifys
;;     functions
;;     tasks.

;; g) Port namespace:  ports within
;;     modules
;;     interfaces
;;     primitives
;;     programs

;; h) Attribute namespace, also separate.

;; Notes on scope rules, from SV spec 23.9.

;; Elements that define new scopes:
;;     — Modules
;;     — Interfaces
;;     — Programs
;;     — Checkers
;;     — Packages
;;     — Classes
;;     — Tasks
;;     — Functions
;;     — begin-end blocks (named or unnamed)
;;     — fork-join blocks (named or unnamed)
;;     — Generate blocks

;; An identifier shall be used to declare only one item within a scope.
;; However, perhaps this doesn't apply to global/compilation-unit scope, since
;; ncverilog and vcs both allow, e.g., a module and a wire of the same name
;; declared at the top level of a file.  We can't check this inside a module
;; since neither allows nested modules, and modules aren't allowed inside
;; packages.

;; This is supposed to be true of generate blocks even if they're not
;; instantiated; as an exception, different (mutually-exclusive) blocks of a
;; conditional generate can use the same name.

;; Search for identifiers referenced (without hierarchical path) within a task,
;; function, named block, generate block -- work outward to the
;; module/interface/program/checker boundary.  Search for a variable stops at
;; this boundary; search for a task, function, named block, or generate block
;; continues to higher levels of the module(/task/function/etc) hierarchy
;; (not the lexical hierarchy!).

;; Hierarchical names

(local
 (defsection-progn template-substitution-helpers

   (defun scopes->typeinfos (scopes)
     (declare (xargs :mode :program))
     (if (atom scopes)
         nil
       (union-equal (cddar scopes)
                    (scopes->typeinfos (cdr scopes)))))

   (defun typeinfos->tmplsubsts (typeinfos)
     ;; returns a list of conses (features . strsubst-alist)
     (declare (xargs :mode :program))
     (if (atom typeinfos)
         nil
       (cons (b* ((kwds (and (consp (car typeinfos)) (cdar typeinfos)))
                  (type (if (consp (car typeinfos)) (caar typeinfos) (car typeinfos)))
                  (acc (let ((look (cadr (assoc-keyword :acc kwds))))
                         (if look
                             (symbol-name look)
                           (cat (symbol-name type) "S"))))
                  (name (let ((look (cadr (assoc-keyword :name kwds))))
                          (if look (symbol-name look) "NAME")))
                  (maybe-stringp (cadr (assoc-keyword :maybe-stringp kwds)))
                  (sum-type      (cadr (assoc-keyword :sum-type      kwds)))
                  (transsum      (cadr (assoc-keyword :transsum      kwds))))
               (make-tmplsubst :features (append (and maybe-stringp '(:maybe-stringp))
                                                 (and sum-type      '(:sum-type))
                                                 (and transsum      '(:transsum)))
                               :strs
                               `(("__TYPE__" ,(symbol-name type) . vl-package)
                                 ("__ACC__" ,acc . vl-package)
                                 ("__NAME__" ,name . vl-package))))
             (typeinfos->tmplsubsts (cdr typeinfos)))))

   (defun scopes->tmplsubsts (scopes)
     (declare (xargs :mode :program))
     (if (atom scopes)
         nil
       (cons (make-tmplsubst :strs `(("__TYPE__" ,(symbol-name (caar scopes)) . vl-package))
                             :atoms `((__items__ . ,(cddar scopes)))
                             :features (append (cadar scopes)
                                               (and (cddar scopes) '(:has-items))))
             (scopes->tmplsubsts (cdr scopes)))))))

(defsection scope-items

  (local (xdoc::set-default-parents vl-scopeitem))

  (make-event ;; Definition of vl-scopeitem type
   (let ((substs (typeinfos->tmplsubsts (scopes->typeinfos *vl-scopes->items*))))
     `(progn

        (deftranssum vl-scopeitem
          :parents (scopestack)
          :short "Recognizer for Verilog structures that can occur as scope
                  <b>items</b>."

          :long "<p>See @(see scopestack).  The items are only a subset of
                 Verilog declarations like parameter declarations, module
                 instances, etc., i.e., the kinds of things that can be found
                 by @(see vl-scopestack-find-item).  It does not, e.g., for
                 definitions, packages, etc.</p>"

          ,(template-append '((:@ (not :transsum) vl-__type__)) substs)
          ///
          ,@(template-append '((:@ :transsum
                                (defthm vl-scopeitem-p-when-vl-__type__-p
                                  (implies (vl-__type__-p x)
                                           (vl-scopeitem-p x))
                                  :hints(("Goal" :in-theory (enable vl-__type__-p))))))
                             substs))

        (fty::deflist vl-scopeitemlist
          :elt-type vl-scopeitem-p
          :elementp-of-nil nil
          ///
          . ,(template-proj
              '(defthm vl-scopeitemlist-p-when-vl-__type__list-p
                 (implies (vl-__type__list-p x)
                          (vl-scopeitemlist-p x))
                 :hints (("goal" :induct (vl-scopeitemlist-p x)
                          :expand ((vl-__type__list-p x)
                                   (vl-scopeitemlist-p x))
                          :in-theory (enable (:i vl-scopeitemlist-p)))))
              substs)))))

  (fty::defalist vl-scopeitem-alist
    :parents (vl-scopeitem)
    :key-type stringp
    :val-type vl-scopeitem-p)

  (defoption vl-maybe-scopeitem-p vl-scopeitem-p))


(defsection import-results

  ;; BOZO seems too specific to go into top-level docs
  (local (xdoc::set-default-parents scopestack))

  (defprod vl-importresult
    :tag :vl-importresult
    :layout :tree
    :short "Information about an item that was imported from another package."
    ((item     vl-maybe-scopeitem-p "The item we imported, if any.")
     (pkg-name stringp :rule-classes :type-prescription
               "The package we imported it from.")))

  (fty::defalist vl-importresult-alist
    :key-type stringp
    :val-type vl-importresult))


(defsection scope-definitions

  (local (xdoc::set-default-parents vl-scopedef))

  (make-event ;; Definition of vl-scopedef type
   (let ((substs (typeinfos->tmplsubsts (scopes->typeinfos *vl-scopes->defs*))))
     `(progn
        (deftranssum vl-scopedef
          :parents (scopestack)
          :short "Recognizer for Verilog structures that can occur as scope
                  <b>definitions</b>."
          :long "<p>See @(see scopestack).  These are for global definitions like
                 modules, user-defined primitives, etc.</p>"

          ,(template-proj 'vl-__type__ substs))

        (fty::deflist vl-scopedeflist
          :elt-type vl-scopedef-p
          :elementp-of-nil nil
          ///
          . ,(template-proj
              '(defthm vl-scopedeflist-p-when-vl-__type__list-p
                 (implies (vl-__type__list-p x)
                          (vl-scopedeflist-p x))
                 :hints (("goal" :induct (vl-scopedeflist-p x)
                          :expand ((vl-__type__list-p x)
                                   (vl-scopedeflist-p x))
                          :in-theory (enable (:i vl-scopedeflist-p)))))
              substs)))))

  (fty::defalist vl-scopedef-alist
    :key-type stringp
    :val-type vl-scopedef-p))







(local ;; For each searchable type foo, we get:
 ;;                  - vl-find-foo: linear search by name in a list of foos
 ;;                  - vl-foolist-alist: fast alist binding names to foos.
 (defconst *scopeitem-alist/finder-template*
   '(progn
      (defthm vl-__scopetype__-alist-p-of-vl-__type__list-alist
        (equal (vl-__scopetype__-alist-p (vl-__type__list-alist x acc))
               (vl-__scopetype__-alist-p acc))
        :hints(("Goal" :in-theory (enable vl-__type__list-alist
                                          vl-__scopetype__-alist-p)))))))

(make-event ;; Definition of scopeitem alists/finders
 (b* ((itemsubsts (acl2::tmplsubsts-add-strsubsts
                   (acl2::tmplsubsts-add-features
                    (typeinfos->tmplsubsts (scopes->typeinfos *vl-scopes->items*))
                    '(:scopetype))
                   `(("__SCOPETYPE__" "SCOPEITEM" . vl-package))))
      (defsubsts (acl2::tmplsubsts-add-strsubsts
                  (acl2::tmplsubsts-add-features
                   (typeinfos->tmplsubsts (scopes->typeinfos *vl-scopes->defs*))
                   '(:scopetype))
                  `(("__SCOPETYPE__" "SCOPEDEF" . vl-package))))
      ;(pkgsubsts (typeinfos->tmplsubsts (scopes->typeinfos *vl-scopes->pkgs*)))
      ;(portsubsts (typeinfos->tmplsubsts (scopes->typeinfos *vl-scopes->portdecls*)))
      (events (template-proj *scopeitem-alist/finder-template*
                             (append itemsubsts defsubsts
                                     ;;pkgsubsts portsubsts
                                     ))))
   `(progn . ,events)))



;; ;; Now we define:
;; ;; - how to look up a package name in the global design
;; ;; - how to look up a scopeitem in a package, not considering its imports
;; ;; - how to look up a name in a list of import statements.
;; ;; These don't involve the scopestack yet: in each case we know in which scope
;; ;; to find the item.  This works and doesn't need some gross recursive
;; ;; implementation because the following isn't allowed:
;; ;; package bar;
;; ;;   parameter barparam = 13032;
;; ;; endpackage
;; ;; package foo;
;; ;;   import bar::barparam;
;; ;; endpackage
;; ;; module baz ();
;; ;;   import foo::barparam; // fail -- barparam isn't exported by foo.
;; ;; endmodule

;; ;; We then use the above functions to define other scopestack functions resolve
;; ;; imports.


;; (define vl-design->package-alist ((x vl-design-p))
;;   :enabled t
;;   (vl-packagelist-alist (vl-design->packages x) nil)
;;   ///
;;   (memoize 'vl-design->package-alist))

;; (define vl-design-find-package ((name stringp) (x vl-design-p))
;;   :returns (res (iff (vl-package-p res) res))
;;   (mbe :logic (vl-find-package (string-fix name) (vl-design->packages x))
;;        :exec (cdr (hons-get (string-fix name) (vl-design->package-alist x)))))




(local
 (defun def-scopetype-find (scope importp itemtypes resultname resulttype scopeitemtype)
   (declare (xargs :mode :program))
   (b* ((substs (typeinfos->tmplsubsts itemtypes))
        ((unless itemtypes) '(value-triple nil))
        (template
          `(progn
             (define vl-__scope__-scope-find-__result__
               :ignore-ok t
               :parents (vl-scope-find)
               ((name  stringp)
                (scope vl-__scope__-p))
               :returns (item    (iff (__resulttype__ item) item))
               (b* (((vl-__scope__ scope))
                    (?name (string-fix name)))
                 (or . ,(template-proj
                                  '(vl-find-__type__ name scope.__acc__)
                                  substs))))

             (define vl-__scope__-scope-__result__-alist
               :parents (vl-scope-find)
               :ignore-ok t
               ((scope vl-__scope__-p)
                acc)
               :returns (alist (:@ :scopeitemtype
                                (implies (vl-__scopeitemtype__-alist-p acc)
                                         (vl-__scopeitemtype__-alist-p alist))
                                :hints(("Goal" :in-theory (enable vl-__scopeitemtype__-alist-p)))))
               (b* (((vl-__scope__ scope))
                    . ,(reverse
                        (template-proj
                         '(acc (vl-__type__list-alist scope.__acc__ acc))
                         substs)))
                 acc)
               ///
               (local (in-theory (enable vl-__scope__-scope-find-__result__)))
               (defthm vl-__scope__-scope-__result__-alist-lookup-acc-elim
                 (implies (syntaxp (not (equal acc ''nil)))
                          (equal (hons-assoc-equal name (vl-__scope__-scope-__result__-alist scope acc))
                                 (or (hons-assoc-equal name (vl-__scope__-scope-__result__-alist scope nil))
                                     (hons-assoc-equal name acc)))))
               (defthm vl-__scope__-scope-__result__-alist-correct
                 (implies (stringp name)
                          (equal (hons-assoc-equal name (vl-__scope__-scope-__result__-alist scope nil))
                                 (b* ((item (vl-__scope__-scope-find-__result__ name scope)))
                                   (and item
                                        (cons name item))))))
               ;; (defthmd vl-__scope__-scope-__result__-alist-correct2
               ;;   (implies (stringp name)
               ;;            (equal (vl-__scope__-scope-find-__result__ name scope)
               ;;                   (let ((look (hons-assoc-equal name (vl-__scope__-scope-__result__-alist scope nil))))
               ;;                     (mv (consp look) (cdr look))))))
               ))))
     (template-subst-top template
                               (make-tmplsubst
                                :features
                                (append (and importp '(:import))
                                        (and scopeitemtype '(:scopeitemtype)))
                                :strs
                                `(("__SCOPE__" ,(symbol-name scope) . vl-package)
                                  ("__RESULT__" ,(symbol-name resultname) . vl-package)
                                  ("__RESULTTYPE__" ,(symbol-name resulttype) . vl-package)
                                  ("__SCOPEITEMTYPE__" ,(symbol-name scopeitemtype) . vl-package))
                                :pkg-sym 'vl-package)))))


(make-event ;; Definition of vl-design-scope-find-package vl-design-scope-package-alist
 (b* ((substs (scopes->tmplsubsts *vl-scopes->pkgs*)))
   `(progn . ,(template-proj
               '(make-event
                 (def-scopetype-find
                   '__type__
                   (:@ :import t) (:@ (not :import) nil)
                   '__items__ 'package 'vl-package-p 'package))
               substs))))


(make-event ;; Definitions of e.g. vl-module-scope-find-item and vl-module-scope-item-alist
 (b* ((substs (scopes->tmplsubsts *vl-scopes->items*)))
   `(progn . ,(template-proj
               '(make-event
                 (def-scopetype-find '__type__
                   (:@ :import t) (:@ (not :import) nil)
                   '__items__ 'item 'vl-scopeitem-p 'scopeitem))
               substs))))

(make-event ;; Definitions of e.g. vl-design-scope-find-definition and vl-design-scope-definition-alist
 (b* ((substs (scopes->tmplsubsts *vl-scopes->defs*)))
   `(progn . ,(template-proj
               '(make-event
                 (def-scopetype-find '__type__ 
                   (:@ :import t) (:@ (not :import) nil)
                   '__items__ 'definition 'vl-scopedef-p 'scopedef))
               substs))))


(make-event ;; Definition of scopetype-find and -fast-alist functions
 (b* ((substs (scopes->tmplsubsts *vl-scopes->portdecls*)))
   `(progn . ,(template-proj
               '(make-event
                 (def-scopetype-find '__type__
                   (:@ :import t) (:@ (not :import) nil)
                   '__items__ 'portdecl 'vl-portdecl-p 'portdecl))
               substs))))




(define vl-package-scope-item-alist-top ((x vl-package-p))
  :enabled t
  (make-fast-alist (vl-package-scope-item-alist x nil))
  ///
  (memoize 'vl-package-scope-item-alist-top))

(define vl-design-scope-package-alist-top ((x vl-design-p))
  :enabled t
  (make-fast-alist (vl-design-scope-package-alist x nil))
  ///
  (memoize 'vl-design-scope-package-alist-top))


(defprod vl-scopeinfo
  ((locals  vl-scopeitem-alist-p "Locally defined names bound to their declarations")
   (imports vl-importresult-alist-p
            "Explicitly imported names bound to import result, i.e. package-name and declaration)")
   (star-packages string-listp "Names of packages imported with *"))
  :layout :tree
  :tag :vl-scopeinfo)

(make-event ;; Definition of vl-scope type
 (let ((subst (scopes->tmplsubsts *vl-scopes->items*)))
   `(progn
      (deftranssum vl-scope
        :short "Recognizer for a syntactic element that can have named elements within it."
        (,@(template-proj 'vl-__type__ subst)
           vl-scopeinfo))

      (defthm vl-scope-p-tag-forward
        ;; BOZO is this better than the rewrite rule we currently add?
        (implies (vl-scope-p x)
                 (or ,@(template-proj '(equal (tag x) :vl-__type__) subst)
                     (equal (tag x) :vl-scopeinfo)))
        :rule-classes :forward-chaining))))






;; (make-event ;; Definition of vl-package-scope-find-nonimported-item
;;  (b* ((substs (scopes->tmplsubsts (list (assoc 'package *vl-scopes->items*)))))
;;    `(progn . ,(template-proj
;;                '(make-event
;;                  (def-scopetype-find '__type__ nil
;;                    '__items__ 'nonimported-item 'vl-scopeitem-p))
;;                substs))))



;; Now, we want a function for looking up imported names.  This must first look
;; for the name explicitly imported, then implicitly.

;; What do we do when we find an import of a name from a package that doesn't
;; contain that name?  This should be an error, but practially speaking I think
;; we want to check for these in one place and not disrupt other code with
;; error handling.  So in this case we just don't find the item.
(define vl-importlist-find-explicit-item ((name stringp) (x vl-importlist-p) (design vl-maybe-design-p))
  :returns (mv (package (iff (stringp package) package)
                        :hints nil)
               (item (iff (vl-scopeitem-p item) item)
                     :hints nil))
  (b* (((when (atom x)) (mv nil nil))
       ((vl-import x1) (car x))
       ((when (and (stringp x1.part)
                   (equal x1.part (string-fix name))))
        ;; if we don't have a design, I think we still want to say we found the
        ;; item, just not what it is.
        (b* ((package (and design (vl-design-scope-find-package x1.pkg design))))
          ;; regardless of whether the package exists or has the item, return found
          (mv x1.pkg (and package (vl-package-scope-find-item name package))))))
    (vl-importlist-find-explicit-item name (cdr x) design))
  ///
  (more-returns
   (package :name maybe-string-type-of-vl-importlist-find-explicit-item-package
            (or (stringp package) (not package))
            :rule-classes :type-prescription))

  (more-returns
   (package :name package-when-item-of-vl-importlist-find-explicit-item-package
            (implies item package))))

;; (local
;;  (defthm equal-of-vl-importlist-find-explicit-item
;;    (equal (equal (vl-importlist-find-explicit-item name scope design) x)
;;           (and (consp x)
;;                (consp (cdr x))
;;                (not (cddr x))
;;                (equal (mv-nth 0 (vl-importlist-find-explicit-item name scope design))
;;                       (mv-nth 0 x))
;;                (equal (mv-nth 1 (vl-importlist-find-explicit-item name scope design))
;;                       (mv-nth 1 x))))
;;    :hints(("Goal" :in-theory (enable mv-nth-expand-to-conses
;;                                      equal-of-cons
;;                                      vl-importlist-find-explicit-item)))))


(define vl-importlist->explicit-item-alist ((x vl-importlist-p) (design vl-maybe-design-p)
                                            acc)
  :returns (alist (implies (vl-importresult-alist-p acc)
                           (vl-importresult-alist-p alist)))
  (b* (((when (atom x)) acc)
       ((vl-import x1) (car x))
       ((unless (stringp x1.part))
        (vl-importlist->explicit-item-alist (cdr x) design acc))
        ;; if we don't have a design, it seems like returning the package but
        ;; not the item is the best way to go here, since we might have
        ;; imported the name from the package but can't find out.
       (package (and design (cdr (hons-get x1.pkg (vl-design-scope-package-alist-top design)))))
       (item (and package (cdr (hons-get x1.part (vl-package-scope-item-alist-top package))))))
    (hons-acons x1.part (make-vl-importresult :item item :pkg-name x1.pkg)
                (vl-importlist->explicit-item-alist (cdr x) design acc)))
  ///
  (defthm vl-importlist->explicit-item-alist-lookup-acc-elim
    (implies (syntaxp (not (equal acc ''nil)))
             (equal (hons-assoc-equal name (vl-importlist->explicit-item-alist x design acc))
                    (or (hons-assoc-equal name (vl-importlist->explicit-item-alist x design nil))
                        (hons-assoc-equal name acc)))))
  (defthm vl-importlist->explicit-item-alist-correct
    (implies (stringp name)
             (equal (hons-assoc-equal name (vl-importlist->explicit-item-alist x design nil))
                    (b* (((mv pkg item) (vl-importlist-find-explicit-item name x design)))
                      (and (or pkg item)
                           (cons name (make-vl-importresult :item item :pkg-name pkg))))))
    :hints(("Goal" :in-theory (enable vl-importlist-find-explicit-item)))))

(define vl-importlist-find-implicit-item ((name stringp) (x vl-importlist-p) (design vl-maybe-design-p))
  :returns (mv (package (iff (stringp package) package))
               (item (iff (vl-scopeitem-p item) item)))
  (b* (((when (atom x)) (mv nil nil))
       ((vl-import x1) (car x))
       ((unless (eq x1.part :vl-import*))
        (vl-importlist-find-implicit-item name (cdr x) design))
       (package (and design (vl-design-scope-find-package x1.pkg design)))
       ((unless package) (mv x1.pkg nil))
       (item (vl-package-scope-find-item (string-fix name) package)))
    (if item
        (mv x1.pkg item)
      (vl-importlist-find-implicit-item name (cdr x) design)))
  ///
  (more-returns
   (package :name maybe-string-type-of-vl-importlist-find-implicit-item-package
          (or (stringp package) (not package))
          :rule-classes :type-prescription)))


(define vl-importlist->star-packages ((x vl-importlist-p))
  :returns (packages string-listp)
  (b* (((when (atom x)) nil)
       ((vl-import x1) (car x)))
    (if (eq x1.part :vl-import*)
        (cons x1.pkg (vl-importlist->star-packages (cdr x)))
      (vl-importlist->star-packages (cdr x)))))


(define vl-import-stars-find-item ((name stringp) (packages string-listp) (design vl-maybe-design-p))
  :returns (mv (package (iff (stringp package) package))
               (item (iff (vl-scopeitem-p item) item)))
  (b* (((when (atom packages)) (mv nil nil))
       (pkg (string-fix (car packages)))
       (package (and design (cdr (hons-get pkg (vl-design-scope-package-alist-top design)))))
       ((unless package) (mv pkg nil))
       (item (cdr (hons-get (string-fix name)
                            (vl-package-scope-item-alist-top package))))
       ((when item) (mv pkg item)))
    (vl-import-stars-find-item name (cdr packages) design))
  ///
  (defthm vl-import-stars-find-item-correct
    (equal (vl-import-stars-find-item name (vl-importlist->star-packages x) design)
           (vl-importlist-find-implicit-item name x design))
    :hints(("Goal" :in-theory (enable vl-importlist-find-implicit-item
                                      vl-importlist->star-packages)))))






(define vl-scopeinfo-find-item ((name stringp) (x vl-scopeinfo-p) (design vl-maybe-design-p))
  :returns (mv (package (iff (stringp package) package))
               (item (iff (vl-scopeitem-p item) item)))
  (b* (((vl-scopeinfo x))
       (name (string-fix name))
       (local-item (cdr (hons-get name x.locals)))
       ((when local-item) (mv nil local-item))
       (import-item (cdr (hons-get name x.imports)))
       ((when import-item) (mv (vl-importresult->pkg-name import-item)
                               (vl-importresult->item import-item))))
    (vl-import-stars-find-item name x.star-packages design)))










;; (fty::deflist vl-scopelist :elt-type vl-scope :elementp-of-nil nil)

(local (defthm type-of-vl-scope-fix
         (consp (vl-scope-fix x))
         :hints (("goal" :use ((:instance consp-when-vl-scope-p
                                (x (vl-scope-fix x))))
                  :in-theory (disable consp-when-vl-scope-p)))
         :rule-classes :type-prescription))


(fty::defflexsum vl-scopestack
  (:null :cond (atom x)
   :shape (eq x nil)
   :ctor-body nil)
  (:global :cond (eq (car x) :global)
   :fields ((design :type vl-design-p :acc-body (Cdr x)))
   :ctor-body (cons :global design))
  (:local :cond t
   :fields ((top :type vl-scope-p :acc-body (car x))
            (super :type vl-scopestack-p :acc-body (cdr x)))
   :ctor-body (cons top super)))

(define vl-scopestack->design ((x vl-scopestack-p))
  :returns (design (iff (vl-design-p design) design))
  :measure (vl-scopestack-count x)
  (vl-scopestack-case x
    :null nil
    :global x.design
    :local (vl-scopestack->design x.super))
  ///
  (more-returns
   (design :name vl-maybe-design-p-of-vl-scopestack->design
           (vl-maybe-design-p design))))

(define vl-scopestack-push ((scope vl-scope-p) (x vl-scopestack-p))
  :returns (x1 vl-scopestack-p)
  (make-vl-scopestack-local :top scope :super x))

(define vl-scopestack-pop ((x vl-scopestack-p))
  :returns (super vl-scopestack-p)
  (vl-scopestack-case x
    :local x.super
    :otherwise (vl-scopestack-fix x)))

(define vl-scopestack-init
  :short "Create an initial scope stack for an entire design."
  ((design vl-design-p))
  :returns (ss vl-scopestack-p)
  (make-vl-scopestack-global :design design))


(define vl-scopestack-nesting-level ((x vl-scopestack-p))
  :returns (level natp)
  :measure (vl-scopestack-count x)
  (vl-scopestack-case x
    :null 0
    :global 1
    :local (+ 1 (vl-scopestack-nesting-level x.super))))


(local (defthm vl-maybe-design-p-when-iff
         (implies (iff (vl-design-p x) x)
                  (vl-maybe-design-p x))))


(local
 (defun def-vl-scope-find-item (table result resulttype stackp importsp)
   (declare (xargs :mode :program))
   (b* ((substs (scopes->tmplsubsts table))
        (template
          `(progn
             (define vl-scope-find-item
               :short "Look up a plain identifier to find an item in a scope."
               ((name  stringp)
                (scope vl-scope-p)
                (design vl-maybe-design-p))
               :returns (mv (pkg-name    (iff (stringp pkg-name) pkg-name)
                                         "The name of the package where the item was found, if applicable.")
                            (item  (iff (vl-scopeitem-p item) item)
                                   "The declaration object for the given name, if found."))
               (b* ((scope (vl-scope-fix scope)))
                 (case (tag scope)
                   ,@(template-append
                      '((:@ :has-items
                         (:vl-__type__
                          (:@ (not :import)
                           (mv nil (vl-__type__-scope-find-__result__ name scope)))
                          (:@ :import
                           (b* (((vl-__type__ scope :quietp t))
                                (item (vl-__type__-scope-find-__result__ name scope))
                                ((when item) (mv nil item))
                                ((mv pkg item) (vl-importlist-find-explicit-item
                                                name scope.imports design))
                                ((when (or pkg item)) (mv pkg item)))
                             (vl-importlist-find-implicit-item name scope.imports design))))))
                      substs)
                   (:vl-scopeinfo
                    (vl-scopeinfo-find-item name scope design))
                   (otherwise (mv nil nil))))
               ///
               (more-returns
                (pkg-name :name maybe-string-type-of-vl-scope-find-item-pkg-name
                          (or (stringp pkg-name) (not pkg-name))
                          :rule-classes :type-prescription)))


             (define vl-scope->scopeinfo
               :short "Make a fast lookup table for items in a scope.  Memoized."
               ((scope vl-scope-p)
                (design vl-maybe-design-p))
               :returns (scopeinfo vl-scopeinfo-p)
               (b* ((scope (vl-scope-fix scope)))
                 (case (tag scope)
                   ,@(template-append
                      '((:@ :has-items
                         (:vl-__type__
                          (b* (((vl-__type__ scope :quietp t)))
                            (make-vl-scopeinfo
                             :locals (make-fast-alist
                                      (vl-__type__-scope-__result__-alist scope nil))
                             (:@ :import
                              :imports (make-fast-alist
                                        (vl-importlist->explicit-item-alist scope.imports design nil))
                              :star-packages (vl-importlist->star-packages scope.imports)))))))
                      substs)
                   (:vl-scopeinfo (vl-scopeinfo-fix scope))
                   (otherwise (make-vl-scopeinfo))))
               ///
               (local (in-theory (enable vl-scope-find-item
                                         vl-scopeinfo-find-item)))
               (defthm vl-scope->scopeinfo-correct
                 (implies (stringp name)
                          (equal (vl-scopeinfo-find-item name (vl-scope->scopeinfo scope design) design)
                                 (vl-scope-find-item name scope design)))
                 :hints (("goal" :expand ((vl-import-stars-find-item name nil design)))))
               (memoize 'vl-scope->scopeinfo))

             (define vl-scope-find-item-fast
               :short "Like @(see vl-scope-find-item), but uses a fast lookup table."
               ((name stringp)
                (scope vl-scope-p)
                (design vl-maybe-design-p))
               :enabled t
               (mbe :logic (vl-scope-find-item name scope design)
                    :exec (vl-scopeinfo-find-item name (vl-scope->scopeinfo scope design) design )))

             ,@(and stackp
                    `((define vl-scopestack-find-item/context
                        ((name stringp)
                         (ss   vl-scopestack-p))
                        :hints (("goal" :expand ((vl-scopestack-fix ss))))
                        :guard-hints (("goal" :expand ((vl-scopestack-p ss))))
                        :short "Find an item declaration and information about where it was declared."
                        :returns (mv (item (iff (vl-scopeitem-p item) item)
                                           "The item declaration, if found")
                                     (item-ss vl-scopestack-p
                                              "The scopestack for the context in
                                               which the item was found")
                                     (pkg-name (iff (stringp pkg-name) pkg-name)
                                               "The package from which the item
                                                was imported, if applicable."))
                        :measure (vl-scopestack-count ss)
                        (b* ((ss (vl-scopestack-fix ss)))
                          (vl-scopestack-case ss
                            :null (mv nil nil nil)
                            :global (b* (((mv pkg-name item)
                                          (vl-scope-find-item-fast name ss.design
                                                                   ss.design)))
                                      (mv item (vl-scopestack-fix ss) pkg-name))
                            :local (b* ((design (vl-scopestack->design ss))
                                        ((mv pkg-name item)
                                         (vl-scope-find-item-fast name ss.top design))
                                        ((when (or pkg-name item))
                                         (mv item ss pkg-name)))
                                     (vl-scopestack-find-item/context name ss.super)))))

                      (define vl-scopestack-find-item
                        :short "Look up a plain identifier in the current scope stack."
                        ((name stringp)
                         (ss   vl-scopestack-p))
                        :returns (item (iff (vl-scopeitem-p item) item)
                                       "The item declaration, if found.")
                        (b* (((mv item & &) (vl-scopestack-find-item/context name ss)))
                          item))

                      (define vl-scopestack-find-item/ss
                        :short "Look up a plain identifier in the current scope stack."
                        ((name stringp)
                         (ss   vl-scopestack-p))
                        :returns (mv (item (iff (__resulttype__ item) item)
                                       "The item declaration, if found.")
                                     (item-ss vl-scopestack-p
                                              "The scopestack for the context
                                               in which the item was declared."))
                        (b* (((mv item context-ss pkg-name)
                              (vl-scopestack-find-item/context name ss))
                             ((unless pkg-name) (mv item context-ss))
                             (design (vl-scopestack->design context-ss))
                             (pkg (and design (cdr (hons-get pkg-name (vl-design-scope-package-alist-top design)))))
                             ((unless pkg) ;; this should mean item is already nil
                              (mv item nil))
                             (pkg-ss (vl-scopestack-push pkg (vl-scopestack-init design))))
                          (mv item pkg-ss))))))))
     (template-subst-top template
                         (make-tmplsubst
                          :features (and importsp '(:import))
                          :strs `(("__RESULT__" ,(symbol-name result) . vl-package)
                                  ("__RESULTTYPE__" ,(symbol-name resulttype) . vl-package))
                          :pkg-sym 'vl-package)))))

(local (defthm maybe-scopeitem-when-iff
         (implies (or (vl-scopeitem-p x)
                      (not x))
                  (vl-maybe-scopeitem-p x))
         ))

(make-event
#||
  (define vl-scope-find-item ...)
  (define vl-scope-item-alist ...)
  (define vl-scope-find-item-fast ...)
  (define vl-scopestack-find-item ...)
||#

 (def-vl-scope-find-item *vl-scopes->items* 'item 'vl-scopeitem-p t t))



(local
 (defun def-vl-scope-find (table result resulttype stackp)
   (declare (xargs :mode :program))
   (b* ((substs (scopes->tmplsubsts table))
        (template
          `(progn
             (define vl-scope-find-__result__
               :short "Look up a plain identifier to find a __result__ in a scope."
               ((name  stringp)
                (scope vl-scope-p))
               :returns (__result__ (iff (vl-__resulttype__-p __result__) __result__))
               (b* ((scope (vl-scope-fix scope)))
                 (case (tag scope)
                   ,@(template-append
                      '((:@ :has-items
                         (:vl-__type__
                          (vl-__type__-scope-find-__result__ name scope))))
                      substs)
                   (otherwise nil))))


             (define vl-scope-__result__-alist
               :short "Make a fast lookup table for __result__s in a scope.  Memoized."
               ((scope vl-scope-p))
               :returns (alist vl-__resulttype__-alist-p)
               (b* ((scope (vl-scope-fix scope)))
                 (case (tag scope)
                   ,@(template-append
                      '((:@ :has-items
                         (:vl-__type__
                          (b* (((vl-__type__ scope :quietp t)))
                            (make-fast-alist
                             (vl-__type__-scope-__result__-alist scope nil))))))
                      substs)
                   (otherwise nil)))
               ///
               (local (in-theory (enable vl-scope-find-__result__)))
               (defthm vl-scope-__result__-alist-correct
                 (implies (stringp name)
                          (equal (cdr (hons-assoc-equal name (vl-scope-__result__-alist scope)))
                                 (vl-scope-find-__result__ name scope (:@ :import design))))
                 :hints (("goal" :expand ((vl-import-stars-find-item name nil design)))))
               (memoize 'vl-scope-__result__-alist))

             (define vl-scope-find-__result__-fast
               :short "Like @(see vl-scope-find-__result__), but uses a fast lookup table"
               ((name stringp)
                (scope vl-scope-p))
               :enabled t
               (mbe :logic (vl-scope-find-__result__ name scope)
                    :exec (cdr (hons-get name (vl-scope-__result__-alist scope)))))

             ,@(and stackp
                    `((define vl-scopestack-find-__result__/ss
                        ((name stringp)
                         (ss   vl-scopestack-p))
                        :hints (("goal" :expand ((vl-scopestack-fix ss))))
                        :guard-hints (("goal" :expand ((vl-scopestack-p ss))))
                        :returns (mv (__result__ (iff (vl-__resulttype__-p __result__) __result__)
                                                 "The declaration, if found")
                                     (__result__-ss vl-scopestack-p
                                                    "The scopestack showing the
                                                     context of the declaration"))
                        :short "Find a __definition__ as well as info about where it was found"
                        :measure (vl-scopestack-count ss)
                        (b* ((ss (vl-scopestack-fix ss)))
                          (vl-scopestack-case ss
                            :null (mv nil nil)
                            :global (b* ((__result__
                                          (vl-scope-find-__result__-fast name ss.design)))
                                      (mv __result__ (vl-scopestack-fix ss)))
                            :local (b* ((__result__
                                         (vl-scope-find-__result__-fast name ss.top))
                                        ((when __result__)
                                         (mv __result__ ss)))
                                     (vl-scopestack-find-__result__/ss name ss.super)))))

                      (define vl-scopestack-find-__result__
                        :short "Look up a plain identifier in the current scope stack."
                        ((name stringp)
                         (ss   vl-scopestack-p))
                        :returns (__result__ (iff (vl-__resulttype__-p __result__) __result__))
                        (b* (((mv __result__ &) (vl-scopestack-find-__result__/ss name ss)))
                          __result__)))))))
     (template-subst-top template
                         (make-tmplsubst
                          :strs `(("__RESULT__" ,(symbol-name result) . vl-package)
                                  ("__RESULTTYPE__" ,(symbol-name resulttype) . vl-package))
                          :pkg-sym 'vl-package)))))





(make-event
 #||
 (define vl-scope-find-definition ...)
 (define vl-scope-definition-alist ...)
 (define vl-scope-find-definition-fast ...)
 (define vl-scopestack-find-definition ...)
 ||#
 (def-vl-scope-find *vl-scopes->defs* 'definition 'scopedef t))

(make-event
#||
  (define vl-scope-find-package ...)
  (define vl-scope-package-alist ...)
  (define vl-scope-find-package-fast ...)
  (define vl-scopestack-find-package ...)
||#
 (def-vl-scope-find *vl-scopes->pkgs* 'package 'package t))

(make-event
#||
  (define vl-scope-find-portdecl ...)
  (define vl-scope-portdecl-alist ...)
  (define vl-scope-find-portdecl-fast ...)
||#
 (def-vl-scope-find *vl-scopes->portdecls* 'portdecl 'portdecl nil))




(define vl-scopestacks-free ()
  :parents (scopestack)
  :short "Frees memoization tables associated with scopestacks."
  :long "<p>You should generally call this function, e.g., at the end of any
transform that has used scopestacks.</p>"
  (progn$ (clear-memoize-table 'vl-scope->scopeinfo)
          (clear-memoize-table 'vl-scope-definition-alist)
          (clear-memoize-table 'vl-scope-package-alist)
          (clear-memoize-table 'vl-scope-portdecl-alist)
          (clear-memoize-table 'vl-design-scope-package-alist-top)
          (clear-memoize-table 'vl-package-scope-item-alist-top)))


