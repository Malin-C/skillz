---
name: writing-ste100
description: Use when writing any prose for the user or in files — replies, explanations, documentation, commit messages, comments, reports, READMEs — to keep the language in ASD-STE100 Simplified Technical English (controlled English with approved words, short sentences, active voice, no idioms).
---

# writing-ste100

## Overview

ASD-STE100 is the aerospace industry's controlled-English writing standard. It cuts sentences to one clear idea, bans jargon and idiom, and picks one word per meaning. This skill applies that standard to text you write.

## Scope

STE applies to text you compose: chat replies, explanations, docs, commit messages, comments, PR descriptions, reports.

STE does NOT apply to: code syntax, identifiers, file paths, command output, error messages, or text you quote verbatim from the user or a third source. Do not rewrite quoted material to fit STE.

## Rules

1. **Sentence length.** Instructions: 20 words or fewer. Descriptions: 25 words or fewer. One idea per sentence.
2. **Active voice.** "The build fails" not "The build has been failed." Name the actor.
3. **Simple tense.** Use present, simple past, simple future, or the imperative. Avoid perfect and continuous tenses ("has been running", "will have completed") where a simple tense says the same thing.
4. **Imperative for instructions.** "Run the tests." not "You should run the tests." or "The tests should be run."
5. **One word, one meaning.** Pick one term for a concept and reuse it. Do not vary vocabulary for style — do not switch between "delete", "remove", and "erase" for the same action; pick one. See `references/word-substitutions.md` for common not-approved → approved swaps.
6. **No gerunds as nouns.** "the operation of the switch" not "the operating of the switch". "-ing" words are fine as adjectives ("the running process") but not as stand-in nouns for an action.
7. **No noun clusters.** Break up chains of more than three nouns strung together. "pump drive shaft" is fine; "fuel pump drive shaft housing bracket" is not — rephrase with prepositions.
8. **If/then for conditions.** "If the file is missing, then create it." not implied or buried conditionals.
9. **No multiple negatives.** State the positive case. "Only admins can edit this" not "Non-admins cannot not edit this."
10. **No idioms, metaphors, or jargon.** No "ballpark figure", "low-hanging fruit", "under the hood" (unless it's an established technical term the audience needs).
11. **Numbers as numerals.** "3 retries" not "three retries", except when a numeral would start a sentence.
12. **Consistent reference.** Refer to the same object with the same term every time it appears in a passage.
13. **Short paragraphs.** Group related sentences; keep procedures as one action per numbered step.

## Example

Not STE (32 words, passive, idiom, gerund-noun):
> The configuration file should be updated prior to deployment, otherwise the service might not be picking up the new settings, which could be a real headache down the line.

STE (3 short sentences, active, imperative):
> Update the configuration file before you deploy. If you do not update it, the service does not read the new settings. This can cause errors later.

## Reference

`references/word-substitutions.md` — common not-approved → approved word pairs, plus extended before/after examples.
