grammar SubseaCable;

/*
 * ============================================================
 * Subsea Cable Language — ANTLR4 Parser Specification
 * ============================================================
 * NOTE:
 * The generated lexer emits physical newline and comment tokens. Before the
 * parser consumes them, a REQUIRED lexical preprocessing stage normalizes that
 * raw token stream according to the SSoT lexical conventions below:
 * - Remove a line comment but preserve its terminating physical newline.
 * - Replace an entire block comment, including any internal newlines, with one
 *   ordinary whitespace boundary. Only a newline outside a block comment can emit
 *   a TERMINATOR. Comments never concatenate adjacent tokens.
 * - Block comments do not nest; the first closing delimiter ends the comment.
 * - Suppress physical newlines inside unclosed [], {}, or ().
 * - Suppress a physical newline immediately after any token in this exact
 *   continuation set:
 *       =  ->  -0>  -1>  -N>  ,  :  @  $
 *       ||  &&  ==  !=  <=  >=  <  >
 *       +  -  *  /  %  !
 * - Coalesce the remaining physical newlines and emit logical TERMINATOR tokens.
 * - Form a MULTIPLICITY_ARROW token in exactly one position: immediately after
 *   the square-bracket group that begins a Binding's right-hand side. When a
 *   depth-zero `=` is followed at once by `[`, and that group closes back to
 *   depth zero, and the next three tokens are `-`, then `0`, `1` or `N`, then
 *   `>`, with no character between them, replace those three tokens with one
 *   MULTIPLICITY_ARROW whose text is `-0>`, `-1>` or `-N>`. Nowhere else is the
 *   sequence fused: a parenthesized right-hand side such as `(base)-1>0` stays
 *   ordinary subtraction and comparison, as do `x-1>0` and a spaced `- 1 >`.
 * - Form the contextual Root keyword. When the first token of a statement (the
 *   first token of the file, or the first after a logical TERMINATOR, at
 *   depth zero) is the Identifier `root` and the next token is an Identifier,
 *   retype it as ROOT; `root = ...` and every other use stay IDENTIFIER. After
 *   ROOT, an Identifier, an optional HASH_QUALIFIER and `/`, a NUMBER with no
 *   fractional part is retyped as ROOT_ARITY. Any other spelling in those
 *   positions reaches the parser unchanged and is a SyntaxError.
 *
 * This stage MUST be implemented independently of the grammar, for example as
 * a TokenSource wrapper. The parser rules consume only the normalized stream.
 * ============================================================
 */

