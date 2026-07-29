# Example reference file

> Reference files hold detail that the SKILL.md body links to but does not need inline.
> This keeps the body under the line cap and loads the detail only when it is actually
> needed (progressive disclosure). Files longer than 100 lines must open with a table of
> contents, like this one, so a partial read still reveals the full scope.

## Table of contents

1. [Why reference files exist](#why-reference-files-exist)
2. [The one-level-deep rule](#the-one-level-deep-rule)
3. [When to extract a section](#when-to-extract-a-section)
4. [Time-sensitive content](#time-sensitive-content)

## Why reference files exist

`SKILL.md` is loaded into context every time the skill triggers. Detail that is only
needed mid-task — long tables, edge-case handling, worked examples — belongs in a
reference file so it does not cost tokens on every invocation.

## The one-level-deep rule

`SKILL.md` may link to reference files. A reference file must NOT link to another
reference file. Nested references cause partial reads (`head -100`) that miss content,
so the navigation graph stays flat: body → reference, never reference → reference.

## When to extract a section

Extract the heaviest, least-frequently-needed sections first: failure-mode tables,
appendix templates, rare edge-case guidance. Aim to keep the body at 380–450 lines with
headroom before the 500-line hard cap.

## Time-sensitive content

Point-in-time facts (validation dates, coverage percentages) should go in a `<details>`
collapsible so the body states the durable rule and the dated baseline is one click away.

<details>
<summary>Example dated baseline</summary>

This starter kit was generated as a generic template; replace this section with your own
dated baselines as your skill evolves.

</details>
