# Demo — ApplicationSet Web UI (Argo CD 3.5)

Self-contained demo folder. Drop it in your repo, run `configure.sh`, apply in order.

---

## Version check ✅

Verified this one before building, given what happened with the Helm glob feature. Two docs pages are **new in 3.5** and absent from 3.4.4:

- `docs/user-guide/application-set-ui.md`
- `docs/operator-manual/applicationset/Web-UI.md`

So this is genuinely a 3.5 feature. (For reference, the full list of docs pages added between 3.4.4 and 3.5.1: those two, plus `operator-manual/mtls.md`, `user-guide/source-integrity.md`, `user-guide/source-integrity-git-gpg.md`, `user-guide/application-notice.md`, `operator-manual/notifications/services/gcppubsub.md`, `operator-manual/upgrading/3.4-3.5.md`, and `operator-manual/upgrading/ui-extensions-react-19-upgrading.md`. `user-guide/gpg-verification.md` was removed. **`user-guide/application-notice.md` is a feature neither of us has on the list yet** — worth a look.)

## ⚠️ Say "alpha" on camera

The docs carry an explicit alpha warning: *look, behavior, and the APIs it consumes may change in future releases or be removed in backwards-incompatible ways.* The release blog didn't mention this.

Say it once, early, and move on. It costs you five seconds and it's the difference between a video that ages well and one that gets "this doesn't work anymore" comments in six months.

---

## Setup

```bash
./configure.sh https://github.com/<you>/<your-repo>.git appset-ui
git add . && git commit -m "add appset UI demo" && git push

kubectl apply -f manifests/00-projects.yaml
kubectl apply -f manifests/01-envs-appset.yaml
kubectl apply -f manifests/02-services-appset.yaml
kubectl apply -f manifests/03-degraded-appset.yaml

./verify.sh
```

For the app-of-appset beat (Beat 6) and the RBAC beat (Beat 5), see their sections — both need extra setup.

**Why four ApplicationSets:** a single one makes a terrible list-page demo. The list page has a health pie chart, filters by project/namespace/label/health, and tile-vs-table toggle — none of which mean anything with one row. You need variety in project (`platform` vs `team-a`), in labels (`owner`), and crucially in **health** (one Degraded).

---

## Beat 1 — the list page (~45s)

Navigate to `/applicationsets`, or the top-level nav item.

**Before 3.5 — narration:**

*"There was no UI for ApplicationSets. None. You had `kubectl get appset`, `argocd appset get`, or you looked at the child Applications and inferred the parent. The issue asking for this was opened in 2021."*

Run the old workflow first so the contrast is concrete — it still works on 3.5:

```bash
kubectl get appset -n argocd
kubectl get appset envs -n argocd -o yaml | head -40
```

Then switch to the UI and walk it:

- **Health pie chart** at the top, summarizing whatever the current filter matches. This is why the demo ships a deliberately broken ApplicationSet — a single-colour pie is a boring pie.
- **Search bar**, substring match on name and namespace. Press `/` to focus it. Type `svc`.
- **Filters sidebar** — project, namespace, labels, health (`Healthy`, `Progressing`, `Degraded`, `Unknown`). Filter to `platform`, then to `Degraded`.
- **Filters are reflected in the URL.** Copy the URL out of the address bar and say "shareable, bookmarkable" — small detail, real workflow value, nobody else will show it.
- **Tile vs table toggle.** Table view shows name, namespace, project, health, conditions, and the number of generated Applications.

**RBAC point worth one sentence:** the page shows ApplicationSets across every namespace the user can access, enforced identically to the CLI. If `argocd appset get` works for you, you'll see it here.

---

## Beat 2 — resource tree (~30s)

Click into `envs`.

The centre of the details page is a resource tree. Root node is the ApplicationSet; each downstream node is a child Application it generated. Health and sync icons render exactly as they do on the Application tree. Clicking a child navigates to that Application's own details page — do that, then come back.

**Then show it live-update.** This is the beat that proves it's a real view and not a static render:

```bash
cp -r staged/qa workloads/qa
git add . && git commit -m "add qa environment" && git push
```

Refresh the ApplicationSet. A fourth node — `env-qa` — appears in the tree. The generator re-evaluated and the UI followed.

