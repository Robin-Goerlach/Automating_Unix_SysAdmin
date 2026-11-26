# SASD Automating Unix SysAdmin — Agent Instructions

Deutsch: [Deutsche Fassung](AGENTS.de.md)

These instructions apply to the entire repository.

## Mission and non-goals

Develop an original, reliable, historically plausible Unix administration collection. Preserve the feel of independently useful scripts collected across multiple technological generations. Do not rebuild Apress's tutorial infrastructure, copy its code, imitate its text, or claim to be a historically discovered archive.

The primary target profile is 1999. Features from 2002–2009 require a clearly marked later profile. CFEngine 1 belongs to the 1999 profile; CFEngine 2, Nagios and 2009 book-specific components do not. See docs/TIMELINE.md.

## Source boundaries

- Books are references for general *ideas*, architecture concerns, and topic coverage. Design, naming, data formats, algorithms, fixtures and prose independently.
- Preserve third-party copyright and license notices. Do not paste book listings or proprietary Big Brother code or configuration under the repository MIT license.
- Keep docs/BOOK-MAP.md accurate but not a chapter-by-chapter code transcription.
- Reference original third-party product names descriptively; avoid suggesting endorsement.

## Engineering

- Prefer POSIX sh, awk, sed and era-appropriate Perl core modules for historical programs.
- No mandatory Node, Python, Docker, systemd, web service or new runtime in the historical execution path.
- Use newline-oriented text and clear interfaces; permit independent tools without a forced central framework.
- Explain source/input trust boundaries and errors. Reject unsafe identifiers and path traversal. Avoid executing untrusted input as shell code.
- Administrative changes must require an explicit operation and be limited to disposable test systems until a separate acceptance gate is documented.
- New CFEngine/MRTG/RRD examples are **unverified templates** until actually validated with the corresponding version. Record exact version/OS before claiming compatibility.
- Testing on a modern CI runner does not prove operation on an original SunOS/Solaris/FreeBSD/AIX/HP-UX release or Perl 5.004.
- Keep Unix administration programs readable for human operators: use meaningful indentation and names, small functions, one statement per line where practical, and comments for interfaces and non-obvious safety decisions. Avoid compressed Perl or shell and broad cosmetic rewrites.

## Workflow

1. Update local `main` with `git pull --ff-only` and verify a clean working tree.
2. Read the README, architecture, roadmap, security document, and affected source and tests.
3. Identify the compatibility profile and independently useful task.
4. Implement the smallest bounded tool or integration. Update fixtures and negative tests.
5. Run `make test`, and record optional integration testing separately.
6. Update English and German technical documentation in the same change; run the documentation-pair check.
7. Review the diff, commit directly to `main` for ordinary work, push it, and verify GitHub Actions. Temporary branches are reserved for risky or separately reviewed work.
8. Avoid unrequested changes to SASD-Sysadmin/freeware: that is a separate repository.
9. Do not fabricate test results, release dates, history or provenance.

## Documentation maintenance

English Markdown is canonical and German Markdown is maintained in parallel using the `.de.md` suffix. Every meaningful change to an English technical document must update its German companion in the same commit. `make test` runs a lightweight pair and relative-link check; it does not prove translation quality.

Commits on main are acceptable for this solo experimental project when authorized and validated; do not force push, rewrite history, or delete unrelated work. Always confirm the current HEAD before publication.

## Session closeout and context handoff

- At the beginning of every development session, read `../logs/LAST-SESSION.md` and, when needed, the complete archive it references.
- At the beginning of every development session, also read the complete `../logs/MASTER-ASSIGNMENT.md`. This is the durable strategic and technical assignment; it must not be replaced by, or rewritten as, a shortened session summary.
- At the end of every development assignment, create one complete UTC-stamped session archive in `../logs`, even when the work is partial or a push, CI run, network connection or technical gate fails.
- Update `../logs/LAST-SESSION.md` only after the complete archive exists and is readable. The handoff must identify the actual repository state, tests, commits, remote/CI status, blockers and next safe step.
- Before recommending `/new`, complete and verify the session archive and handoff. After an interruption, first check whether the previous development state was documented and repair the missing documentation at the next opportunity.
- Do not create archives for ordinary progress messages. Never record secrets, tokens, private keys or production data, and never describe unverified tests, pushes or CI as successful.

Session archival is part of the definition of done, not an optional reporting task.

## Definition of done

A new tool needs a documented purpose, supported input and output, a safe failure mode, an offline fixture and at least one negative test. A third-party integration additionally needs a version matrix and direct acceptance evidence before being described as functional on a historical target. Planned tasks are not completed tasks.
