# dotfiles #

Yet another dotfiles repository.

## Installation ##

- `./bootstrap.sh`
- `./install-global-npm-packages.sh`

## Usage ##

`bootstrap.sh` symlinks the files listed in its `FILES`/`CONFIG_DIRS` arrays into
`$HOME` (or `$HOME/.config`), so editing a file in this repo takes effect the next
time you open a new shell. Re-run `./bootstrap.sh` after adding a new file that
needs to be linked.

## Contributing ##

- Group config for one external tool under its own top-level directory (e.g.
  `k9s/`, `ripgrep/`), and add its files to the `FILES`/`CONFIG_DIRS` arrays in
  `bootstrap.sh` so they get symlinked.
- `claude/` holds the Claude Code config worth version controlling
  (`CLAUDE.md`, `RTK.md`, `settings.json`, custom `skills/`). Most of
  `~/.claude` is runtime/session state (history, cache, projects, backups)
  and is intentionally left untracked, as is `settings.local.json`, which
  Claude Code treats as machine-local.
- Zsh plugin/agent config follows a conf.d pattern: add one file per plugin under
  `zsh/agent.d/<plugin>.zsh`. Every `*.zsh` file there is sourced automatically by
  `zsh/.zshrc` — no changes to `.zshrc` needed.
- Keep `zsh/.zshrc` itself organized with vim fold markers (`# Section {{{1` /
  `{{{2`); it starts with `vim:fdm=marker` so folds work automatically in vim.

## Testing zsh changes ##

- Check for syntax errors without executing anything: `zsh -n zsh/.zshrc`.
- Source directly in the current shell to try changes without a new terminal:
  `source zsh/.zshrc`.
- Source in a clean subshell to catch issues masked by your current shell's
  state: `zsh -c 'source zsh/.zshrc'`.
- To test exactly as it runs once installed (through the `$HOME` symlink), run
  `./bootstrap.sh` and open a new terminal tab.
