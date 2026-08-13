# STE word substitutions

The full ASD-STE100 dictionary is a controlled document with about 1000 approved words. This file is a practical subset — the pairs that come up most often in software writing (chat replies, docs, commit messages). It is not a certified copy of the standard; for aerospace/defense deliverables that must pass a formal STE check, consult the official specification.

## Not approved → approved

| Not approved | Use instead |
|---|---|
| utilize | use |
| commence, initiate | start, begin |
| terminate | stop, end |
| prior to | before |
| subsequent to, following | after |
| in order to | to |
| due to the fact that, owing to the fact that | because |
| in the event that | if |
| in the case where | if, when |
| approximately | about |
| sufficient | enough |
| assist | help |
| attempt (verb) | try |
| obtain | get |
| purchase | buy |
| facilitate | help, make easier |
| indicate | show |
| ensure | make sure |
| verify | check |
| optimum, optimal | best |
| numerous | many |
| additional | more, extra |
| endeavor | try |
| proceed | go, continue |
| regarding, concerning, with respect to | about |
| implement (verb) | put in place, do, add |
| functionality | function |
| methodology | method |
| leverage (verb) | use |
| whilst | while |
| amongst | among |
| via | by, through |
| per | for each |
| e.g. | for example |
| i.e. | that is |
| etc. | list the items, or write "and other items" |
| a number of | some, many, or an exact count |
| shall, should (obligation) | must |
| and/or | and — or — pick the one you mean |

## Approved procedure verbs

For step-by-step instructions, prefer this small, unambiguous verb set over synonyms: check, clean, close, connect, disconnect, do, fill, find, follow, get, give, hold, install, keep, lock, loosen, make, move, open, operate, put, read, release, remove, replace, send, set, start, stop, take, tighten, turn, use, write.

Do not swap between synonyms for the same action across a document (for example "remove" and "delete" for the same operation) — pick one and reuse it.

## Noun clusters

STE caps noun strings at 3 nouns used as one adjective phrase. Longer clusters are ambiguous — a reader cannot tell which noun modifies which.

- Not approved: "the database connection pool timeout setting"
- Approved: "the timeout setting for the database connection pool"

Break the cluster with prepositions ("for", "of", "in") until each phrase reads as one clear relationship.

## Verb tense

STE allows: simple present, simple past, simple future, and the imperative. Avoid:

- Present perfect: "The job has completed" → "The job completed" or "The job is complete."
- Past perfect: "The build had failed before the retry" → "The build failed. Then it retried."
- Continuous forms used as narration: "The service is now handling requests" → "The service handles requests."

## Extended example

Not STE:
> Prior to merging, please ensure that all of the relevant tests have been run and that the reviewer's comments have been addressed, as failure to do so could potentially result in a regression being introduced further down the line.

STE:
> Before you merge, run all the relevant tests. Fix the issues the reviewer found. If you skip this step, you can add a regression later.

Not STE:
> The API utilizes a token-based authentication methodology, and clients should include the token in the request header, otherwise the request will be rejected by the server.

STE:
> The API uses token-based authentication. Add the token to the request header. If the token is not there, the server rejects the request.