> Leave `workloads/qa/` in place afterwards, or `git rm` it to reset between takes.

---

## Beat 3 — status bar, health, and the conditions modal (~45s)

Still on `envs`: the status bar at the top shows **health**, **conditions by severity**, and **last updated**.

Now switch to `broken-generator`. It's **Degraded**, because its generator points at a repo that doesn't exist.

Open the conditions modal. Each condition shows type, status, the controller's message, and when it was last reported.

**Land the operational value:** this is the first place to look when an ApplicationSet is Degraded or Unknown — for example a generator that failed to evaluate, which is exactly what you're looking at.

**The derivation rules are worth 20 seconds**, because `status.health` on the ApplicationSet CR is itself new. The controller computes it from `status.conditions`, in this order:

1. No conditions → **Unknown** ("No status conditions found for ApplicationSet")
2. `ErrorOccurred` is True → **Degraded**, with that condition's message
3. else `RolloutProgressing` is True → **Progressing**
4. else `ResourcesUpToDate` is True → **Healthy**
5. else → **Unknown** ("Waiting for health status to be determined")

Show the field directly to connect UI to CR:

```bash
kubectl get appset broken-generator -n argocd -o jsonpath='{.status.health}' | jq
```

The UI reads this field through the normal Get/List/Watch endpoints — there's no separate health-evaluation API call.

---

## Beat 4 — the Preview tab (~2:00, the centrepiece)

**Correct a likely misconception up front.** Preview is not just "a list of the Applications this will generate." It's a **diff against live state**, with three sub-tabs:

| Tab | Shows |
|---|---|
| `DIFF` | default — unified diff of each Application that would change |
| `LIVE APPS` | what the ApplicationSet currently generates on the cluster |
| `DESIRED APPS` | what it *would* generate if the proposed spec were applied |

Open `services` → slide-out panel → **PREVIEW**.

### The edit

Click **Edit** on the ApplicationSet manifest card. Replace the list elements with:

```yaml
        elements:
          - name: api
            replicas: "3"      # MODIFIED - was "1"
          - name: worker
            replicas: "1"      # unchanged
          - name: gateway      # ADDED - new element
            replicas: "1"
          # cache REMOVED - deleted entirely
```

Click **Preview** again.

**Why this specific edit:** it produces all three diff categories in one shot — `svc-gateway` **added** (only in DESIRED), `svc-cache` **removed** (only in LIVE), `svc-api` **modified** (in both, with field-level differences). One screen, complete mental model.

Walk all three sub-tabs. Then click **Cancel** and show the spec revert.

### The two things to say out loud

**It's a sandbox — edits are never saved.** To persist anything you go through your normal GitOps flow, or `kubectl apply` / `argocd appset create`. Say this plainly; someone will otherwise assume the UI is a write path and be unpleasantly surprised.

**Why a list generator?** The docs are explicit that Git, SCM Provider, Pull Request, and Cluster generators are re-evaluated on **every** Preview click — if the upstream is slow or flaky, the preview reflects that. A list generator makes the diff instant and deterministic, which is what you want on camera. Worth mentioning as a caveat for real-world use.

### Known limitation, 15 seconds

Preview compares **whole Application manifests**. It does not recurse into the Kubernetes resources inside each child Application. For that, sync the child and use the existing Application diff view. Set the expectation before someone hits it.

---

## Beat 5 — Preview needs `create`, not just `get` (~45s, optional)

The sharpest RBAC point in the release, and everyone will get it wrong intuitively.

```bash
./rbac/setup.sh
argocd account update-password --account viewer --new-password <password>
```

Log in as `viewer` in a second browser profile.

**Show:** the list page works, the details page works, the resource tree works, events work. Every read view is fine — `viewer` has `applicationsets, get`.

**Then click PREVIEW.** Permission denied.

**Explain why, and this is the interesting part:** Preview calls `POST /api/v1/applicationsets/generate`, which renders candidate Applications server-side. That's the same operation the controller performs when it creates Applications — so the API server enforces **`applicationsets, create`** on the project of the *template*, the same permission you'd need to actually create the rendered apps.

