(*|

Tutorial on Coq commands
************************

:author: Enrico Tassi

..
   Elpi is an extension language that comes as a library
   to be embedded into host applications such as Coq.
   
   Elpi is a variant of λProlog enriched with constraints.
   λProlog is a programming language designed to make it easy
   to manipulate abstract syntax trees containing binders.
   Elpi extends λProlog with programming constructs that are
   designed to make it easy to manipulate abstract syntax trees
   containing metavariables (also called unification variables, or
   evars in the Coq jargon).
   
   This software, "coq-elpi", is a Coq plugin embedding Elpi and
   exposing to the extension language Coq spefic data types (e.g. terms)
   and API (e.g. to declare a new inductive type).
   
   In order to get proper syntax highlighting using VSCode please install the
   "gares.coq-elpi-lang" extension. In CoqIDE please chose "coq-elpi" in
   Edit -> Preferences -> Colors.


This tutorial assumes the reader is familiar with Elpi and the HOAS
representation of Coq terms; if it is not the case, please take a look at
these other tutorials first:
`Elpi tutorial <https://lpcic.github.io/coq-elpi/tutorial_elpi_lang.html>`_
and 
`Coq HOAS tutorial <https://lpcic.github.io/coq-elpi/tutorial_coq_elpi_HOAS.html>`_.

.. contents::

=================
Defining commands
=================

Lets declare a simple program, called "hello"

|*)
From elpi Require Import elpi.

Elpi Command hello.
Elpi Accumulate lp:{{

  % main is, well, the entry point
  main Arguments :- coq.say "Hello" Arguments.

}}.
Elpi Typecheck.

(*|

The program declaration is made of 3 parts.

The first one `Elpi Command hello.` sets the current program to hello.
Since it is declared as a `Command` some code is loaded automatically:

* APIs (eg `coq.say`) and data types (eg Coq terms) are loaded from
  `coq-builtin.elpi <https://github.com/LPCIC/coq-elpi/blob/master/coq-builtin.elpi>`_
* some utilities, like `copy` or `whd1` are loaded from
  `elpi-command-template.elpi <https://github.com/LPCIC/coq-elpi/blob/master/elpi/elpi-command-template.elpi>`_

  
The second one `Elpi Accumulate ...` loads some extra code.
The `Elpi Accumulate ...` family of commands lets one accumulate code
taken from:

* verbatim text `Elpi Accumulate lp:{{ <code> }}`
* source files `Elpi Accumulate File <path>`
* data bases (Db) `Elpi Accumulate Db <name>`

Accumulating code via inline text or file is equivalent, the AST of <code>
is stored in the .vo file (the external file does not need to be installed).
We postpone the description of data bases to a dedicated section.

Once all the code is accumulated `Elpi Typecheck` verifies that the
code does not contain the most frequent kind of mistakes. This command
considers some mistakes minor and only warns about them. You can
pass `-w +elpi.typecheck` to `coqc` to turn these warnings into errors.

We can now run our program!

|*)

Elpi hello "world!".

(*|

You should see the following output (hover the bubble next to the
code if you are reading this online):

.. code::

   Hello [str world!]

The  string `"world!"` we passed to the command is received by the code
as `(str "world!")`. Note that `coq.say` won't print quotes around strings.

=================
Command arguments
=================

|*)

Elpi hello 46.
Elpi hello there.

(*|

This time we passed to the command a number and an identifier.
Identifiers are received as strings, and can contain dots, but no spaces.

|*)

Elpi hello my friend.
Elpi hello this.is.a.qualified.name.

(*|

Indeed the first invocation passes two arguments, of type string, while
the second a single one, again a string containing dots.

There are a few more types of arguments a command can receive:

* terms, delimited by `(` and `)`
* toplevel declarations, like `Inductive ..`, `Definition ..`, etc..
  which are introduced by their characterizing keyword.

Let's try with a term.

|*)

Elpi hello (0 = 1).

(*|

Terms are received "raw", in the sense that no elaboration has been
performed. In the example above the type argument to `eq` has not
been synthesized to be `nat`. As we will see later the `coq.typecheck` API
can be used to satisfy typing constraints.

|*)

Elpi hello Definition test := 0 = 1.
Elpi hello Record test := { f1 : nat; f2 : f1 = 1 }.