/*
 * ============================================================
 * Semantic Model
 * ------------------------------------------------------------
 * Interpreted by Vessel/Carousel (structural demand and atomic deduction),
 * Cable (installed topology and its Outcome & Value Store), Host (concrete
 * semantics), and Scheduler (eligibility, outcomes, and Scheduler-addressed
 * policy). NOT enforced by this grammar. This is a synchronized summary for
 * grammar readers, not an independent source of semantic truth; README.md,
 * implementation/RUNTIME_CONTRACT.md, conformance/, and effective Accepted
 * SCPs govern their respective areas.
 * ============================================================
 *
 * NAMING LAW (the only one):
 *   The base Identifier before `[...]` is read by case. A Goal name may carry
 *   an optional codebase hash qualifier after that Identifier:
 *       Something[...]          uppercase -> Goal
 *       Something#7fa31c[...]   uppercase -> hash-qualified Goal
 *       something[...]          lowercase -> map
 *   A map access MUST contain exactly one key: `something[key]`. Empty or
 *   multi-argument lowercase brackets are semantic errors, and a lowercase map
 *   name may not carry a hash qualifier. Goals may retain zero or more arguments.
 *   Leading underscores do not participate in the case test; the first ASCII
 *   letter decides it (`_Build[...]` -> Goal, `_cache[...]` -> map). An
 *   identifier with no letter at all may not take a bracket suffix.
 *   Inside serial or parallel Goal composition only, a bare Identifier whose
 *   first ASCII letter is uppercase is also a Goal stage. This is the sole
 *   bracket-omission shorthand; a bare lowercase Identifier remains a value.
 *   No other casing rule exists in the language.
 *
 * MAP WILDCARD:
 *   `_` is reserved for use as a map key. It is not a general expression and
 *   cannot appear as a pipeline stage, argument, or standalone value.
 *   It is permitted only as the fallback key of an ordinary lookup Map. A
 *   resolving Map that exports parallel branch results MUST use concrete keys;
 *   `_` in a resolving Map is a semantic error because no materialized result
 *   key could satisfy it.
 *   A map may contain at most one `_` entry and may not repeat an explicit key.
 *   An exact explicit-key match always wins, regardless of declaration order;
 *   `_` is selected only when no explicit key matches. Violations are semantic
 *   errors and are not enforced by the grammar.
 *   A bare Identifier key is static shorthand for a String key with the same
 *   spelling; `success` and `"success"` are therefore duplicates. Map keys are
 *   never scope lookups or evaluated expressions. Numeric and String keys are
 *   distinct, so `1` and `"1"` are different keys.
 *   Equality and duplicate detection use normalized structural key forms, not
 *   raw source spelling: `1` equals `1.0`, `0` equals `-0`, and String escapes
 *   are decoded before comparison. String comparison is case-sensitive.
 *
 *   Source text is UTF-8, but Identifiers deliberately remain ASCII:
 *   `[A-Za-z_][A-Za-z0-9_]*`. The ASCII casing law therefore remains portable
 *   and applies equally to Goal names, parameters, `$` Anchor names, `@` policy
 *   names, and bare Identifier map keys. Hash qualifiers also remain ASCII
 *   alphanumeric. Strings contain Unicode scalar values and are never Unicode-
 *   normalized; invalid UTF-8 is a source-decoding error, and canonically
 *   equivalent spellings such as precomposed `é` and `e` plus a combining
 *   accent remain different values. Escape spellings are
 *   decoded before String equality, map-key comparison, or hashing, so source
 *   spellings that decode to the same scalar sequence denote the same String.
 *   `\u{...}` must contain one to six hexadecimal digits and denote a Unicode
 *   scalar value (0..10FFFF excluding D800..DFFF), otherwise validation fails.
 *   Ordinary lookup Maps are selective routing structures. `map[key]` selects
 *   an exact normalized key first, then `_`; only the selected entry participates
 *   in the resulting dependency/value structure. Unselected entries do not. If
 *   neither exists, lookup raises `KeyNotFound`. A statically evident miss is a
 *   validation error; a demand-time miss is a deduction error. A Map literal
 *   is resolving only when it is the direct body of a Goal arrow. Its concrete
 *   keyed entries declare independent Goal branches and explicit key-to-result
 *   relationships. A Map is a value producer, never a Goal stage by itself;
 *   `[A, {x: B, y: C}, D]` is invalid. Wrap it as
 *   `[A, [] -> {x: B, y: C}, D]`, or use a parameterized Goal arrow when
 *   upstream routing is required.
 *
 * NUMBER BOUNDARY:
 *   Subsea has one Number syntax, not separate integer, floating-point, decimal,
 *   or width-specific types. A NUMBER token is only a grammar-validated decimal
 *   string. Subsea does not convert it to a native numeric representation and
 *   defines no precision, range, overflow, rounding, division, modulo, or
 *   division-by-zero behavior. The Host primitive semantics owns all
 *   such conversion and computation semantics, including its result and errors.
 *   This deliberately permits different implementations to realize the same
 *   Goal structure with different numeric models.
 *   Numeric Map keys are the sole structural exception: duplicate detection and
 *   lookup normalize their source text without evaluating a number. Remove
 *   trailing fractional zeroes, remove a now-empty decimal point, and erase a
 *   minus sign from zero. Thus `1`, `1.0`, and `1.00` denote one structural key,
 *   as do `0`, `0.0`, and `-0`. This normalization defines key identity only;
 *   it does not define runtime arithmetic or numeric equality.
 *
 * PRIMITIVE EXPRESSIONS:
 *   Primitive operators are intentional deduction-time conveniences and may be
 *   used in value-expression positions, including Goal arguments:
 *       A = [x] -> B[x + 1]
 *   Carousel requests `x + 1` from Host primitive semantics when that routed
 *   argument is needed. This evaluation creates no Goal node, leaf, or
 *   Scheduler work. Subsea fixes the
 *   operators' syntax, precedence, associativity, and structural evaluation
 *   control such as left-to-right Boolean short-circuiting. A consuming
 *   Host primitive-semantics profile owns operand support and conversion,
 *   numeric representation, exact results, and errors. Consequently
 *   String `+`, mixed-type equality/order, overflow, rounding, division, modulo,
 *   and division by zero are implementation contracts rather than Subsea value
 *   semantics. Every successful result MUST re-enter deduction as a Subsea-
 *   representable value; primitive operator evaluation itself MUST have no
 *   effect.
 *   Because a computed value may select an ordinary Map branch, the unfolded
 *   structure is relative to the source, its input values, and the selected
 *   Host primitive-semantics profile. Every deduction MUST record that profile
 *   and version in provenance. Changing it may affect only future deductions;
 *   no committed deduction is rewritten. Runtime `==` belongs to that Host
 *   profile and is distinct from the fixed structural equality used for
 *   Map-key identity.
 *
 * VALUE-PRODUCING CALL POSITION:
 *   Outside an arrow-function leaf, eager `Goal(...)` and `$anchor(...)` calls
 *   MUST occur as direct structural occurrences: the direct body of a Goal
 *   arrow, a serial or parallel element, or a resolving-Map branch. They
 *   MUST NOT be nested inside Goal or Anchor arguments, policy arguments,
 *   operator operands, lookup keys, or
 *   ordinary value containers. Such a program is `InvalidStructuralContext`;
 *   a Runtime never hoists the call or commits a pending argument placeholder.
 *   Primitive expressions such as `B[x + 1]` remain valid. Inside an arrow-
 *   function leaf, nested Anchor calls are ordinary Host-evaluated function
 *   expressions; Goal calls remain forbidden by the function-leaf boundary.
 *   These placement rules are semantic validation and are not enforced by this
 *   permissive expression grammar.
 *
 * NAME RESOLUTION AND ERROR OWNERSHIP:
 *   Syntactic category is fixed before lookup. A value Identifier searches
 *   innermost lexical scope outward, then top-level non-Goal bindings; Goals
 *   never satisfy value lookup. An unqualified Goal reference is stored as a
 *   symbolic Name/Arity occurrence. A local definition or current codebase
 *   entry may validate that spelling, but does not pin future occurrences.
 *   When an occurrence is demanded, Carousel atomically resolves the then-
 *   current Name/Arity alias, records the selected full ArtifactHash and
 *   codebase revision, applies the reduction rule, and commits the result.
 *   `Name#prefix` instead requires exactly one stored artifact and is expanded
 *   to its full pinned hash before storage. Bare Identifier Map keys perform no
 *   lookup. `$Anchor` and `@policy` names are not resolved by structural
 *   validation, though their arguments still undergo ordinary validation.
 *   No exact Goal match yields `ArityMismatch` when the name exists at other
 *   arities, otherwise `GoalNotFound`. These kinds are validation errors when
 *   statically provable and deduction errors when late alias lookup discovers
 *   them. Qualified lookup yields `HashNotFound` or `AmbiguousHashPrefix` before
 *   `ArityMismatch`.
 *   Error phases are source, validation, deduction, host, and policy. Source
 *   and validation errors invalidate the whole source unit and prevent codebase
 *   commit. `KeyNotFound`, `DestructureMismatch`, cycles, and
 *   `OutputMultiplicityMismatch` for a declaration or resolving-map-branch
 *   contract are validation errors when statically provable and otherwise
 *   deduction errors. `OutputMultiplicityCannotBeInferred` is a validation
 *   error. A Host whose output violates its declared multiplicity reports the
 *   host-phase `OutputMultiplicityMismatch(context = host-emission)`; a `/N`
 *   Host terminal violation reports the host-phase
 *   `HostTerminalProtocolViolation(kind = late-value | duplicate-terminal |
 *   missing-terminal)`. Primitive
 *   semantics are Host-provided; a failure requested while reducing is reported
 *   in the deduction context. Arrow-function and Anchor leaf failures are Host-
 *   owned. Scheduling and upstream outcomes are Scheduler-owned without
 *   exception. Policy existence, applicability and conflicts are resolved
 *   against two declarations: a Scheduler policy registry and a Host capability.
 *   An identifier claimed by the Scheduler is interpreted by the Scheduler; one
 *   claimed by the Host is interpreted by the Host inside a single grounded leaf
 *   invocation; one claimed by both is `PolicyConflict`; one claimed by neither
 *   is `UnknownPolicy` and does not fall back to either side. A failed deduction commits no partial result
 *   and never rewrites any earlier deduction. Each error has a stable kind and
 *   phase; source span, artifact, occurrence, and active lineages are attached
 *   when available.
 *
 * LEXICAL PARAMETERS:
 *   Names must be unique within one Goal parameter list or one destructuring
 *   pattern. Each arrow creates a lexical scope. A nested structural arrow may
 *   shadow a name from an enclosing arrow or the top-level scope. Same-scope
 *   duplicates are semantic errors and are not enforced by the grammar.
 *   Both arrow forms have fixed arity. `[x, y]` and `(x, y)` accept exactly two
 *   values; `[]` and `()` accept none. `[{x, y}]` and `({x, y})` each accept
 *   exactly one Map value and destructure it. Defaults and variadic
 *   parameters are unsupported. Destructuring a non-Map or a Map missing any
 *   requested key raises `DestructureMismatch`; unrequested extra keys are
 *   allowed. A mismatch known from structure is a validation error; otherwise
 *   it is a deduction error.
 *
 * GOAL ARITY:
 *   Source lookup uses (human-readable name, arity, optional hash prefix).
 *   Multiple local Goal definitions may share a name only when their parameter
 *   counts differ; one source unit may define at most one implementation of a
 *   given name/arity. A deferred `Goal[...]` reduction or eager `Goal(...)` call
 *   supplies the lookup arity solely by argument count. Argument values, types,
 *   patterns, and guards never participate in overload selection. Default and
 *   variadic parameters are not supported.
 *   An unqualified reference remains symbolic Name/Arity in the stored artifact
 *   and selects the current alias only when its occurrence is demanded.
 *   `Name#prefix` selects a specific stored ArtifactHash and is expanded to the
 *   full hash before storage. Arity checks are semantic and are not enforced by
 *   the grammar.
 *   Context supplies arguments only for a bare uppercase stage in a composition.
 *   An initial serial stage or a parallel sibling with no upstream value is
 *   Goal/0. A later bare serial stage is Goal/1 and receives the immediately
 *   preceding result as its sole argument. A downstream parallel composition
 *   has the all-bare fan-out shorthand defined below. An explicit `Goal[...]`
 *   receives exactly the arguments written inside its brackets; upstream values
 *   are never inserted, appended, or otherwise merged into that list.
 *
 * BINDING KINDS:
 *   A Binding whose right-hand side is a structural arrow
 *   `[params] -> goal-body` defines a composite Goal. A Binding whose
 *   right-hand side is `(params) -> body` defines a Goal with an arrow-function
 *   leaf implementation. A composite definition may replace `->` with `-0>`,
 *   `-1>` or `-N>` to declare its output multiplicity; a function-leaf
 *   definition always uses `->` and is always `/1`. See OUTPUT MULTIPLICITY.
 *   Both are Goal definitions and their names MUST begin with an uppercase
 *   ASCII letter after leading underscores are ignored. Any other permitted
 *   right-hand side creates an immutable non-Goal value binding. There is no
 *   reassignment. A function arrow is never a value: it cannot be aliased,
 *   passed, returned, stored in a Map, or placed in a composition or argument.
 *   A String binding remains an ordinary value and has no special location or
 *   import meaning. Host Anchors never resolve through String bindings: `$`
 *   accepts only an Identifier, which the Host resolves through an external
 *   registry. A Host Anchor itself may never
 *   be bound directly (`name = $host` is invalid), though invoking one may
 *   produce a value that participates in a larger expression. These rules are
 *   semantic and are not enforced by the grammar.
 *
 * CALLABILITY:
 *   There are exactly two value-producing call forms. `Goal(...)` eagerly
 *   evaluates a Subsea Goal selected by Name/Arity; `$anchor(...)` invokes a
 *   Host-resolved Anchor. Outside a function leaf, either form must be a direct
 *   structural occurrence; nesting it in a value expression is invalid.
 *   A lowercase value identifier followed by `(...)` is invalid. Maps,
 *   pipelines, grouped expressions, call results, and all other values are not
 *   callable. Calls cannot be chained, and callable values do not exist.
 *   Inside an arrow-function leaf implementation, every Subsea Goal call is
 *   forbidden at any depth; only Host Anchor calls written with `$` are
 *   permitted.
 *
 * STRUCTURAL ARROWS VS FUNCTION ARROWS:
 *   `[params] -> goal-body` is a Goal arrow: it defines structural Goal
 *   reduction and may appear inline where Goal structure is required. Its
 *   single-Map destructuring form is `[{x, y}] -> ...`; for example,
 *   `[{x, y}] -> [T1[y], T2[x]]` explicitly routes resolving-map results.
 *   `(params) -> body` is an arrow function, but only as the complete right-hand
 *   side of a named Goal binding such as `Add = (x, y) -> x + y`. It is
 *   not an expression and can never occur inline or between pipeline stages.
 *   Its body is terminal reduction content and MUST NOT contain a structural
 *   arrow, serial/parallel/resolving Goal composition, deferred Goal reference,
 *   or eager Subsea Goal call at any depth. It may use literals, parameters,
 *   operators, ordinary Maps/lookups, and Anchor calls such as `$Plus(x, y)`.
 *   Anchor calls inside the implementation do not create Subsea Goal nodes.
 *       Leaf = ({x, y}) -> { $C(x); $D(y) }   valid
 *       Leaf = (x) -> C(x)                    invalid: Subsea Goal call
 *       [A, (x) -> x + 1, B]                  invalid: inline function arrow
 *   Function parameters are either a comma-separated Identifier list or one
 *   scope-destructuring pattern. Thus `(x, y)` has arity 2, while `({x, y})`
 *   has arity 1 and destructures its single input.
 *   A function composite `{ first; second; ... }` is available only inside that
 *   named leaf implementation. It declares strict left-to-right dependencies,
 *   does not forward non-final values, and exposes the final expression's value.
 *   It is neither a Map nor a parallel Goal composition; `;` has no meaning
 *   outside this composite. Error handling remains Scheduler policy.
 *
 * GOAL BODY VALIDITY:
 *   A Goal arrow body MUST be reduction structure, never a bare primitive or
 *   computed value. Its direct forms are: a deferred/eager Goal reference, an
 *   Anchor leaf/reference call, another Goal arrow, serial composition, unkeyed
 *   parallel composition, a resolving Map, or an ordinary Map lookup whose
 *   selectable results are all valid Goal structure. Goal arguments may still
 *   contain ordinary value expressions.
 *   A bare Anchor is an Anchor/0 leaf; enclosing Goal parameters are never
 *   forwarded implicitly. `$host` and `$host()` are the same zero-argument
 *   occurrence. Signature compatibility and resolution belong entirely to the
 *   Host, not structural validation.
 *       Value = [x] -> 42          invalid: primitive body
 *       Zero  = [x] -1> $host      valid: Anchor/0; x is unused
 *       Call  = [x] -1> $host(x)   valid: Anchor/1
 *       Bad   = [x] -> (y) -> y    invalid: function arrow is never inline
 *   Serial and parallel elements obey the same structural restriction. A Map
 *   literal may appear there only behind a Goal arrow as defined above.
 *
 * SERIAL AND PARALLEL GOAL COMPOSITION:
 *   `[A, B]` is serial composition: B depends on A and receives A's result as
 *   its upstream input. `{A, B}` is parallel composition: it creates no
 *   dependency edge between A and B, so a Scheduler may run them concurrently.
 *   Braces permit concurrency but do not require simultaneous execution.
 *   A bare initial/parallel Goal denotes Goal/0. A bare downstream serial Goal
 *   denotes Goal/1 and receives only the preceding result. Explicit brackets
 *   disable that shorthand: `[A[x], B[y]]` still orders B after A, but B receives
 *   only y and A's result is discarded. To forward or augment the upstream
 *   value, use an explicit Goal-arrow stage:
 *       [A[x], [Aresult] -> B[Aresult, y]]
 *   No implicit argument insertion or expansion occurs. Commas therefore mean
 *   serialization inside `[...]`, parallel sibling placement inside `{...}`,
 *   and Map entry separation only when paired with `:`. Semicolons occur only
 *   in a function composite.
 *
 * UPSTREAM FAN-OUT:
 *   A parallel composition in a downstream serial position has exactly two
 *   valid modes. In implicit fan-out mode, EVERY branch expression
 *   is a bare uppercase Goal and resolves to Goal/1; each upstream Value is
 *   routed as the sole argument to every branch:
 *       [A, {B, C}]
 *         == [A, [i] -> {B[i], C[i]}]
 *   If any bare branch lacks a unary implementation, or if any branch needs other
 *   arguments, the shorthand is invalid. The author MUST make the whole routing
 *   explicit with an inline Goal arrow:
 *       [A, [i] -> {B[i], C[i, y]}]
 *       [A, [i] -> {B[y], C[i]}]
 *   In explicit mode, no branch is bare and every branch writes its own argument
 *   list; the upstream value is not routed into the parallel composition:
 *       [A, {B[a], C[b]}]
 *   Mixing bare implicit branches with explicit branches is a semantic error.
 *   This shorthand never applies to a resolving Map because a Map cannot occupy
 *   a composition slot. Wrap keyed branches in a Goal arrow and route explicitly:
 *       [A, [i] -> {x: B[i], y: C[i]}]
 *   A zero-parameter wrapper may deliberately ignore upstream output:
 *       [A, [] -> {x: B, y: C}]
 *
 * CONDITIONAL STRUCTURAL PIPELINE:
 *   `[selector, {key: GoalBranch, ...}]` evaluates one effect-free selector
 *   expression through Host primitive semantics and exposes exactly the branch
 *   selected by normalized Map-key rules. Exact keys precede `_`; no match is
 *   `KeyNotFound`. The branch Map is contextual structure, not an ordinary Map
 *   value or resolving Map. The selector may contain parameters, immutable
 *   values, literals, ordinary value lookups, and primitive operators, but no
 *   Goal or Anchor occurrence/call. Every branch is validated, while only the
 *   selected branch creates occurrences or performs demand-time observations.
 *   The selected branch's output is the conditional Pipeline's output.
 *
 * COMPOSITION OUTPUT:
 *   A serial composition contains at least two elements and exports the Values
 *   of its final element. Earlier results are discarded unless explicitly
 *   routed. Bare `[]` and singleton `[A]` are not expressions; `[] -> ...`
 *   remains the zero-arity Goal-arrow form, and `Goal[]` remains a
 *   zero-argument deferred Goal reference.
 *   A routed stage runs once for every Value its predecessor emits, so a serial
 *   composition's output multiplicity follows the composition rule in OUTPUT
 *   MULTIPLICITY rather than its final element alone: `[A/N, B/1]` exports N
 *   Values. A stage whose argument tuple is fully explicit consumes no upstream
 *   Value, runs once after its predecessor completes, and resets the
 *   multiplicity to its own.
 *   An unkeyed parallel composition also contains at least two elements and has
 *   effective multiplicity `/0`: it publishes no outward Value whatever its
 *   branches produce. Singleton `{A}` is invalid. `{}` remains an ordinary empty
 *   Map value, not parallel composition.
 *   A `/0` predecessor invokes a routed successor zero times and its empty
 *   segment completes normally:
 *       [{A, B}, C[]]         valid: runs once after {A, B}; C/0
 *       [{A, B}, C[y]]        valid: y comes from lexical scope
 *       [{A, B}, C]           valid: C is invoked zero times; the whole is /0
 *       [{A, B}, [x] -> C[x]] valid: no parameter is bound; the whole is /0
 *   `NoOutput` survives only as the internal absence of a scalar that a
 *   resolving-map binding or function-leaf body explicitly requires; there it
 *   still reports `NoOutputNotRoutable`. It has no source literal and is not
 *   `null`, unit, or an empty Map.
 *
 * PARALLEL RESULT EXPORT:
 *   Unkeyed parallel composition `{A, B}` exports no downstream value. When it
 *   precedes another serial element, the structure contains a dependency from
 *   the composite node to that element, but the language does not define when
 *   the composite is considered satisfied. Goal names are never synthesized
 *   into result keys. A following bare unary Goal or parameterized arrow is
 *   invoked zero times, as COMPOSITION OUTPUT shows.
 *   To export branch results, the author MUST make a resolving Map the direct
 *   body of a Goal arrow:
 *       [[] -> {x: A, y: B}, [{x, y}] -> [C[x], D[y]]]
 *   Its entries are independent branches and expose one immutable Map-shaped
 *   result `{x: resultOfA, y: resultOfB}`. That single value may be
 *   scope-destructured by the following Goal arrow. Only explicitly
 *   written concrete keys are exported; wildcard `_` is forbidden here, and
 *   `{A, B}` can never provide values for `[{x, y}]`.
 *   A resolving Map itself is never adjacent to Goals in a composition. Each
 *   branch MUST have effective multiplicity exactly `/1`, and the Map and a
 *   Goal arrow whose direct body it is are `/1`. A `/0` or `/N` branch reports
 *   `OutputMultiplicityMismatch(expected = /1, context = resolving-map-branch)`
 *   even when one invocation would happen to emit a single Value; no first
 *   Value is chosen, no Values are collected, and no key is omitted.
 *   A singleton resolving Map such as `[] -> {x: A}` is valid. Empty `{}` is
 *   always an ordinary Map value and never a resolving Map.
 *
 * SCHEDULER POLICY BOUNDARY:
 *   The language defines dependency edges, serial/parallel independence, value
 *   routing, and explicit result keys only. It does NOT define success criteria,
 *   failure propagation, all/any/quorum completion, retries, cancellation,
 *   timeouts, fire-and-forget behavior, or error aggregation. Those belong to
 *   the Scheduler. A Scheduler may make a dependent evaluation instance
 *   eligible only when its policy considers the upstream structure satisfied
 *   and every value required by that instance has been supplied accordingly.
 *
 * BOOLEANS:
 *   `true` and `false` are reserved Boolean literals and cannot be rebound as
 *   Identifiers. There is no truthiness conversion: `!`, `&&`, and `||` require
 *   Boolean operands, and equality/comparison operations produce Booleans.
 *   Boolean Map keys are distinct from String keys, so `true` and `"true"` do
 *   not collide.
 *   `&&` and `||` short-circuit from left to right. `false && rhs` and
 *   `true || rhs` do not select the right operand, so any eager Goal or Anchor
 *   call contained only in that operand does not participate in the resulting
 *   dependency/evaluation structure. This is Boolean value-selection semantics,
 *   not a success or failure policy; execution policy remains with the Scheduler.
 *
 * TOP-LEVEL BINDINGS:
 *   The top level is one order-independent scope. Forward references are valid,
 *   A non-Goal name may be bound exactly once. Local Goal definitions of either
 *   implementation kind may share a base name only across distinct arities.
 *   A Goal and a non-Goal binding may not share a base name. Rebinding,
 *   reassignment, same-name/same-arity Goal definitions, and
 *   last-declaration-wins behavior do not exist.
 *   Violations are semantic errors and are not enforced by the grammar.
 *   A direct or mutual definition cycle is valid only as guarded recursion.
 *   Every cycle in its local Goal-definition component MUST cross a recursive
 *   reference inside a conditional branch Map, and that Map MUST have at least
 *   one branch that exits the component. An unconditional cycle, or a
 *   conditional component with no exit branch, is `CycleDetected`.
 *   Selecting a recursive branch creates a fresh child occurrence rather than
 *   a back-edge to an ancestor occurrence. Validation does not prove that a
 *   particular input terminates.
 *
 * OUTPUT MULTIPLICITY:
 *   Every Goal has an output multiplicity of exactly `/0`, `/1` or `/N`. It is
 *   part of the Goal's StructureHash but not of the `Name/Arity` lookup key and
 *   is never an overload axis. A named Goal's plain `->` means infer; it never
 *   defaults to `/1`. Where inference cannot be unique, the named definition
 *   declares its contract with `-0>`, `-1>` or `-N>`. Only a named Goal's
 *   complete structural definition `[params] -> ...` may use those arrows. A
 *   function-leaf definition keeps `->` and is always `/1`, and an inline Goal
 *   arrow keeps `->` and takes its body's multiplicity.
 *       Add          = (a, b) -> a + b                  inferred /1
 *       FanOut       = [x] -> {A[x], B[x]}              inferred /0
 *       Print        = [x] -0> $PrintLn(x)              declared /0
 *       Eratosthenes = [limit] -N> $Eratosthenes(limit) declared /N
 *   Inference may use a pure scalar function-arrow result (`/1`), the composite
 *   rules below, an explicit or uniquely inferred signature in the same source
 *   unit, and the signature of a hash-qualified artifact. It MUST NOT use the
 *   artifact an unqualified alias currently selects, a Host registry or
 *   capability snapshot, observed output counts, the branch one execution
 *   selected, or Scheduler policy, placement, or timing.
 *   Serial routing composes an upstream and a downstream multiplicity: `/0`
 *   absorbs on either side, `/1` is the identity, and otherwise the result is
 *   `/N`. A downstream `/0` fixes the composite at `/0` even when the upstream
 *   multiplicity is unknown. A conditional whose branch multiplicities are all
 *   known joins them: all `/0` gives `/0`, all `/1` gives `/1`, any other mix
 *   gives `/N`; an unknown branch needs an explicit arrow on the containing
 *   named Goal. An unkeyed parallel composite is `/0`; a resolving Map is `/1`.
 *   An inferred contract never pins an unqualified child, which stays a symbolic
 *   Name/Arity occurrence until demand. When inference is not unique, validation
 *   reports `OutputMultiplicityCannotBeInferred` with reason
 *   `opaque-host-output`, `external-symbolic-reference`,
 *   `recursive-signature-cycle` or `unknown-conditional-branch`. Which reason
 *   is reported when more than one cause applies to one definition is not yet
 *   specified. An explicit
 *   arrow is a checked contract, not an override: a disagreement reports
 *   `OutputMultiplicityMismatch(context = goal-declaration)`. A multiplicity
 *   arrow on a Goal whose body is a direct `$Anchor` output is accepted as the
 *   Host contract; the Host is held to it at emission.
 *
 * ONE PROGRAM, ONE ROOT:
 *   A program contains exactly one `root` declaration naming its default laid
 *   target as a symbolic signature reference:
 *       root Eratosthenes/1
 *       root Eratosthenes#ab12/1
 *   The GoalName's base Identifier begins with an uppercase ASCII letter and may
 *   be hash-qualified; the integer after `/` is input arity only. There is no
 *   argument position, so no input can be written in the Root. `root` is a
 *   contextual keyword: it is recognized only at the start of a statement
 *   followed by a GoalName, so `root = ...` remains an ordinary Binding. Any
 *   other leading word, or an arity that is not a non-negative integer
 *   spelling, is a SyntaxError.
 *   The declaration evaluates nothing, supplies no input, resolves no alias,
 *   creates no occurrence, and lays no Cable. A caller that lays the stored
 *   Voyage Plan lays this target by default. Any top-level statement that is
 *   neither a Binding nor the `root` declaration — including the former
 *   input-bearing Root form `Eratosthenes[50]` — is `InvalidRoot`, as is a
 *   program with no `root` declaration or with more than one.
 *
 * GOAL DAG:
 *   Demand-driven deductions materialize the structure reachable from each
 *   admitted input segment's Root occurrence of the laid target as
 *   a directed acyclic graph (DAG), not necessarily a tree. The complete future
 *   graph is not frozen in advance: an undeduced unqualified occurrence still
 *   observes a mutable alias when demanded. Source expressions are tree-shaped,
 *   but occurrences that select the same resolved Goal definition/arity
 *   designate one structural Goal node and add incoming edges to it; they do not
 *   clone that node. Occurrences that select different hashes remain different
 *   nodes. Serial/parallel placement, argument routing, and resolving keys
 *   belong to edges and composite structure. Guarded recursive definitions
 *   unfold as fresh child occurrences, so the realized occurrence graph stays
 *   acyclic even when multiple occurrences share a recursive GoalNodeId.
 *   Unguarded definition cycles remain invalid.
 *   Node sharing alone does not combine incoming values or create an all-parent
 *   barrier. Each edge retains its own routing and may produce a separate
 *   evaluation instance. Multiple upstream results feed one instance only when
 *   an explicit structure such as a resolving Map combines them.
 *
 * GOAL NODE IDENTITY, LINEAGE, AND EVALUATION:
 *   Before deduction, an unqualified occurrence has stable occurrence identity
 *   but no selected GoalNodeId. Deduction resolves its alias and commits the
 *   selected artifact. GoalNodeId is that artifact's policy-erased StructureHash
 *   plus arity, independent of parent, occurrence, lineage, and argument values.
 *   The definition node is structurally shared while deduction and evaluation
 *   remain occurrence/argument-sensitive. Deferred `Goal[...]` and eager
 *   `Goal(...)` references share a GoalNodeId only when they select the same
 *   artifact; their suffix changes demand/evaluation timing, not post-resolution
 *   identity. A lineage path is one Root-to-occurrence traversal, not node identity or
 *   memoization key. A node with multiple incoming paths carries multiple
 *   lineages. Deduction extends every incoming lineage across committed outgoing edges:
 *       PrepareOrder[10, {..}]
 *         deduces the explanatory projection
 *       { PrepareOrder/2.GetUserInfo/1[10],
 *         PrepareOrder/2.ValidateOrder/1[{..}] }
 *   The dotted `Name/Arity` form is human-readable explanatory pretty-printing
 *   of one lineage,
 *   NOT `.vyg` syntax, a reparsable deduction output, or a unique address.
 *   For example, `Root/0.B/1.D/1` and `Root/0.C/1.D/1` are two lineages of the
 *   same structural D/1 node when B and C both reduce to D. Values such as leaf
 *   parameters, map values, and literals remain lexically scoped and inherit
 *   the active lineage set as context.
 *   Evaluation is separate from expansion: one structural Goal node may have
 *   multiple evaluation instances, distinguished by their routed argument
 *   tuples. Structural sharing does not prescribe execution-result caching or
 *   coalescing; those remain Scheduler policy. Each instance carries the active
 *   lineage or lineages that actually contributed its routed inputs, while the
 *   structural node's lineage set is their union.
 *   Distinct source occurrences remain distinct even when they point to the
 *   same GoalNodeId with the same routed arguments. For example,
 *   `{Goal1, Goal1}` contains two sibling occurrences and two edges to one
 *   shared Goal1/0 node. The structure is therefore a directed acyclic
 *   multigraph. Each occurrence/edge has stable identity so lineage and policy
 *   attachment can distinguish duplicates. Whether identical evaluation work
 *   is physically coalesced remains Scheduler policy.
 *   A conditional structural pipeline selects one Goal branch from a pure
 *   value during deduction. Only that branch enters the occurrence graph. The
 *   Host primitive profile, selector value, selected key, and occurrence
 *   provenance make this data-dependent expansion auditable.
 *
 * LEAVES (exactly two kinds):
 *   Successive deductions bottom out in either an arrow-function leaf belonging
 *   to a named Goal or an Anchor leaf. Both are Host-provided computation: the
 *   Host evaluates an arrow body and resolves/invokes an opaque `$Anchor`. An arrow
 *   function cannot be hidden in or transported through a value; its enclosing
 *   Goal supplies its Name/Arity and active lineages.
 *   There are NO native effects. `$identifier` marks an opaque Host-resolved
 *   Anchor. Subsea supplies the Identifier, explicit arguments/arity, occurrence
 *   identity, and active lineages, but neither locates nor validates the Host
 *   implementation. The Anchor is never structurally reduced.
 *
 * ANCHORING POLICY:
 *   `@policy` prefixes attach How metadata to exactly the following structural
 *   occurrence. They never change dependency topology, GoalNodeId, arguments,
 *   or result routing. Stacked prefixes attach an ordered policy list to the
 *   same target. Policy-specific meaning, argument schema, same-addressee
 *   composition, and execution belong to the addressee the two declarations
 *   resolve. The Runtime policy phase owns resolution, cross-addressee
 *   collisions, target enforcement, and the forwarding allowlist; an identifier
 *   neither declaration claims is `UnknownPolicy`. Policies never inherit or
 *   copy to descendants. Only interpretation inside one grounded leaf invocation
 *   ever moves to the Host; eligibility, the attempt lifecycle, and scope
 *   outcomes stay with the Scheduler.
 *       @retry Goal1
 *       @retry @atLeastOnce $foo
 *       @timeout("30s") {Goal1, Goal1}
 *   A policy on a shared Goal reference belongs to that occurrence/edge and its
 *   lineage, never to the shared Goal definition or node. Erasing all policy
 *   annotations yields the same structural projection. StructureHash therefore
 *   excludes policies. ArtifactHash identifies the complete authored term and
 *   MUST include its ordered policy projection.
 *
 * CODEBASE AND HOST ANCHOR:
 *   A Host Anchor uses only `$Identifier`; its registry and resolution live
 *   outside Subsea source. It is never a codebase Goal reference.
 *   Subsea has no import, export, package, module, or visibility construct.
 *   Every named Goal definition in a valid source unit is stored in an abstract
 *   content-addressed codebase, including definitions unreachable from the
 *   `root` target. That declaration only names the default laid target; the
 *   Root occurrence of each admitted input segment is that segment's first
 *   deduction demand. The codebase backend may be a file
 *   store, database, distributed service, or any implementation of the same
 *   lookup contract.
 *   ArtifactHash is the identity of one stored authored Goal term, including its
 *   policy projection; policy-erased StructureHash is used for structural node
 *   sharing. The current name index maps (human-readable name, arity) to one
 *   ArtifactHash while retaining older hashes and observable revisions. Names
 *   are mutable indexes, never identity. Stored unqualified Goal references
 *   retain symbolic Name/Arity and resolve only when their occurrences are
 *   demanded. The successful deduction records the chosen full hash and
 *   codebase revision and can never be retargeted. `Name#prefix` is expanded to
 *   one pinned full hash before storage for exact historical selection.
 *   A name may NOT be bound directly to an anchor (semantic rule, not syntactic):
 *       Add = [a,b] -1> $plus(a,b)  OK  — a real goal reducing to a leaf
 *       Add = (a,b) -> a + b        OK  — a named Goal with a function leaf
 *       Add = $plus                 FORBIDDEN — a leaf disguised as a goal
 *   An Anchor leaf must be reached through structural Goal reduction; only the
 *   dedicated function-arrow binding form may give a Goal a direct leaf
 *   implementation.
 * ============================================================
 */

