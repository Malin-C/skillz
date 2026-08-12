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

Global install (all projects):

```bash
./install.sh <skill-name>
```

Project install (single repo):

```bash
./install.sh <skill-name> /path/to/target/repo
```

List available skills:

```bash
./install.sh --list
```

Uninstall:

```bash
./install.sh --uninstall <skill-name>                        # global
./install.sh --uninstall <skill-name> /path/to/target/repo   # project
```

## Skills

See individual skill folders under `skills/` for details.