Every other UI endpoint checks `get`. Preview is the only one that requires more.

**RBAC scoping footnote:** ApplicationSet RBAC objects are scoped by `spec.template.spec.project` — the project of the template's target Application — together with the ApplicationSet's namespace and name. Not the ApplicationSet's own project field. That trips people up.

Skip this beat if you don't want the second-login setup; it's self-contained.

---

## Beat 6 — owner badge, parent toggle, and app-of-appset preview (~1:00)

### Owner badge and the parent toggle

Open any child Application, e.g. `env-dev`.

- A small **badge** with the parent ApplicationSet's name sits on the Application node. Click it — it jumps to the ApplicationSet details page.
- In the Application's **view preferences**, toggle **Show parent ApplicationSet**. The parent renders as a synthetic root node on the resource tree with an edge to the Application. When the toggle is on, the badge hides, since the parent is already explicit.

Both only appear for Applications with an `ApplicationSet` ownerReference — worth stating, since hand-made Applications won't show them.

### App-of-ApplicationSets preview

```bash
kubectl apply -f app-of-appset/parent-app.yaml
argocd app sync parent-of-appset
```

Now make it OutOfSync by editing the managed ApplicationSet **in Git** without syncing — add a third region:

```bash
# in app-of-appset/appset/managed-appset.yaml, add:
#           - region: ap-south
git commit -am "add ap-south region" && git push
argocd app refresh parent-of-appset
```

Open `parent-of-appset` → click the **ApplicationSet node** on its tree → slide-out panel → preview.

You get a preview scoped to what would land when you sync the parent: `region-ap-south` would be added.

**Two differences from the standalone Preview tab, both worth stating:**

1. **Desired state comes from Git, not an editor.** The proposed ApplicationSet is the target manifest tracked by the parent Application. There's no YAML editor in this panel.
2. **Only available when the ApplicationSet is OutOfSync.** In sync means no diff to show — you get a short status message instead. This is why `parent-app.yaml` deliberately has no automated sync policy.

**The framing that makes this land:** this is the bridge between "I have a pending sync on my parent Application" and "show me which child Applications change as a result." That question was previously unanswerable without applying and finding out.

---

## Suggested cut (~5:00)

| Beat | Content | Target |
|---|---|---|
| 1 | List page, filters, health pie, URL sharing | 0:45 |
| 2 | Resource tree + live generator re-evaluation | 0:30 |
| 3 | Status bar, Degraded appset, conditions, health rules | 0:45 |
| 4 | **Preview tab — three diff categories** | 2:00 |
| 5 | Preview needs `create` (optional) | 0:45 |
| 6 | Owner badge, parent toggle, app-of-appset preview | 1:00 |

If it runs long, Beat 5 lifts cleanly as a standalone short — "the one Argo CD RBAC rule that surprises everyone."

---

## Pre-flight

- [ ] `./configure.sh` run, folder committed and pushed
- [ ] `./verify.sh` matches the expected table
- [ ] `broken-generator` actually shows **Degraded** (not Unknown) — if it's Unknown, the controller hasn't reconciled yet; wait or restart the appset controller
- [ ] `workloads/qa/` is **not** yet in Git (it gets added live in Beat 2)
- [ ] For Beat 5: `viewer` account created, password set, second browser profile logged in
- [ ] For Beat 6: `parent-of-appset` synced once, then the Git edit made so it reads OutOfSync
- [ ] Preview edit text ready to paste — retyping YAML on camera is dead air

---

## Files

```
manifests/00-projects.yaml        platform + team-a projects
manifests/01-envs-appset.yaml     git directory generator (tree, live re-eval)
manifests/02-services-appset.yaml list generator (the Preview demo)
manifests/03-degraded-appset.yaml broken repo -> ErrorOccurred -> Degraded
workloads/{dev,staging,prod}/     what the git generator discovers
staged/qa/                        copied in live during Beat 2
app-of-appset/parent-app.yaml     parent Application (no auto-sync, on purpose)
app-of-appset/appset/             the ApplicationSet it manages
rbac/setup.sh                     viewer account for the Preview RBAC beat
configure.sh                      fills in repo URL + path
verify.sh                         checks every appset is in the expected state
```