// ------------------------------------------------------------
// 1. Parser Rules (Syntax Rules)
// ------------------------------------------------------------

// Synthesized by the required lexical preprocessor (see NOTE); the lexer never
// emits them directly.
tokens { MULTIPLICITY_ARROW, ROOT, ROOT_ARITY }

// Syntax admits a general statement list; semantic validation requires exactly
// one `root` declaration and rejects any other non-Binding statement as
// `InvalidRoot` (see ONE PROGRAM, ONE ROOT). The file must be fully parsed to EOF.
program
    : TERMINATOR? statementList EOF
    ;

statementList
    : statement (TERMINATOR statement)* TERMINATOR?
    ;

statement
    : rootDeclaration
    | binding
    | expression
    ;

// `root` is contextual: the preprocessor forms ROOT and ROOT_ARITY only in
// this position (see NOTE and ONE PROGRAM, ONE ROOT).
rootDeclaration
    : ROOT goalName '/' ROOT_ARITY
    ;

/* --- Bindings --- */
binding
    : IDENTIFIER '=' functionLeafImplementation
    | IDENTIFIER '=' declaredGoalArrow
    | IDENTIFIER '=' expression
    ;

// A function arrow is syntax only for a named Goal's leaf implementation. It
// is not an Expression and therefore cannot appear as a value anywhere else.
functionLeafImplementation
    : fnParams '->' fnBody
    ;

