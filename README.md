<div align="center">

<img src="assets/logo.svg" alt="$ dot" width="520">

### Your `~/.config`, backed up to git. Your secrets, left at home.

One POSIX shell script. No dependencies beyond git. No YAML. No regrets.

[![ci](https://github.com/anamulbahar/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/anamulbahar/dotfiles/actions/workflows/ci.yml) [![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE) ![POSIX sh](https://img.shields.io/badge/POSIX-sh-brightgreen) ![dependencies: git](https://img.shields.io/badge/dependencies-just%20git-orange)

</div>

---

You spent years getting your terminal *just right*. The prompt is perfect. Vim
behaves. The aliases are muscle memory. Then you get a new laptop, and for
about a week you're a stranger in your own shell.

The usual fixes ask a lot of you: move all your files into a special repo,
learn a template language, write a YAML manifest, make your home folder a git
repo, and keep a small prayer handy for the day you `git add .` your SSH keys.

**`dot` asks for nothing.** Your config stays exactly where it lives today. `dot`
keeps a *filtered* copy in a git repo, refuses to let a secret anywhere near
GitHub, and puts everything back on any machine with one command. If you change
your mind, it undoes itself.

```sh
dot capture     # copy the safe parts of ~/.config into the repo, commit
dot sync        # capture + pull + push, for people with more than one computer
dot apply       # put it all on this machine (backs up whatever it replaces)
dot rollback    # Ctrl+Z for your home folder
```

## The 10-second tour

```console
$ dot capture
==> Capturing ~/.config -> ~/dotfiles
  + vim/vimrc
  + sh/rc
  + yazi/theme.toml
  ~ htop/htoprc
Kept out - secrets found inside:
  x app/settings.ini  (secret: line 2: GitHub token)
Kept out by rules: gcloud, gh/ (1), github-copilot, rclone/ (1), ssh
Plugins recorded in dot.plugins (re-cloned, not copied):
  - vim/pack/github/start/copilot.vim  <- https://github.com/github/copilot.vim.git (release)
3 new, 1 updated, 40 unchanged.
  + committed: capture from laptop: 3 new, 1 updated
```

Notice what *didn't* happen. Your SSH keys, cloud credentials, rclone remotes
and that one config file with a token in it all stayed home. `dot` told you
*which line* looked dangerous and *what kind* of secret it was. It never
printed the secret itself, because your terminal scrollback is not a vault
either.

## Install: choose your adventure

### 🆕 "I have a brand new machine"

```sh
curl -fsSL https://raw.githubusercontent.com/anamulbahar/dotfiles/main/dot | sh -s -- bootstrap anamulbahar
```

That clones the repo, applies it, links the home-folder files, re-clones the
plugins and offers to put `dot` on your `PATH`. Swap in your own GitHub
username once you have your own copy. Prefer to read scripts before running
them? Good instinct: the whole program is [one file](dot).

### 🏠 "I already have a config I love"

```sh
git clone https://github.com/anamulbahar/dotfiles ~/dotfiles   # anywhere you like
~/dotfiles/dot init
```

`init` does the boring parts so you don't have to:

- creates the git repo and installs the secret guard;
- connects **your** GitHub account (it uses `gh` if installed, lets you pick
  when you have several accounts, and makes new repos **private** unless you say
  otherwise);
- puts `dot` in `~/.local/bin`;
- captures your config and pushes.

### 🍴 "I like *your* config and want my own copy"

Bootstrap or clone this repo, then run `dot init`. It notices the repo isn't
yours and offers to create your own copy under your account. It keeps this one
as `upstream`, so `dot upstream` merges future improvements into yours. Replace
`config/` with your own (`dot capture --prune`) or keep the bits you like.

## Why people switch

| | **dot** | chezmoi | yadm | GNU Stow | dotbot |
|---|:---:|:---:|:---:|:---:|:---:|
| Install | 📄 one `sh` file | Go binary | bash script | Perl | Python |
| Leaves your `~/.config` where it is | ✅ | ❌ source dir | ✅ repo is `$HOME` | ❌ | ❌ |
| Scans file *contents* for secrets before every commit | ✅ | ❌ | ❌ | ❌ | ❌ |
| Backs up everything it overwrites + one-command rollback | ✅ | ❌ | ❌ | ❌ | ❌ |
| Merges onto a machine that already has config | ✅ keep / overwrite / newer / review | prompts | ❌ | aborts | ❌ |
| Records plugin clones instead of copying them | ✅ | externals | ❌ | ❌ | ❌ |
| Per-OS and per-host variants | ✅ overlays + templates | templates | alternates | ❌ | ❌ |
| Gives anyone their own copy, then merges your updates | ✅ | ❌ | ❌ | ❌ | ❌ |
| Encrypted secrets *inside* the repo | ✅ opt-in (age or openssl) | ✅ | ✅ | ❌ | ❌ |
| Templates | ✅ variables + if/else | ✅ Go templates | ✅ | ❌ | ❌ |
| Works with nothing but `sh` and `git` | ✅ | ❌ | ❌ bash | ❌ | ❌ |

We'll be honest: chezmoi's Go templates can do more than ours (loops,
functions, password-manager lookups), so if your config is basically a program,
chezmoi is excellent. If you want your real config backed up and portable, a
safety net that never lets a plain-text key reach GitHub, encryption when you
ask for it, and templates for the bits that differ between machines, all in
one file you can read in an afternoon, you're home.

### Things `dot` will never do

- 🔑 Push a secret in plain text. Not your SSH keys, not your tokens, not your
  shell history. (Encrypted, if you ask it to. See below.)
- 🗑️ Delete your files. It adds and replaces, and everything it replaces is
  backed up first.
- 📦 Ask you to install Node, Python, Go, Rust or a feelings-based package manager.
- 📝 Make you learn YAML. Its config files are plain lists of paths.
- 🙈 Hang a script waiting for an answer nobody is there to give. Without a
  terminal it picks the safe default.

## How your secrets stay home

Every file in `~/.config` has to get past four independent bouncers. Any one of
them can stop it.

| # | Bouncer | What it checks |
|---|---|---|
| 1 | **Path rules** | Names that are never config: `ssh/`, `gnupg/`, `*.pem`, `id_rsa*`, `.netrc`, `*credential*`, `*token*`, `*secret*`, `rclone.conf`, `gh/hosts.yml*`, `github-copilot/`, `gcloud/`, `aws/`, password stores, databases, history, caches, `.DS_Store`, `*.icloud`... (`dot rules` shows them all) |
| 2 | **Content scan** | Private keys; GitHub, GitLab, OpenAI, Anthropic, AWS, Google, Slack, Stripe, npm, PyPI, Hugging Face, DigitalOcean and Telegram tokens; JWTs; passwords in URLs; rclone passwords; lines that assign a password, token, secret or API key |
| 3 | **`.gitignore` safety net** | The same high-risk names, in case someone runs `git add` by hand |
| 4 | **Pre-commit hook** | Scans *every* commit, made by `dot` or by you, and refuses the ones that contain secrets |

It also skips binary files, anything over 1 MiB, sockets, and symlinks that
point outside `~/.config`. It records git clones (Vim and Neovim plugins, say)
by URL and branch instead of copying them, so the repo stays small and nobody
inherits 120 MB of someone else's plugin cache.

```sh
dot explain gh/hosts.yml     # x gh/hosts.yml  kept out: rule 'gh/hosts.yml*'
dot explain vim/vimrc        # + vim/vimrc  backed up (ok)
dot ignore  'nvim/spell'     # never back this up
dot allow   'ssh/config'     # back this up anyway (the content is still scanned)
dot scan --history           # check the repo and every commit it ever had
```

A false positive? Put `dot:allow` in a comment at the end of that line.

`capture` also notes files that contain an **email address, an IP address or a
home-folder path**. Those are harmless in a private repo, but worth a second
look before you go public. (Ask how we know.)

## Moving into a machine that already has furniture

```sh
dot apply                # asks how to handle files that differ
dot apply --keep         # only add what's missing; your files win
dot apply --overwrite    # the repo wins (everything replaced is backed up)
dot apply --newer        # whichever changed last wins
dot apply --link         # symlink files into the repo instead of copying
dot apply -n             # dry run: show me, don't touch anything
```

The first apply on a lived-in machine also takes a full **snapshot** of
`~/.config`. Then every apply, adopt, link and rollback writes down exactly
what it replaced and what it created, so it can all be undone:

```sh
dot backups                         # list backups and snapshots
dot rollback                        # undo the last change
dot rollback                        # ...undo the undo (yes, really)
dot rollback 20261004-203015-apply  # undo a specific one
dot snapshot restore <id>           # extract a whole snapshot back
```

Backups and snapshots live in `~/.local/state/dot` on that machine. They are
never committed or pushed.

## Home-folder links

Like keeping everything in `~/.config`, with tidy symlinks from `~`? `dot.links`
lists them, and `dot capture` records the ones it finds:

```
.zshrc               sh/rc        source
.bashrc              sh/rc        source
.vim                 vim/
.ssh                 ssh/
.screenrc            screen/screenrc   os=linux
```

A target ending in `/` is a folder that's created (mode `700`) if it's missing.
On a fresh machine, `~/.ssh` points at a new private `~/.config/ssh`, ready for
keys that will never be backed up. Links are relative where possible, and
anything they replace is backed up.

### zsh and bash, done politely

One rc file, `sh/rc`, serves both shells. But your shell's own rc file might
already be doing real work: most Linux distributions ship a `~/.bashrc` with
tab completion, history settings and a colored prompt, and zsh frameworks live
in `~/.zshrc`. Replacing those with a symlink would quietly throw all of that
away. So `.zshrc` and `.bashrc` use **`source`** mode:

- **No file there yet** (a brand-new Mac has no `~/.zshrc`, and most Linux
  installs have none either)? It becomes a plain symlink to `sh/rc`.
- **A file already there?** `dot` keeps it and appends one guarded line:

  ```sh
  # added by dot: load sh/rc from ~/.config
  [ -r "$HOME/.config/sh/rc" ] && . "$HOME/.config/sh/rc"
  ```

  `dot apply` asks first: *[s]ource* (keep yours, add the line; the default),
  *[r]eplace* (a symlink, backed up) or *[k]eep*. Without a terminal it picks
  source, and `--keep` leaves the file alone.
- **Bash login shells** (SSH sessions, macOS Terminal running bash) read
  `~/.bash_profile` or `~/.profile` instead of `.bashrc`. `dot` makes sure
  whichever one bash actually reads loads `.bashrc`. It never creates a
  `.bash_profile` that would hide your distribution's `.profile`, and it leaves
  a `.profile` alone if it already loads `.bashrc` (as Ubuntu's and Debian's
  do). zsh needs none of this: it reads `.zshrc` in every interactive shell.
- The line is added once, backed up first, and `dot rollback` takes it out
  again.

```sh
dot adopt ~/.screenrc                    # -> ~/.config/screen/screenrc, linked back
dot adopt ~/.tmux.conf --as tmux/tmux.conf  # you pick the spot
dot link                                 # (re)create every link in dot.links
```

## One repo, many machines

```
config/                    every machine
overlay/os.darwin/         macOS only
overlay/os.linux/          any Linux
overlay/os.alpine/         one distribution (the ID in /etc/os-release)
overlay/host.<hostname>/   one specific machine
```

Overlays win in that order. When a file has an overlay copy for the current
machine, `capture` writes changes back into *that* copy, so a laptop's quirks
never leak onto your server.

Daily driver: `dot sync`. It captures, pulls (rebasing your capture on top),
pushes, and offers to apply anything your other machines sent.

## Templates: one file, every machine

Overlays copy whole files. When only a line or two differs, use a template.
Any repo file ending in `.tmpl` is rendered on `apply`:

```
# config/git/config.tmpl
[user]
    name = {{name}}
    email = {{email}}
{{if os=darwin}}
[credential]
    helper = osxkeychain
{{else}}
[credential]
    helper = cache
{{end}}
[core]
    editor = {{env:EDITOR}}
```

```ini
# dot.vars: plain "name = value"; later matching sections win
name  = Ada Lovelace
email = ada@example.com

[host=work-laptop]
email = ada@work.example.com
```

| You write | You get |
|---|---|
| `{{host}}` `{{os}}` `{{distro}}` `{{arch}}` `{{user}}` `{{home}}` `{{config}}` | facts about this machine |
| `{{name}}` | a value from `dot.vars` (sections: `[os=darwin]`, `[host=box]`, `[distro=alpine]`, `[name=value]`) |
| `{{env:NAME}}` | an environment variable (handy for values from a password manager) |
| `{{if os=darwin}}` … `{{else}}` … `{{end}}` | lines for some machines only; also `!=`, `host=`, or a bare name for "is set"; they nest |

```sh
dot template git/config     # turn an already-captured file into a template
dot render git/config       # see exactly what this machine will get
dot vars                    # every variable and its value here
```

`capture` knows which files come from templates and never overwrites a
`.tmpl` with its rendered output. A template that uses an unknown variable is
reported and skipped rather than half-installed. Rendering is pure POSIX `awk`:
no Go, no Python, no surprises.

## Encrypted secrets (opt-in)

By default `dot` keeps secrets *out* of the repo, full stop. If you'd rather
carry a few of them along (your `gh` login, an rclone remote, an API token
file), list them and they travel **encrypted**:

```sh
dot secret init                 # make a key: age if installed, else openssl
dot secret add gh/hosts.yml     # list it and encrypt it into secrets/
dot capture --secrets           # re-encrypt whatever changed
dot apply --secrets             # on another machine: decrypt into ~/.config
dot secret list                 # what's stored, and is it up to date?
```

- **Nothing happens without `--secrets`** (or `DOT_SECRETS=1`). Plain
  `capture` and `apply` never touch them, and a listed file is never copied in
  plain text, even by accident.
- **age** (authenticated, modern) is used when your key is an age identity.
  Otherwise **openssl**, which ships with macOS and practically every Linux:
  AES-256-CBC with PBKDF2-SHA256 (200,000 rounds) plus a keyed SHA-256
  integrity check, so a wrong key or a tampered file is refused instead of
  decrypted into garbage. Files made on a Mac decrypt on Linux and back again
  (tested both ways).
- **The key never enters the repo.** It lives at `~/.local/share/dot/key`
  (mode `600`; `DOT_KEY` moves it, `DOT_PASSPHRASE` replaces it). Keep a copy
  in your password manager and put it at the same path on your other
  machines. Lose it and the encrypted files are just noise. That's the point.
- The commit guard checks that everything in `secrets/` really is encrypted,
  and refuses the commit if it isn't.
- Decrypted files land with mode `600`, get the same backups as everything
  else, and `dot rollback` can take them away again.

## The rest of the Swiss Army knife

```sh
dot status                # what changed, what capture/apply would do
dot diff [path]           # this machine vs the repo
dot plugins update        # git pull every recorded plugin
dot packages dump         # Brewfile, pixi global manifest, apk/apt/dnf/pacman lists
dot packages install      # reinstall them on a new machine (asks first)
dot doctor                # git, gh, hooks, broken links, iCloud placeholders...
eval "$(dot completion)"  # tab completion for bash and zsh
dot git log --stat        # any git command, run inside the repo
cd "$(dot path)"          # teleport to the repo
```

**Hooks.** Executable scripts named `pre-capture`, `post-capture`, `pre-apply`
or `post-apply` in `hooks/` run at those moments. They get `DOT_ROOT`,
`DOT_TARGET`, `DOT_OS`, `DOT_DISTRO` and `DOT_HOST`. `bootstrap` asks before
running hooks from a repo, and `DOT_NO_HOOKS=1` turns them off.

## Batteries included: what's in this repo's `config/`

This repo is also the author's real, everyday setup, with the personal parts
left out:

| | |
|---|---|
| `sh/rc` | One POSIX rc for `sh`, `bash` and `zsh`: prompt, colors, macOS and Linux aliases, a `PATH` that only ever *adds* folders (so it's safe on top of any distribution), and a set of polite installers (below) |
| `vim/vimrc` | Relative numbers, netrw as a file tree, sensible search, `habamax` on Vim 9 |
| `vifm/`, `yazi/` | Two terminal file managers, because one is never enough |
| `htop/`, `conda/`, `gh/` | The small settings you forget about until they're gone |
| `sh/apk-*` | Quality-of-life helpers for Alpine (including iSH on iPhone) |

The installers in `sh/rc` check whether a tool is already there. If not, they
download the vendor's **official** installer to a temporary file and run it
with the shell it was written for. Downloading first means a half-finished
download never runs, which plain `curl | sh` can't promise.

| Function | Installs |
|---|---|
| `xcode_install` | Xcode Command Line Tools (macOS) |
| `brew_install` / `brew_uninstall` | Homebrew |
| `pixi_install` | pixi |
| `claude_install` | Claude Code (`claude`) |
| `codex_install` | OpenAI Codex CLI (`codex`) |
| `antigravity_install` | Google Antigravity CLI (`agy`) |
| `copilot_install` | GitHub Copilot CLI (`copilot`) |
| `ai_install` | all four AI CLIs, then a report of anything that failed |
| `copilot_setup` | the Copilot plugin for Vim |

Each one also has a hyphenated alias (`claude-install`, `ai-install`, and so on).

And then there's **`update`**, the one command to rule them all. pixi is the
default for CLI tools everywhere, so it updates pixi and its global tools
first. Then it does the rest of the machine: Homebrew on macOS, or the system
packages on Linux with whichever manager is there (`apt`, `dnf`, `yum`,
`zypper`, `pacman` or `apk`), using `sudo` or `doas` only when you aren't root.
Same word, every computer you own.

## Options and environment

| Option | Meaning |
|---|---|
| `-n`, `--dry-run` | show what would happen, change nothing |
| `-y`, `--yes` | assume yes (non-interactive) |
| `-v` / `-q` | more / less output |
| `-C <dir>` | use this repo |
| `--target <dir>` | manage this folder instead of `~/.config` |

| Variable | Default |
|---|---|
| `DOT_DIR` | the folder holding the `dot` script |
| `DOT_TARGET` | `$XDG_CONFIG_HOME`, or `~/.config` |
| `DOT_STATE` | `$XDG_STATE_HOME/dot`, or `~/.local/state/dot` |
| `DOT_MODE` | `copy` (or `link`) |
| `DOT_STRATEGY` | `ask` (or `overwrite`, `keep`, `newer`) |
| `DOT_MAX_SIZE` | `1048576` bytes |
| `DOT_SECRETS` | unset (`1` = always `--secrets`) |
| `DOT_KEY` | `~/.local/share/dot/key` |
| `DOT_PASSPHRASE` | unset (an openssl passphrase instead of a key file) |
| `DOT_NO_HOOKS`, `NO_COLOR` | unset |

## Runs on more shells than most people know exist

Plain POSIX `sh`: no arrays, no `local`, no `[[ ]]`, no `readlink -f`, no
`sed -i`, no GNU-only flags. The test suite (131 end-to-end checks in a
throwaway `$HOME`, 135 when age is installed, with fake secrets assembled at
run time) passes on:

- **macOS**: `sh`, `dash`, `bash`, `ksh`, `zsh`
- **Linux, GNU tools**: `dash`, `bash`
- **busybox ash with only busybox utilities** (its own `awk` renders the
  templates): the Alpine experience
- **git as old as 2.17, OpenSSL 1.1.1 and LibreSSL**, with secrets encrypted
  on one and decrypted on the other

CI repeats all of it on Ubuntu, macOS and Alpine, and on `mksh` and `yash` too.

```sh
sh tests/run.sh dash      # bring your own shell
```

File names with spaces are fine. Names with tabs or newlines are skipped
politely, and reported.

## FAQ

**Is it safe to make my dotfiles public?**
That's what the four bouncers are for. Run `dot scan --history` before you flip
the switch, and read the privacy notes `capture` prints. A secret that was ever
pushed stays public even after you delete it, so rotate it and rewrite history.
`dot` is built so you never get there.

**And encrypted secrets in a public repo?**
They're as safe as your key and your passphrase habits. age and AES-256 are not
the weak link; a key file left lying around is. If you'd rather not bet on that
at all, leave `dot secret` alone: the default is still "secrets stay home".

**Why POSIX `sh` and not Go or Python?**
Because the machine you're setting up doesn't have Go or Python yet. It does
have `sh`. It always has `sh`.

**What if `dot` has a bug and eats my config?**
It would have to get past the snapshot, the per-change backups and its own
rollback first. It also never deletes your files. We still recommend backups of
your backups, because we're engineers and we've met computers.

**Can I use it for something other than `~/.config`?**
Yes: `dot --target ~/some/folder capture`. It's a filtered, versioned, undoable
copy machine. Point it where you like.

**Why is it called `dot`?**
It manages dotfiles, and every other name was taken by a tool that needs a YAML
file.

## Contributing

Issues and pull requests are welcome. The whole program is [`dot`](dot) and the
whole test suite is [`tests/run.sh`](tests/run.sh). Please keep both POSIX, and
run `shellcheck -s sh dot` and `sh tests/run.sh dash` before you send.

## License

[MIT](LICENSE). Use it, fork it, improve it, tell your friends.

---

<div align="center">

If `dot` saved you an afternoon, a ⭐ helps other people find it.

</div>

## Project status

v1.3.0 adds opt-in encrypted secrets (age or openssl) and templates
(variables, `dot.vars` sections, environment values and `if/else`), on top of
1.2.0's polite `source` mode for `~/.zshrc` and `~/.bashrc`. The test suite
passes on macOS (`sh`, `dash`, `bash`, `ksh`, `zsh`) and on Linux (`dash`,
`bash`, busybox ash with busybox utilities, git 2.17, OpenSSL 1.1.1), and CI
adds Alpine, `mksh` and `yash`. shellcheck is clean. Ideas for later: native
Windows support.

### What's in the repo

```
dot                  the whole program
config/              your captured ~/.config (*.tmpl files are templates)
overlay/             per-OS and per-host variants (optional)
secrets/             encrypted files, only if you use dot secret
dot.links            home-folder links      dot.plugins   plugin clones
dot.ignore           your extra rules       dot.secrets   files to encrypt
dot.vars             template values        assets/       the logo
tests/run.sh         the test suite
```
