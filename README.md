# skillz

A personal marketplace of Claude Code plugins.

## Plugins

### craft

Spec-driven development workflow for Claude Code: brainstorming, planning, subagent-driven execution, code review, and branch finishing.

Location: [plugins/craft/](plugins/craft/)

### go-mistakes

Reviews Go source code against the 100 mistakes from *100 Go Mistakes and How to Avoid Them* (Teiva Harsanyi, Manning, 2022). Produces a markdown report grouped by book category, written in ASD-STE100 Simplified Technical English.

Location: [plugins/go-mistakes/](plugins/go-mistakes/)

## Install

Add this marketplace to Claude Code:

```
/plugin marketplace add Malin-C/skillz
```

Then install individual plugins:

```
/plugin install craft@skillz
/plugin install go-mistakes@skillz
```

## Layout

```
.claude-plugin/marketplace.json     marketplace manifest listing all plugins
plugins/<name>/                     one directory per plugin
  .claude-plugin/plugin.json        plugin manifest
  skills/                           one subdirectory per skill
  agents/                           agent definitions (optional)
  commands/                         slash commands (optional)
  hooks/                            hooks (optional)
tests/                              shared test scripts
docs/craft/specs/                   design specs
docs/craft/plans/                   implementation plans
```

## License

Plugins in this repository are MIT-licensed. See [plugins/craft/LICENSE](plugins/craft/LICENSE).