// A named composite Goal that declares its output multiplicity. Plain `->`
// definitions stay ordinary goalArrow expressions and infer it.
declaredGoalArrow
    : goalParams MULTIPLICITY_ARROW goalBody
    ;

/* --- Expressions --- */
expression
    : goalArrow
    | logicalOr
    ;

goalArrow
    : goalParams '->' goalBody
    ;

goalBody
    : policyPrefix* goalBodyCore
    ;

goalBodyCore
    : goalReference
    | hostAnchor
    | goalArrow
    | serialPipeline
    | parallelComposition
    | resolvingMap
    ;

// A direct Goal body is not a contextual composition position, so a bare Goal
// name is not shorthand here. Lowercase bracket form is an ordinary Map lookup;
// uppercase bracket/paren forms are deferred/eager Goal references. Case and
// arity constraints remain semantic.
goalReference
    : goalName (bracketSuffix | callSuffix)
    ;

// A hash qualifier is an authoring-time codebase lookup hint. Resolution
// replaces it with the full ArtifactHash before the Goal term is stored. Without
// a qualifier, Name/Arity remains symbolic until each occurrence is demanded.
goalName
    : IDENTIFIER HASH_QUALIFIER?
    ;

// `@policy` prefixes are transparent structural annotations. Their argument
// list is policy data; they target exactly the following structural occurrence.
policyPrefix
    : '@' IDENTIFIER callSuffix?
    ;

