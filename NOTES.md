# Jargon — a starter vocabulary for Omarchy dictation

A curated library of technical terms for Omarchy's dictation (**Voxtype**,
hold **F9**), so jargon transcribes correctly the *first* time it is spoken.

Written 2026-09-19 as a handoff. Everything about Voxtype below was verified on
this machine. **Read the "Prior art" section first — a plugin already occupies
most of this space, and the remaining gap is narrower and more interesting than
the original idea.**

---

## Prior art — read this first

[`omarchy-teach-voxtype`](https://github.com/Enovara/omarchy-teach-voxtype) by
Enovara is installed on this machine (`omarchy plugin add ... --enable`). It is
good, and it solves the hardest problem in this space.

The hard problem: `text.replacements` keys must match what Whisper *produced*,
not what was said, so mappings cannot be written in advance. Their answer is to
**record you saying the word six times** — alone, slowly, quickly, in sentences —
transcribe each take with your model plus `base.en` (which mishears more, and so
surfaces errors you would hit later), and show every spelling Whisper actually
produced with counts. You tick the ones to map. Spellings that are real English
words are flagged and left unchecked, so a mapping never rewrites a word you
genuinely say. It writes `text.replacements`, appends to
`whisper.initial_prompt`, and restarts the daemon.

It is a `bar-widget`: a mic that follows voxtype's status, left click opens the
trainer, right click toggles dictation. Also driveable from the terminal:

```bash
omarchy-shell io.github.enovara.teach-voxtype teach "GLB"
```

**Verified gaps (checked against the repo on 2026-09-19):**

- **No pre-built library.** No presets, no starter lists, no batch import.
  Entirely reactive, one word at a time, each costing six spoken takes.
- **No token budget.** The README never mentions the 224-token cap. Since it
  appends to `initial_prompt` on every word taught, a heavy user will silently
  cross the limit and start *degrading* transcription with no warning.

So the remaining idea is not a competing plugin. It is **the library, plus
budget awareness**, and the best home for both is probably a PR to that plugin
rather than a second one fighting for the same slot.

### The sharper version of the gap

teach-voxtype is a **precision tool offered as the general solution**, and the
general solution is a word list.

Six spoken takes are the right price for a word that resists biasing — proper
nouns and brand names, which have no natural context and lose to
phonetically-plausible English however you prompt. "Enovara" genuinely needs
the recording, because the only way to learn the literal string Whisper emits
is to say it and look.

For ordinary technical vocabulary it is wildly disproportionate. "Cache",
"GLB", "WebGL" are fixed by putting them in the prompt, at zero takes, because
prevention beats correction when the term is merely *unfamiliar* rather than
*unpronounceable-by-machine*. A user who works through their jargon one
six-take recording at a time is doing by hand what one curated list does at
once — and burning their 224-token budget doing it, since every taught word is
appended.

**The order that should be recommended, cheapest first:**

1. **A prompt library** — covers most dev jargon immediately, no takes.
2. **A bigger model** — `base.en` is the second smallest. For technical
   vocabulary this may beat both config settings combined.
3. **teach-voxtype** — for what is still wrong after 1 and 2. Names, brands,
   oddities. A short list, not a whole vocabulary.

Nothing today tells a user this. teach-voxtype is the only visible answer, so
it gets used for everything.

Also in this space: [`omarchy-voxtype-enhance`](https://github.com/iamcheyan/omarchy-voxtype-enhance)
(model downloads, multilingual, terminal-aware paste) and
[`omarchy-utter`](https://github.com/RR-CodeBase/omarchy-utter) (voice *commands*
against an editable grammar). Community plugin directories live at
omarchyplugins.com and plugins.omarchy.org — browse them before building.

---

## Positioning

Three claims, in the order they should be made to a user.

**It is already on your machine.** Voxtype ships the capability that
commercial dictation apps charge a subscription for — Wispr Flow's headline
feature is a custom dictionary, and voxtype has had the same two settings all
along. They sit in a TOML file nobody opens, undocumented in Omarchy's
defaults, with no vocabulary in them. A capability with no surface is not a
capability. This does not add a feature; it **opens a door on one that exists**.

**It is one step.** Enable the groups that match your work and you are done.
No recording, no ritual, no per-word ceremony — the terms are right the first
time you say them. Teaching a word by voice is a good tool for the few that
need it and a bad default for the many that do not.

**It costs almost nothing.** Two senses, and both are true:

- *Effort* — one toggle against six spoken takes per word.
- *Tokens* — a curated list is far more efficient than words appended one at a
  time, and being budget-aware means it stays inside the 224-token cap instead
  of silently overflowing it. Prevention is cheaper than correction, both to
  set up and to store.

**It comes with a developer vocabulary, ready to use.** Not an empty box with
instructions — the terms are already written, grouped and curated: GLB, glTF,
Mixamo, mipmap, rebase, Fastify, Hyprland. Someone has done the judgement of
deciding which terms are worth the budget and which are waste, which is the
part a user cannot be bothered to do and a generic word dump gets wrong.
Anyone who writes code gets value on install, before typing a single term of
their own.

That last claim is the actual product; the first three are why it is worth
having. But the third is the one to lead with in a README or a post — "your
dictation already does this and nobody told you" is a better hook than "here
is another plugin".

---

## The problem

Voxtype transcribes with Whisper. On the stock `base.en` model it guesses at
technical terms it has barely seen — "GLB" becomes "glee bee", "cache" becomes
"cash", "WebGL" becomes "web jill". The words are ordinary English to the
model, and the model has no idea you are talking about 3D assets.

Voxtype can already fix this — but only in the sense that it provides two
empty settings to put vocabulary in. **It ships no vocabulary of its own.**
Omarchy's default config does not mention `initial_prompt` at all, and the
only `replacements` line is a commented-out example. Nothing on disk is a word
list. Supplying the content is the whole point of this plugin.

The settings are also buried in a TOML file nobody opens, and one of them has
a size limit that is easy to blow past without noticing.

## What Voxtype already gives us

Config lives in `~/.config/voxtype/config.toml`. Read and write it with
`voxtype config get|set|unset <key>`, which preserves comments. Changes need
`systemctl --user restart voxtype`.

Two relevant keys, and they work very differently:

**Neither is a spell-check.** There is no candidate list Whisper consults when
it is unsure — no dictionary, no fuzzy matching, no "did you mean". That model
is wrong and it leads to wrong designs. One setting shapes what Whisper
*produces*; the other rewrites what it already produced. They are not two
versions of the same idea.

| | when it acts | how | limit |
|---|---|---|---|
| `initial_prompt` | during decoding | **prevention** — biases token probabilities | 224 tokens |
| `text.replacements` | after decoding | **correction** — literal find-and-replace | none |

### `whisper.initial_prompt`

Text prepended to Whisper's context to bias vocabulary and spelling. It is not
a dictionary — it puts the model somewhere that those words are plausible, so
they win over their homophones. Having "GLB" in the prompt does not make
Whisper look up "glee bee" and find a match; it makes "GLB" the more probable
output, so the mishearing never happens at all.

**Hard limit: 224 tokens** (whisper.cpp uses `n_text_ctx / 2`). Overflow is
silently truncated, which is the trap: a large pasted word list pushes the
useful terms off the end and makes transcription *worse* with no warning.
Roughly 4 characters per token, so budget around 900 characters.

This is the high-value setting and the one that needs curation, not volume.
Terms any model already spells correctly (`API`, `JSON`, `CSS`) are waste.

### `text.replacements`

Case-insensitive find-and-replace applied *after* transcription. No practical
size limit.

```toml
[text]
replacements = { "gee lb" = "GLB", "web jill" = "WebGL" }
```

The catch: keys must be what Whisper *produced*, not what was said. You cannot
write these in advance — they have to be collected from real mistakes. A
generic library of these is close to useless; a personal one is excellent.

### Also worth knowing

- `whisper.model` — currently `base.en`, the second-smallest. `voxtype info
  accel` reports **CPU-only** on this machine. Upgrading to `small.en` may
  matter more than any vocabulary tuning; `voxtype setup model` picks one.
- `voxtype config schema` lists every settable key.
- Current state: `whisper.initial_prompt` is set (~105 of 224 tokens) with a
  3D/web-dev list. `text.replacements` is unset.

## The idea

Two deliverables, in order of value. The first is useful on its own and needs
no UI at all.

### 1. The library (the real contribution)

A curated set of developer terms, grouped by domain, as plain JSON or TOML.
Toolkit-agnostic — a TUI, a CLI, a panel or a PR to teach-voxtype can all
consume it.

It is the *general* answer, where teach-voxtype is the precision one: prompt
first, record only what survives. See "The sharper version of the gap" above.

This is the part requiring judgement, and nobody has done it. Deciding *which
50 terms are worth 224 tokens* for a 3D web developer is knowledge, not code.
It complements teach-voxtype rather than duplicating it: that plugin fixes
words after they fail, at six spoken takes each; a library loads terms before
you ever hit them, at zero.

Note the asymmetry — a library can only sensibly populate `initial_prompt`
(prevention), never `text.replacements` (correction), because replacement keys
are personal to your voice and mic. Anyone shipping a generic replacements list
is shipping noise.

### 2. Budget awareness

A live "137 / 224 tokens" readout, warning as it fills. This turns an
invisible silent-truncation failure into something obvious, and it is the
single feature no existing plugin has. Worth raising as an issue on
teach-voxtype regardless of what gets built here, since appending on every
taught word walks straight into it.

### Where it should live

Decide deliberately, and prefer the cheapest that works:

- **A PR to teach-voxtype** — presets and a budget readout added to a plugin
  people already install. Best reach, least duplicated effort, and the mic
  icon is already in their bar.
- **A CLI** (`jargon groups`, `jargon add`) — an afternoon's work, scriptable,
  no QML. Enough to use the library today.
- **A new plugin** — only if it does something the others cannot. See below.

**What would justify a separate plugin:** vocabulary that switches with
context — 3D terms while Blender is focused, git terms in the terminal. That
needs a resident process watching the focused window, which is exactly what
the shell is for and what a CLI cannot do. Editing a word list is not that.

### Suggested groups

Keep each small. The point is that a user enables two or three, not all of them.

- **3D / graphics** — GLB, glTF, Blender, Mixamo, three.js, WebGL, mesh, UV,
  mipmap, anisotropy, shader, emissive, viewport
- **Web / frontend** — Vite, TypeScript, WebSocket, DOM, canvas, WebP, npm,
  SvelteKit, Tailwind
- **Backend / data** — Fastify, SQLite, Postgres, Redis, schema, migration,
  endpoint, payload
- **Git / workflow** — repo, commit, branch, rebase, merge, stash, cherry-pick,
  upstream
- **Linux / Omarchy** — Hyprland, Omarchy, Wayland, Arch, systemd, pacman, AUR
- **AI / agents** — Claude, LLM, prompt, token, embedding, inference, agentic

## If it does become a plugin

Only after the "where should it live" question above is settled. Omarchy shell
plugins are Quickshell/QML, discovered from
`~/.config/omarchy/plugins/<plugin-id>/`. Saving any file there hot-reloads;
`omarchy-shell shell rescanPlugins` forces it.

**Hot-reload is fragile.** Installing teach-voxtype on this machine segfaulted
quickshell (SIGSEGV, 2026-09-19 11:27) during the reload. It restarted clean
and has been stable since, so prefer `omarchy-restart-shell` over a hot-reload
when testing, and expect the same during development.

Two models to copy, depending on the kind:

- `omarchy.tailscale` (`/usr/share/omarchy/shell/plugins/panels/tailscale/`) —
  a `bar-widget` with a popup panel, `Service.qml` for state, `Model.js`, and a
  `manifest.json` declaring a settings `schema`.
- `io.github.enovara.teach-voxtype`
  (`~/.config/omarchy/plugins/`, installed) — the closest analogue by far:
  a `bar-widget` driving voxtype through a Python engine (`voxwords.py`) with
  an IPC entry point. Read its `Panel.qml` and `Request.js` before writing
  anything.

**Summoning, if it is not a bar widget.** A bar icon costs permanent screen
space for something touched a few times a year. The alternatives, verified:

- **Omarchy menu** — add to `~/.config/omarchy/extensions/omarchy-menu.jsonc`
  (hot-reloads, `description` is searchable, `when` hides the row when voxtype
  is absent):
  ```jsonc
  "setup.jargon": {
    "icon": "󰗋", "label": "Dictation vocabulary",
    "description": "Technical terms Voxtype should recognise",
    "action": "omarchy-shell shell summon jargon.dictation '{}'",
    "when": "command -v voxtype"
  }
  ```
- **Super+F9** — verified unbound on this machine (bare F9 has two binds, press
  and release, for hold-to-talk; Super+F9 is free). Good mnemonic: F9 dictates,
  Super+F9 configures what it hears. Binding it in `~/.config/hypr/bindings.lua`
  also puts it in the keybindings cheatsheet (`omarchy-menu-keybindings` reads
  the config) **for free**, which is the best passive discovery surface Omarchy
  has.
- **`keepLoaded: true`** in the manifest keeps the window alive between summons.

Read `/usr/share/omarchy/shell/plugins/README.md` for the manifest contract and
`~/.claude/skills/omarchy/plugins.md` for the user-side rules. **Never edit
anything under `/usr/share/omarchy/`** — read it freely, write only to
`~/.config/omarchy/plugins/`.

Proposed id: `jargon.dictation`. Note installed plugins use reverse-DNS
(`io.github.<user>.<name>`), which is the better convention if published.

## Discovery — the honest problem

There is **no plugin marketplace in the CLI**; distribution is
`omarchy plugin add <git-url>`. Community directories exist
(omarchyplugins.com, plugins.omarchy.org, and the Okomart storefront) but
nobody browses plugin lists to find features they did not know existed.

For a plugin you install yourself this does not matter. For anyone else, the
only path with real reach is **the voxtype install flow**, which already ends
with a notification:

> *"Voxtype Dictation Ready — Hold F9 to dictate (or toggle with Super + Ctrl + X)."*

One more clause there reaches every person who installs dictation on Omarchy.
That is a one-line change to `omarchy-voxtype-install` and is worth more than
every other discovery surface combined — another argument for contributing
upstream rather than shipping a standalone plugin.

## Open questions for whoever builds this

- **Where does the library live?** A JSON file is simplest. If shipped as
  plugin data, an update could overwrite user edits, so personal terms belong
  in a separate file that is never overwritten.
- **Own the prompt, or merge into it?** teach-voxtype already appends to
  `initial_prompt`, and a user may have hand-written one. Clobbering either
  would be rude; merging is friendlier but makes token accounting harder to
  explain. **This now has to coexist with another plugin writing the same key** —
  the single most important design constraint here.
- **Token counting.** No real tokenizer in QML. `chars / 4` is a decent
  approximation; be conservative and warn early.
- **Restart cost.** `systemctl --user restart voxtype` reloads the model, which
  is not instant on CPU. Debounce writes; do not restart per keystroke.

## Verify before building

Things that were true on 2026-09-19 and are worth re-checking, since Omarchy
moves fast:

```bash
voxtype config schema | grep -E "initial_prompt|replacements"
voxtype config get whisper.initial_prompt      # what is set right now
voxtype info accel                              # cpu-only on this machine
voxtype info models                             # base.en is the only one installed
omarchy plugin list                             # teach-voxtype should be enabled
cat /usr/share/omarchy/shell/plugins/README.md  # manifest contract
```

## State of this machine, 2026-09-19

- Voxtype installed, `voxtype.service` active, **F9** hold-to-dictate.
- `whisper.model = base.en` (second smallest), `voxtype info accel` says
  **cpu-only**. Upgrading to `small.en` via `voxtype setup model` may matter
  more for technical terms than any vocabulary tuning — test that before
  building anything.
- `whisper.initial_prompt` **is set** (~105 of 224 tokens): a hand-written
  3D/web-dev list. Remove with `voxtype config unset whisper.initial_prompt`.
- `text.replacements` unset.
- `io.github.enovara.teach-voxtype` installed and enabled, bar widget placed
  between weather and microphone.
- Missing optional dep: `/usr/share/dict/words` (`omarchy pkg add words`),
  which teach-voxtype uses to flag real English words so a mapping never
  rewrites a word you actually say. Worth installing.

---

## As built, 2026-09-19

All three asks are working: no bar icon, **Super+F9** opens a panel, the budget
warns, and term usage is logged.

```
library/groups.json   7 curated groups
jargon                CLI; owns initial_prompt only, never text.replacements
plugin/               rufussed.jargon — overlay, keepLoaded, no bar widget
install.sh            links the CLI, copies the plugin, enables, rescans
```

**Summoning.** `o.bind("SUPER + F9", "Dictation vocabulary", "omarchy-shell
shell toggle rufussed.jargon")` in `~/.config/hypr/bindings.lua`, so it also
lands in the keybindings cheatsheet for free. The panel is `kind: overlay`
(not `bar-widget`), so it costs no permanent screen space.

**Usage logging turned out to be free.** voxtype logs every finished
transcription at INFO: `journalctl --user -u voxtype | grep 'Transcribed:'`.
`jargon usage` counts library terms against those lines — read-only, outside
the dictation hot path, and *retroactive* over whatever the journal still
holds. `output.post_process.command` was the alternative and is worse: it sits
in the hot path and only one thing can own it.

Caveat: a term appearing in output does not prove the prompt caused it. It is
a usefulness proxy, not attribution. Terms with zero hits are the eviction
list, which is what the budget question actually needs.

### Gotchas found the hard way

- **The hot-reload watcher does not follow a symlinked plugin directory.**
  Symlinking `plugin/` into `~/.config/omarchy/plugins/` silently serves stale
  QML forever. `install.sh` copies instead.
- **`keepLoaded: true` overlays survive `rescanPlugins`.** The component is
  instantiated at startup and is not destroyed by a rescan, so edits need
  `omarchy restart shell`. Matches the README's warning above about preferring
  a restart over a hot-reload.
- **`os.path.abspath` is not enough when the script is run through a symlink**
  — `~/.local/bin/jargon` resolved its library relative to `~/.local/bin`.
  `realpath`.

### Libraries

Vocabulary is organised into **named libraries**, one active at a time, each
with its own 224-token budget. That is the real answer to the cap: 224 tokens
for everything you ever say is tight, but 224 tokens *per activity* is roomy.

```bash
jargon libs                    # list, with per-library budgets
jargon new wizard-game         # empty, and switches to it
jargon enable 3d web           # edits the active library
jargon add "Mixamo" "atlas"
jargon use default             # switch back (applies immediately)
jargon rm blender
```

The shipped groups in `library/groups.json` are the curated ingredient pool;
a library is a selection of those groups plus its own terms. New libraries
start **empty** on purpose — a per-activity library earns its keep by being
small, and inheriting a general vocabulary defeats that.

In the panel, libraries appear as chips under the title. **Tab** cycles them
and applies immediately, because switching is a deliberate act; toggling
groups stays manual (ctrl+a), because that is editing rather than switching.

Usage counts stay global across libraries: a term you lean on in one project
is evidence when budgeting another.

### Entering vocabulary

Two ways, same store:

- **In the panel** — press **a** (or click the field), type the word, enter.
  It lands in the active library immediately. Click any term in the right-hand
  column to remove it. The panel watches `state.json`, so CLI edits show up
  live while it is open.
- **From the CLI** — `jargon add "Mixamo" "Zod"` / `jargon remove Zod`.

Either way you still need **ctrl+a** (or `jargon apply`) to write the prompt
and restart voxtype. Adding a term is editing; applying is a separate,
deliberate step — the restart reloads the model and is not free on CPU.

The panel is sized to 80% × 90% of the screen: groups on the left, this
library's own terms with their hit counts on the right.

### Three bugs worth remembering

Found while wiring the panel, all of them silent:

- **`Keys.priority: Keys.BeforeItem` beat the text field.** Pressing enter to
  add a term also reached the group list underneath and toggled whatever row
  was selected. This is what had been "mysteriously" switching groups off for
  an hour. The key handler now returns early whenever the input has focus.
- **Two processes shared one temp file.** `save_state` wrote
  `state.json.tmp` unconditionally, so two concurrent `jargon` calls
  interleaved their JSON and produced a corrupt file. The temp name now
  carries the pid, and a corrupt state is moved aside rather than silently
  discarded.
- **`json` saved state wholesale.** The panel runs it right behind commands
  that edit state, so it wrote back a copy loaded before that edit landed.
  Usage counters now merge into a freshly-read file instead.

`~/.config/jargon/audit.log` records every write with its argv and the
resulting group list. It is what identified the first bug in one reading,
after guessing had failed twice.

### Still open

- `small.en` is still not installed. Test it against this prompt before
  growing the library much further.
- Personal terms are managed from the CLI (`jargon add`); the panel shows the
  count but has no add field yet. Same for creating a library.
- **Auto-switching by focused window** is now the obvious next step, and it is
  the one thing in this README that genuinely justifies a resident process:
  blender focused → `blender` library, terminal → `git`. Everything needed for
  it exists now that libraries do.
- Nothing has been offered upstream. The budget readout is still the feature
  teach-voxtype most needs.

---

## Addendum, 2026-09-23: the bar icon is a separate plugin id, on purpose

Omarchy's shell keeps **one shared enabled flag per plugin id**. For a plugin
that declares `kinds: ["overlay", "bar-widget"]`, that flag is defined by
whether the id appears *anywhere* in `shell.json` — for a bar-widget, that
means presence in `bar.layout.*`. Remove the icon from the bar by any means —
a direct edit, `omarchy plugin disable`, even just dragging it off — and the
*whole plugin id* goes dark, overlay included. There is no way to keep the
panel reachable by keybinding while the bar icon is off, as long as both kinds
share one manifest.

The fix is two plugins:

- `rufussed.jargon` — `kinds: ["overlay"]` only. Never touched by icon on/off.
  Its own enabled state lives as a top-level entry in `shell.json`'s
  `plugins[]` array (required for any non-first-party, non-bar plugin to
  count as enabled — see `PluginRegistry.qml`'s `isEnabled`/`findEntryLocation`).
- `rufussed.jargon-icon` (`bar-icon/`) — `kinds: ["bar-widget"]` only. Its sole
  job is a button that runs `omarchy-shell shell toggle rufussed.jargon`.
  Disabling it only ever removes a `bar.layout` entry; it has no other
  registration to lose.

Also worth knowing: `omarchy plugin disable` then `enable` back-to-back is a
real race — each is a separate IPC round-trip that reads, modifies and writes
`shell.json`, and with no gap the enable's read can land before the disable's
write. `jargon`'s `set_icon()` sleeps between them and verifies before
returning.
