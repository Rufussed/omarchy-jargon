# Jargon

**Teach your dictation the words you actually use.**

An [Omarchy](https://omarchy.org) plugin for [Voxtype](https://voxtype.io),
the push-to-talk dictation built into Omarchy. Press **Super+F9**, tick the
vocabulary that matches your work, and technical words come out right the first
time you say them.

---

## The problem

Voxtype transcribes with Whisper. On a small model it guesses at words it has
barely seen:

| you say | you get |
|---|---|
| GLB | *GOB* |
| caching | *casing* |
| prefetching | *pre-veging* |
| Hyprland | *Hyperland* |

Voxtype can already fix this. It has a setting called `whisper.initial_prompt`
that biases what the model expects to hear — but it ships **empty**, lives in a
TOML file nobody opens, and has a size limit you will cross without being told.

Jargon fills that setting in, and stops you overflowing it.

## What it does

- **A vocabulary, ready to use.** Seven curated lists — 3D, web, backend, git,
  Linux, AI, everyday dev — written and grouped so you enable two or three and
  you are done.
- **Your own words.** Add the names, brands and project words nothing else will
  get right. `char-goatman`, `Mixamo`, your client's name.
- **Everything is editable.** The shipped lists are a starting point, not a
  catalogue. Rename them, edit them, delete them, make your own.
- **A budget you can see.** The prompt has a hard limit and Whisper silently
  throws away the overflow. Jargon counts it exactly and refuses to let you go
  over.
- **Tells you what is working.** It reads which of your words actually turn up
  in your dictation, so you know what earns its place and what to cut.
- **Manages your models too.** Download, switch and delete Whisper models from
  the same panel, with progress and a cancel button.

## Requirements

- Omarchy with `omarchy-shell` (the Quickshell-based bar)
- Voxtype installed and running (`voxtype --version`)
- Python 3

## Install

```bash
git clone https://github.com/Rufussed/omarchy-jargon.git
cd omarchy-jargon
./install.sh
```

That puts the `jargon` command on your PATH, installs the panel as an Omarchy
plugin, and binds **Super+F9** to open it. Your `bindings.lua` is backed up
first, and if Super+F9 is already taken it says so instead of clobbering it.

Pass `--no-bind` if you manage your own keybindings, then add:

```lua
-- ~/.config/hypr/bindings.lua
o.bind("SUPER + F9", "Dictation vocabulary", "omarchy-shell shell toggle rufussed.jargon")
```

Because the binding lives in `bindings.lua`, it also shows up in Omarchy's
keybindings cheatsheet for free.

A good mnemonic: **F9 dictates, Super+F9 configures what it hears.**

## Using it

Press **Super+F9**.

| key | does |
|---|---|
| `↑` `↓` | move between lists |
| `space` | turn a list on or off |
| `a` | add a word to the selected list |
| `n` | make a new list |
| `×` | delete a list, or click a word to remove it |
| `esc` | close |

Changes apply when you close the panel, and Voxtype restarts itself. There is
no save button.

**Write words the way you want them typed** — `GLB`, not "gee el bee". You are
showing the model the spelling you want, not how it sounds.

**Add a word when you said it and the wrong thing appeared.** That is the only
signal worth acting on. Words the model already gets right cost budget and buy
nothing.

## From the terminal

Everything the panel does, the CLI does:

```bash
jargon                      # what is on and what it costs
jargon lists                # every list, with its words and cost
jargon enable 3d git        # turn lists on
jargon add "Mixamo" --to 3d # add a word
jargon new wizard-game      # make a list
jargon usage                # which words actually get used
jargon models               # what is installed, what is running
jargon model small.en       # download if needed, then switch
```

## How it works

There is no dictionary and no spell-check. Whisper writes text one piece at a
time, weighing what it heard against the words already in front of it. Your
vocabulary is placed there as context, so when the audio is ambiguous between
"GOB" and "GLB", the surrounding technical words tip the balance.

Two things follow from that:

- **It biases, it does not guarantee.** If the audio clearly says something
  else, a listed word still loses.
- **It only helps words in the prompt.** The prompt holds **224 tokens** and
  Whisper silently discards anything past that — dropping the *earliest* words
  first. That is why Jargon counts exactly, using the tokenizer read out of your
  own model file, rather than estimating.

If your vocabulary is bigger than the budget, a **bigger model** is the other
lever. A model that has seen more text needs less help from you.

## What this does not do

Jargon only writes `whisper.initial_prompt` — prevention, before the mistake.

It never touches `text.replacements`, which rewrites mistakes after the fact.
Those rules have to match the exact garbled text Whisper produced, so they are
personal to your voice and your microphone; a shipped list of them would be
noise. For the handful of words that resist biasing — usually brand names with
no natural context — use
[teach-voxtype](https://github.com/Enovara/omarchy-teach-voxtype), which records
you saying the word and maps what Whisper actually heard. The two work together:
Jargon for your vocabulary, teach-voxtype for the stubborn few.

## Credits

[teach-voxtype](https://github.com/Enovara/omarchy-teach-voxtype) by Enovara
solved the hard half of this problem first, and is the right tool for words a
prompt cannot fix. Jargon covers the other half — the ordinary technical
vocabulary that only ever needed a word list.

`NOTES.md` has the design reasoning, the prior-art survey and the bugs found
along the way.

## License

MIT