// `$name` marks an opaque Host-resolved Anchor. Only an Identifier is allowed;
// location strings and Host registry entries live outside Subsea source.
hostAnchor
    : '$' IDENTIFIER callSuffix?
    ;

goalParams
    : '[' (paramList | scopeDestructure)? ']'
    ;

fnParams
    : '(' (paramList | scopeDestructure)? ')'
    ;

// A function composite exists only in a named Goal's leaf implementation. It is
// sequential value-level evaluation, not a map and not a parallel Goal
// composition. It contains at least two expressions; the optional final
// semicolon does not add another expression.
fnBody
    : expression
    | functionComposite
    ;

functionComposite
    : '{' expression ';' expression (';' expression)* ';'? '}'
    ;

paramList
    : param (',' param)* ','?
    ;

param
    : IDENTIFIER
    ;

scopeDestructure
    : '{' destructureFieldList? '}'
    ;

destructureFieldList
    : IDENTIFIER (',' IDENTIFIER)* ','?
    ;

/* --- Core Operators (Precedence & Associativity) --- */
logicalOr
    : logicalAnd ('||' logicalAnd)*
    ;

logicalAnd
    : equality ('&&' equality)*
    ;

equality
    : comparison (('==' | '!=') comparison)?
    ;

comparison
    : additive (('<=' | '>=' | '<' | '>') additive)?
    ;

