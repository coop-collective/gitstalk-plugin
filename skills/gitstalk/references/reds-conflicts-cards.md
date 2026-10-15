# Handling reds, conflicts and decision cards

Contents: how landing works; when a verdict reaches you; red; recheck (a clash with a bean you
never saw, reconciling its tests, not escalating); inherited red; conflict; reverted or dropped; decision cards; hygiene.

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
   value, update that test and say so in the commit message. Never weaken a protected
   acceptance test to get green; if one contradicts your intent, that is a clash of intents:
   read the other bean's intent and keep both. When the test only pins the assumption you
   changed (a unit, a format), reconcile it as in the recheck section below; ask a person only
   when the two intents cannot both hold. Never skip or weaken tests.
4. Push again (`git push -f origin HEAD:refs/heads/bean/<name>`). An empty failure list means the suite failed before naming tests
   (build error or timeout): run build and tests locally.
5. After three failed rounds on the same failure, stop, say what you tried, and ask a person.

## Recheck: a clash with a bean you never saw

When the repository's `.gitstalk/policy.yml` routes code to `triage`, Clef also compares your
bean's intent with beans you could not have read: beans that landed on the sprout after you
forked, and beans pushed earlier that are still being checked. If Clef is at least 30% sure the
two clash (a unit, format, meaning or value both rely on), your push comes back as an ordinary
**red**, not a person's hold. That holds even when the change would also need a person: the
clash comes to you first, your fixed push is judged again, and a card may still follow for a
real risk, after you have reconciled what you can.

```
remote: gitstalk: approval rules: pricing -> recheck (clef, p=0.71)
remote: gitstalk: back to its author: recheck against shipping-flat
remote: gitstalk: RED: price-dollars was not landed. Merged onto the sprout, these tests failed:
remote: gitstalk:   - .gitstalk/policy.yml > recheck against beans that landed after it forked
remote: gitstalk:     Clef read this bean's intent beside beans it never saw (...) and thinks
remote: gitstalk:     they may disagree (a unit, a format, a meaning or a value both rely on):
remote: gitstalk:       shipping-flat: Flat $5 shipping: total() = price() + 500 (cents)
remote: gitstalk:         imported by: src/shipping.mjs -> src/price.mjs
remote: gitstalk:         you changed, it uses: price
remote: gitstalk:     Read them (...). When a test of theirs only pins the assumption the two
remote: gitstalk:     disagree on (a unit, a format), update that test so their intent still holds (...)
remote: gitstalk:       Intent-checked: shipping-flat
remote: gitstalk:     This is not a person's hold: (...) the approval rules judge the new push again.
```

Each named bean shows its intent (its commit subject, one line) and the link Clef found (an
import, a name it changed that you use). One still in check is labelled `(pushed before this
one, still being checked)`. The explanation prints whole, from the top.

1. Read the named bean: `git fetch origin sprout && git log origin/sprout` (find its commit,
   `git show` it) if it landed; `git fetch origin bean/<name>` then `git show FETCH_HEAD` if it
   is in flight.
2. Compare the two intents. If they disagree (it now returns dollars, you assumed cents), fix
   **your** bean so both hold, and add a test for the combination when you can.
3. **Reconcile its tests.** When a test of the named bean only pins the assumption the two
   intents disagree on (a unit, a format, what a value means), update that test so the other
   bean's intent still holds under the new assumption, and say so in your commit message (which
   test, and why its intent is kept). Example: the shipping bean's flat $5 fee has the test
   `total() === price() + 500` (cents). After `price()` returns dollars you fix `total()` to
   `price() * 100 + 500`, and the test becomes `total() === price() * 100 + 500`: still $105
   for a $100 item. That is reconciling, not weakening. Never change what the test is for,
   never delete or skip it, and never loosen an assertion to make a wrong change pass.
4. Either way, rebase on `origin/sprout` and push again with the trailer
   `Intent-checked: <bean>[, <bean>]` in the bean's commit message (`git commit --amend`, or the
   new commit's message). It removes those beans from the comparison; the tests then decide,
   and the approval rules judge the new push again.
5. Never revert or force-push the other bean, and never change its code. If its intent itself
   looks wrong, say so to your person or on the bean's thread (`bean_thread_post`).

**Do not escalate a misalignment.** Do not write "needs a person to decide", ask for approval
or stop for a clash you can reconcile as above. Escalate only a real contradiction: the two
product intents cannot both hold (one bean wants free shipping, the other a $5 fee).

```
Make price() return dollars, not cents

total() now converts: price() * 100 + 500 keeps shipping-flat's $5 fee in cents.
Reconciled shipping-flat's test total.test.mjs > "adds the flat fee": it pinned
price() in cents; it now expects price() * 100 + 500 (still $105 for $100), so its
intent (a flat $5 fee) holds.

Intent-checked: shipping-flat
```

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

A card asks a person when a change carries real risk under the approval rules, or when two
beans' intents truly contradict and no reconcile (above) can make both hold. Your bean waits.
Do not push variants to route around it and do not edit the other bean's tests to escape it.
Tell the user (`run_status` lists open cards); never approve the bean yourself. If your side
loses, you redo your intent on the new sprout.

A clash Clef is sure of no longer rides along on a card: it comes to you first as a recheck
red, and only your reconciled push can go on to a person.

## Hygiene

Smaller diffs collide and re-check less. One intent per bean. Write the commit message so the
assumptions are explicit (units, formats, what a value means: "prices in cents", "dates as
UTC ISO strings"): it is what Clef compares against other beans. Rebase before every push. Do
not push while a check for the same bean is still running (refused). Do not block on your own
check: work on the next task and read the verdict when it is there.
