# skillz

A collection of custom skills for Claude Code. Each skill is self-contained under `skills/<skill-name>/`. Install any skill into a Claude Code environment with `./install.sh`.

## Layout

```
skills/                         one directory per skill
install.sh                      installer script
tests/                          shared test scripts
docs/superpowers/specs/         design specs
docs/superpowers/plans/         implementation plans
```

## Install a skill

```bash
./install.sh <skill-name>                              # global (~/.claude/skills)
./install.sh <skill-name> /path/to/target/repo         # single project
```

## List available skills

```bash
./install.sh --list
```

## Uninstall

```bash
./install.sh --uninstall <skill-name>                        # global
./install.sh --uninstall <skill-name> /path/to/target/repo   # single project
```

## Skills

### review-go-mistakes

Reviews Go source code against the 100 mistakes from *100 Go Mistakes and How to Avoid Them* (Teiva Harsanyi, Manning, 2022). Writes a markdown report grouped by book category. Report language follows ASD-STE100 Simplified Technical English.

Install:

```bash
./install.sh review-go-mistakes                        # global
./install.sh review-go-mistakes /path/to/target/repo   # single project
```

See [skills/review-go-mistakes/SKILL.md](skills/review-go-mistakes/SKILL.md) for full details.