additive
    : multiplicative (('+' | '-') multiplicative)*
    ;

multiplicative
    : unary (('*' | '/' | '%') unary)*
    ;

unary
    : '!' unary
    | '-' unary
    | policyValue
    | postfix
    ;

// Policies may decorate a value-producing Goal/Anchor occurrence. Outside a
// function leaf that call must still occupy a direct structural position;
// nesting it in another value expression is InvalidStructuralContext. Pure
// literals and operator results are not policy targets.
policyValue
    : policyPrefix+ (goalName (bracketSuffix | callSuffix) | hostAnchor)
    ;

postfix
    : goalName (bracketSuffix | callSuffix)?
    | hostAnchor
    | nonIdentifierPrimary
    ;

// The two suffix forms carry DIFFERENT semantics, not just different brackets:
//
//   Goal[n]  (bracket suffix) is NOT "evaluate this". It creates a deferred
//            Goal occurrence. If unqualified, its Name/Arity remains symbolic
//            until that exact occurrence is demanded for deduction. Deduction
//            then selects a hash, applies its reduction rule, and commits.
//
//   Goal(n)  (paren suffix) IS an eager call/evaluation when it is a direct
//            structural occurrence: demand it now, deduct it through its
//            pipeline, and yield a value. It obeys the same demand-time alias
//            resolution and commit law. Nested use outside a function leaf is
//            InvalidStructuralContext rather than implicit staging.
//
// Square brackets are restricted to a bare identifier so the naming law is
// always defined. Leading underscores are ignored and the first ASCII letter
// decides case; an identifier without a letter may not use this suffix. A
// semantic validator requires exactly one argument for a lowercase map access.
// Parentheses are available only on a bare Identifier, Host Anchor, or policy.
// Semantic validation further restricts ordinary Identifier calls to eager
// uppercase Goal calls and forbids Subsea Goal calls inside leaf implementations.
bracketSuffix
    : '[' argList? ']'
    ;