(*|

Global declarations are received raw as well. In the case of `Definition test`
the optional body (would be none for an `Axiom` declaration) is present
and the type is omitted (that is, a variable `X1` is used).

In the case of the `Record` declaration remark that each field has a few
attributes, like being a coercions (the `:>` in Coq's syntax). Also note that
the type of the record (which wa omitted) defaults to `Type`
(for some level `X0`). Finally note the type of the second field sees `c0`
(the value of the first field).

See the `argument` data type in 
`coq-builtin.elpi <https://github.com/LPCIC/coq-elpi/blob/master/coq-builtin.elpi>`_.
for a detailed decription of all the arguments a command can receive.

========================
Processing raw arguments
========================

There are two ways to process term arguments: typechecking and elaboration.
    
|*)

Elpi Command check_arg.
Elpi Accumulate lp:{{

  main [trm T] :-
    std.assert-ok! (coq.typecheck T Ty) "argument illtyped",
    coq.say "The type of" T "is" Ty.

}}.
Elpi Typecheck.

Elpi check_arg (1 = 0).
Fail Elpi check_arg (1 = true).

(*|

The command `check_arg` receives a term `T` and type checks it, then it
prints the term and its type.

The `coq.typecheck` API has 3 arguments: a term, its type and a diagnostic
which can either be `ok` or `(error Message)`. The `std.assert-ok!` combinator
checks if the diagnostic is `ok`, and if not it prints the error message and
bails out.
  
The first invocation succeeds while the second one fails and prints
the type checking error (given by Coq) following the string passed to
`std.assert-ok!`.

|*)

Coercion bool2nat (b : bool) := if b then 1 else 0.
Fail Elpi check_arg (1 = true).
Check (1 = true).

(*|

The command still fails even if we told Coq how to inject booleans values
into the natural numbers. Indeed the Check commands works.

The `coq.typecheck` API modifies the term in place, it can assign
implicit arguments (like the type parameter of `eq`) but it cannot modify the
structure of the term. To do so, one has to use the `coq.elaborate-skeleton`
API.

|*)

Elpi Command elaborate_arg.
Elpi Accumulate lp:{{

  main [trm T] :-
    std.assert-ok! (coq.elaborate-skeleton T Ty T1) "illtyped arg",
    coq.say "T=" T,
    coq.say "T1=" T1,
    coq.say "Ty=" Ty.
    
}}.
Elpi Typecheck.

Elpi elaborate_arg (1 = true).

(*|

Remark how `T` is not touched by the call to this API, and how `T1` is a copy
of `T` where the hole after `eq` is synthesized and the value `true`
injected to `nat` by using `bool2nat`.

It is also possible to manipulate term arguments before typechecking
them, but note that all the considerations on holes in the tutorial about
the HOAS representation of Coq terms apply here. 

============================
Example: Synthesizing a term
============================

Synthesizing a term typically involves reading an existing declaration
and writing a new one. The relevant APIs are in the `coq.env.*` namespace
and are named after the global refence they manipulate, eg `coq.env.const`
for reading and `coq.env.add-const` for writing.

Here we implement a little command that given an inductive type name, it
generates a term of type nat whose value is the number of constructors
of the given inductive type.

|*)

Elpi Command constructors_num.

Elpi Accumulate lp:{{

  pred int->nat i:int, o:term.
  int->nat 0 {{ 0 }}.
  int->nat N {{ S lp:X }} :- M is N - 1, int->nat M X.

  main [str IndName, str Name] :-
    std.assert! (coq.locate IndName (indt GR)) "not an inductive type",
    coq.env.indt GR _ _ _ _ Kn _,      % the names of the constructors
    std.length Kn N,                   % count them
    int->nat N Nnat,                   % turn the integer into a nat
    coq.env.add-const Name Nnat _ _ _. % save it

}}.
Elpi Typecheck.

Elpi constructors_num bool nK_bool.
Print nK_bool. (* number of constructor of "bool" *)
Elpi constructors_num False nK_False.
Print nK_False.
Fail Elpi constructors_num plus nK_plus.
Fail Elpi constructors_num not_there bla.

(*|

The command starts by locating the first argument and asserting it points to
an inductive type. This line is idiomatic: `coq.locate` aborts if the string
cannot be located, and if it relates it to a gref which is not indt (for
example const plus) `std.assert!` aborts with the given error message.

`coq.env.indt` lets one access all the details of an inductive type, here
we just use the list of constructors. The twin API `coq.env.indet-decl` lets
one access the declaration of the inductive in HOAS form, which might be
easier to manipulate in other situations, like the next example.

Then it crafts a natural number and declares a constant.

=================================
Example: Abstracting an inductive
=================================

For the sake of introducing `copy`, the swiss army knife of λProlog, we
write a command which takes an inductive type declaration and builds a new
one abstracting the former one on a given term. The new inductive has a
parameter in place of the occurrences of that term.

|*)

Elpi Command abstract.

Elpi Accumulate lp:{{

  % a renaming function which adds a ' to an ident (a string)
  pred prime i:id, o:id.
  prime S S1 :- S1 is S ^ "'".

  main [str Ind, trm Param] :-
    
    % the term to be abstracted out, P of type PTy
    std.assert-ok!
      (coq.elaborate-skeleton Param PTy P)
      "illtyped parameter",
    
    % fetch the old declaration
    std.assert! (coq.locate Ind (indt I)) "not an inductive type",
    coq.env.indt-decl I Decl,

    % lets start to craft the new declaration by putting a
    % parameter A which has the type of P
    NewDecl = parameter "A" explicit PTy Decl',

    % lets make a copy, capturing all occurrences of P with a
    % (which stands for the paramter)
    (pi a\ copy P a => copy-indt-decl Decl (Decl' a)),

    % to avoid name clashes, we rename the type and its constructors
    % (we don't need to rename the parameters)
    coq.rename-indt-decl (=) prime prime NewDecl DeclRenamed,

    % we type check the inductive declaration, since abstracting
    % random terms may lead to illtyped declarations (type theory
    % is tough)
    std.assert-ok!
      (coq.typecheck-indt-decl DeclRenamed)
      "can't be abstracted",

    coq.env.add-indt DeclRenamed _.

}}.
Elpi Typecheck.

Inductive tree := leaf | node : tree -> option nat -> tree -> tree.

Elpi abstract tree (option nat).
Print tree'.

(*|

As expected `tree'` as a parameter `A`.

Now lets focus on `copy`. The standard
coq library (loaded by the command template) contains a definition of copy
for terms and declarations
`coq-lib.elpi <https://github.com/LPCIC/coq-elpi/blob/master/elpi/coq-lib.elpi>`_.

An excerpt:

.. code::

  copy X X :- name X.
  copy (global _ as C) C.
  copy (fun N T F) (fun N T1 F1).
    copy T T1, pi x\ copy (F x) (F1 x).
  copy (app L) (app L1) :- !, std.map L copy L1.

Copy implements the identity: it builds, recursively, a copy of the first
term into the second argument. Unless one loads in the context a new clause,
which takes precedence over the identity ones. Here we load

.. code::

  copy P a

which, at run time, looks like

.. code::

  copy (app [global (indt «option»), global (indt «nat»)]) c0

and that clause masks the one for `app` when the sub-term being copied is
exactly (`option nat`). `copy-indt-decl` copies an inductive declaration and
calls `copy` on all the terms it contains (e.g. the type of the constructors).

The `copy` predicate is very flexible, but sometimes one needs to collect
some data along the copy. The sibling `fold-map` lets one do that. An excerpt:

.. code::

  fold-map (fun N T F) A (fun N T1 F1) A2 :-
    fold-map T A T1 A1, pi x\ fold-map (F x) A1 (F1 x) A2.

For example one can use `fold-map` to collect into a list all the occurrences
of inductive type constructors in a given term, then use the list to postulate
the right number of binders for them, and finally use copy to capture them.


====================================
Using DBs to store data across calls
====================================


A Db can be create with the command:

.. code::

  Elpi Db <name> lp:{{ <code> }}.

and a Db can be later extended via `Elpi Accumulate`.

A Db is pretty much like a regular program but can be shared among
other programs *and* is accumulated by name. Moreover the Db and can be
extended by Elpi programs as well thanks to the API `coq.elpi.accumulate`.

Since is a Db is accumulated by name, each time a program runs, the currect
contents of the Db are loaded, <code> is usually just the type declaration
for the predicates part of the Db, and maybe a few default clauses.

Let's define a Db.

|*)

Elpi Db age.db lp:{{ % We like Db names to end in a .db suffix

  % A typical Db is made of one main predicate
  pred age o:string, o:int.

  % the Db is empty for now, we put a clause giving a descriptive error
  % and we name that clause "age.fail".
  :name "age.fail"
  age Name _ :- coq.error "I don't know who" Name "is!".

}}.

(*|

Elpi clauses can be given a name via the `:name` attribute. Named clauses
serve as anchor-points when clauses are added to the Db.

Let's define a Command that makes use of a Db.

|*)

Elpi Command age.
Elpi Accumulate Db age.db.  (* we accumulate the Db *)
Elpi Accumulate lp:{{

  main [str Name] :-
    age Name A,
    coq.say Name "is" A "years old".

}}.
Elpi Typecheck. 

Fail Elpi age bob.

(*|

Let's put some data in the Db. Given that the Db contains a catch-all clause,
we need the new one to be put before it.
   
|*)

Elpi Accumulate age.db lp:{{

  :before "age.fail"     % we place this clause before the catch all
  age "bob" 24.

}}.

Elpi age bob.

(*|

Extending data bases this way is fine, but requires the user of our command
to be familiar with Elpi's syntax, which is not very nice. It would be
more polite to write a command which extends the Db.

|*)

Elpi Command set_age.
Elpi Accumulate Db age.db.
Elpi Accumulate lp:{{
  main [str Name, int Age] :-
    TheClause = age Name Age,
    coq.elpi.accumulate _ "age.db"
      (clause _ (before "age.fail") TheClause).
  
}}.
Elpi Typecheck.

Elpi set_age "alice" 21.
Elpi age "alice".

(*|
  
Additions to a Db are Coq object, a bit like a Notation or a Type Class
instance: these object live inside a Coq module (or a Coq file) and become
active when that module is Imported. Hence deciding to which Coq module these
extra clauses belong is important and `coq.elpi.accumulate` provides a few
options to tune that (here we passed _, that uses the default setting).
All the options to `coq.elpi.accumulate` are described in coq-builtin.elpi,
as all other APIs.

=====================
Attributes and Export
=====================

Elpi programs can be prefixed with attributes, like `#[local]`.
Attributes are not passed as arguments but rather as a clause in the context,
a bit like the option `@holes!` we have seen before.
   
|*)

Elpi Command attr.
Elpi Accumulate lp:{{

  main _ :-
    attributes A, % we fetch the list of attributes from the context
    coq.say A.

}}.

#[this, more(stuff="33")] Elpi attr.

(*|

The first attribute, `elpi.loc` is always present and corresponds to the
location in the source file of the command. Then we find an attribute for
`"this"` holding the emptry string and an attribute for `"more.stuff"` holding
the string `"33"`.

Attributes are usually validated (parsed) and turned into regular options
using `coq.parse-attributes` (its implementation and documentation is in
coq-lib.elpi):

|*)

Elpi Command parse_attr.
Elpi Accumulate lp:{{

  pred some-code.
  some-code :-
    get-option "more.stuff" N, get-option "this" B, coq.say N B.

  main _ :-
    attributes A,
    coq.parse-attributes A [
      att "this" bool,
      att "more.stuff" int,
    ] Opts,
    coq.say "options=" Opts,
    Opts => some-code.

}}.

#[this, more(stuff="33")] Elpi parse_attr.
Fail #[unknown] Elpi parse_attr.

(*|

Note that `get-option` links a string with a datum of type `any`, which means
no type checking is performed on it. It is recommended to wrap calls to
get-option into other predicates typed in a more precise way.

Elpi programs can be exported as regular Coq commands, so that the
final user does not need to type Elpi to invoke them.

|*)

Elpi Command Say.
Elpi Accumulate lp:{{ main [str S] :- coq.say S. }}.
Elpi Typecheck.
Elpi Export Say.

Say "That is all folks!".

(*|

Not yet...

Coq offers no equivalent of Tactic Notation for commands.
Still Elpi commands accept any symbol or keyword as strings.
It is up to the programmer to catch and report parse errors.

|*)

Elpi Command go.
Elpi Accumulate lp:{{
  main [str Src, str "=>", str Tgt, str "/", str F] :- !,
    coq.say "going from" Src "to" Tgt "via" F.
  main _ :- coq.error "Parse error! Use: go <from> => <to> / <via>".
}}.
Elpi Typecheck.
Elpi Export go.

go source => target / plane.
Fail go nowhere.

(*|

Last, (good) Elpi programs should fail reporting intellegible error messages,
as the previous one. If they just fail, they produce the following generic
error.

|*)

Elpi Command bad.
Elpi Accumulate lp:{{ main []. }}.
Elpi Typecheck.
Elpi Export bad.

Fail bad 1.

(*|

The command has indeed failed with message:
The elpi command bad failed without giving a specific error message. Please
report this inconvenience to the authors of the program.

This is really the end, unless you want to learn more about writing
`tactics <https://lpcic.github.io/coq-elpi/tutorial_coq_elpi_tactic.html>`_
in Elpi, in that case look at that tutorial ;-)

.. include:: tutorial_style.rst

|*)