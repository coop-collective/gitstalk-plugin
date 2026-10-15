# Handling reds, conflicts and decision cards

Contents: how landing works; when a verdict reaches you; red; recheck (a clash with a bean you
never saw); inherited red; conflict; reverted or dropped; decision cards; hygiene.

## How landing works

A pushed bean is squashed onto the current sprout and the **pre-land check** runs the test
suite on that result. Green lands it on the sprout; a validator later promotes the sprout to
the stalk. A green bean may be re-checked if beans landed on the same files meanwhile. A bean
that breaks a later validation is **reverted** from the sprout. Other agents' landed work is
real: build on it, never undo it.

## When a verdict reaches you

You pushed without waiting and moved on; the verdict arrives on the status ref
(`references/push-flow.md`). A red or conflict is yours: the bean waits for its author's next
push. Commit (or stash) the work in progress, `git switch bean/<name>`, handle it as below,
push it, then switch back to what you were doing. A child you stacked on it moves with it
(`git rebase --onto bean/<name> <old head>`).

## Red

1. Read the failing test file and name, the landed bean you collided with, and its intent.
2. `git fetch origin sprout && git rebase origin/sprout`; run the failing tests locally.
3. Fix the **code**. If your change intentionally alters another existing test's expected
   value, update that test and say so in the commit message. Never touch a protected
   acceptance test; if one contradicts your intent, that is a clash of intents: read the other
   bean's intent, keep both, or ask via the collaboration tools. Never skip or weaken tests.
4. Push again (`git push -f origin HEAD:refs/heads/bean/<name>`). An empty failure list means the suite failed before naming tests
   (build error or timeout): run build and tests locally.
5. After three failed rounds on the same failure, stop, say what you tried, and ask a person.

## Recheck: a clash with a bean you never saw

When the repository's `.gitstalk/policy.yml` routes code to `triage`, Clef also compares your
bean's intent with beans you could not have read: beans that landed on the sprout after you
forked, and beans pushed earlier that are still being checked. If Clef is at least 50% sure the
two clash (a unit, format, meaning or value both rely on), your push comes back as an ordinary
**red**, not a person's hold:

```
remote: gitstalk: approval rules: checkout -> recheck (clef, p=0.66)
remote: gitstalk: back to its author: recheck against price-dollars
remote: gitstalk: RED: shipping was not landed. Merged onto the sprout, these tests failed:
remote: gitstalk:   - .gitstalk/policy.yml > recheck against beans that landed after it forked
remote: gitstalk:     price-dollars: Price in dollars, not cents
remote: gitstalk:       imports: src/checkout.mjs -> src/price.mjs
remote: gitstalk:       it changed, you use: price
remote: gitstalk:     Intent-checked: price-dollars
```

Each named bean shows its intent and the link Clef found (an import, a name it changed that you
use). One still in check is labelled `(pushed before this one, still being checked)`.

1. Read the named bean: `git fetch origin sprout && git log origin/sprout` (find its commit,
   `git show` it) if it landed; `git fetch origin bean/<name>` then `git show FETCH_HEAD` if it
   is in flight.
2. Compare the two intents. If they disagree (it now returns dollars, you assumed cents), fix
   **your** bean so both hold, and add a test for the combination when you can.
3. Either way, rebase on `origin/sprout` and push again with the trailer
   `Intent-checked: <bean>[, <bean>]` in the bean's commit message (`git commit --amend`, or the
   new commit's message). It removes those beans from the comparison; the tests then decide.
4. Never edit, revert or force-push the other bean. If its intent looks wrong, say so to your
   person or on the bean's thread (`bean_thread_post`) instead.

Add the trailer only after you have read the bean: it tells Clef you checked, and from then
on only the tests guard that combination.

## Inherited red

The sprout was already red on that test before your change (`inherited: true`). It is not
your bug. Do not fix it unless asked; wait for the sprout to move
(`git fetch origin sprout`), rebase, push again.

## Conflict

The remote lists files, hunks and the beans that landed them. Rebase on `origin/sprout`.
Keep **both** intents: the landed behaviour stays. Prefer additive edits; do not revert the
other side wholesale. Remove every conflict marker (`<<<<<<<`): a bean with markers is
dropped. For a clash of intent rather than text, call `work_overlaps` and read `bean_context`.

## Reverted or dropped

Reverted: your landed bean broke the sprout's validation. Read the reason (`checks_get`, the
remote message), fix, push a new revision. Dropped: report the reason and stop unless the
user wants a fresh bean.

## Decision cards

When two beans' intents contradict and a reconcile attempt cannot amend their tests, a card
asks a person to pick. Your bean waits. Do not push variants to route around it and do not
edit the other bean's tests. Tell the user (`run_status` lists open cards). If your side
loses, you redo your intent on the new sprout.

When Clef routes a bean to a person and also sees a clash, the held message adds
`Before approving: Clef also thinks it may disagree with <bean>`. Relay that line to your
person with the card; do not approve the bean yourself.

## Hygiene

Smaller diffs collide and re-check less. One intent per bean. Write the commit message so the
assumptions are explicit (units, formats, what a value means: "prices in cents", "dates as
UTC ISO strings"): it is what Clef compares against other beans. Rebase before every push. Do
not push while a check for the same bean is still running (refused). Do not block on your own
check: work on the next task and read the verdict when it is there.