callSuffix
    : '(' argList? ')'
    ;

argList
    : expression (',' expression)* ','?
    ;

/* --- Primary --- */
nonIdentifierPrimary
    : serialPipeline
    | parallelComposition
    | map
    | group
    | NUMBER
    | BOOLEAN
    | STRING_LITERAL
    ;

serialPipeline
    : '[' (pipelineStageList | conditionalStage) ']'
    ;

pipelineStageList
    : goalStage ',' goalStage (',' goalStage)* ','?
    ;

// One effect-free selector expression followed by a keyed structural branch
// Map. The selector is evaluated through Host primitive semantics; exactly one
// branch enters the realized structure. The Map is contextual structure, not
// an ordinary value Map or a resolving Map. Semantic validation forbids Goal
// and Anchor occurrences/calls anywhere in the selector. This alternative has
// exactly two elements (plus an optional trailing comma). Continue serially by
// nesting it as one stage: `[[selector, {...}], Next]`.
conditionalStage
    : logicalOr ',' conditionalBranchMap ','?
    ;

conditionalBranchMap
    : '{' conditionalBranchEntry (',' conditionalBranchEntry)* ','? '}'
    ;

conditionalBranchEntry
    : mapKey ':' goalStage
    ;

goalStage
    : policyPrefix* goalStageCore
    ;

goalStageCore
    : goalName (bracketSuffix | callSuffix)?
    | hostAnchor
    | goalArrow
    | serialPipeline
    | parallelComposition
    ;

// Comma-separated braces without ':' are independent Goal siblings. Requiring
// at least two expressions keeps '{}' unambiguously available as the empty Map.
parallelComposition
    : '{' goalStage ',' goalStage (',' goalStage)* ','? '}'
    ;

// A resolving Map is a non-empty keyed value producer available only as the
// direct body of a Goal arrow. Each entry is an independent Goal branch.
resolvingMap
    : '{' resolvingMapEntry (',' resolvingMapEntry)* ','? '}'
    ;

resolvingMapEntry
    : mapKey ':' goalStage
    ;

map
    : '{' mapEntryList? '}'
    ;

mapEntryList
    : mapEntry (',' mapEntry)* ','?
    ;

mapEntry
    : mapKey ':' expression
    ;

mapKey
    : '-'? NUMBER
    | BOOLEAN
    | WILDCARD
    | STRING_LITERAL
    | IDENTIFIER
    ;

group
    : '(' expression ')'
    ;


// ------------------------------------------------------------
// 2. Lexer Rules (Raw Token Definitions)
// ------------------------------------------------------------

WILDCARD : '_';

// Human-readable source may pin a codebase Goal with `Name#hashPrefix`.
// The codebase validates prefix length, alphabet, uniqueness, and algorithm.
HASH_QUALIFIER
    : '#' [a-zA-Z0-9]+
    ;

BOOLEAN
    : 'true'
    | 'false'
    ;

IDENTIFIER
    : IDENT_START IDENT_REST*
    ;

fragment IDENT_START : [a-zA-Z_];
fragment IDENT_REST  : [a-zA-Z0-9_];

// A validated numeric spelling only. Its runtime representation and all
// arithmetic semantics belong to the consuming implementation.
NUMBER
    : INT_PART FRAC_PART?
    ;

fragment INT_PART  : '0' | [1-9] [0-9]*;
fragment FRAC_PART : '.' [0-9]+;

STRING_LITERAL
    : '"' STRING_CHAR* '"'
    ;

fragment STRING_CHAR
    : ~["\\\r\n]
    | ESCAPE_SEQ
    ;

fragment ESCAPE_SEQ
    : '\\' ['"nrt\\]
    | '\\u{' HEX_DIGIT HEX_DIGIT? HEX_DIGIT? HEX_DIGIT? HEX_DIGIT? HEX_DIGIT? '}'
    ;

fragment HEX_DIGIT : [0-9a-fA-F];

TERMINATOR
    // Physical newline token. The required lexical preprocessor decides
    // whether it survives as a logical statement terminator.
    : ( '\n' | '\r\n' )+
    ;

// ------------------------------------------------------------
// 3. Skip & Hidden Channels (Whitespace and Comment Handling)
// ------------------------------------------------------------

WHITESPACE
    : [ \t]+ -> channel(HIDDEN)
    ;

LINE_COMMENT
    // The terminating newline is deliberately excluded and remains available
    // to the lexical preprocessor.
    : '//' ~[\r\n]* -> channel(HIDDEN)
    ;

BLOCK_COMMENT
    // The whole token, including internal newlines, becomes one ordinary
    // whitespace boundary. Internal newlines never become TERMINATOR tokens.
    // Nesting is forbidden; the first following `*/` closes the token.
    : '/*' .*? '*/' -> channel(HIDDEN)
    ;
