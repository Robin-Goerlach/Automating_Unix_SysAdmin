# Version-control workflows for Unix sites

Deutsch: [Deutsche Fassung](VERSION-CONTROL.de.md)

The repository uses Git and its commit history is the only project history claimed by SASD. No CVS or Subversion revisions, `$Id$` values, release dates, maintainers, or migrations are invented.

The source layout is intentionally suitable for traditional Unix change control. A site administrator could place the plain-text scripts, configuration files, fixtures, and manuals under a CVS or Subversion working copy and commit changes with the corresponding tool. That is a supported organizational option, not a claim that SASD used CVS or Subversion.

When preserving a checkout for an older Unix host:

1. Keep source, configuration templates, and writable runtime data in separate directories.
2. Review the complete diff before installing a file.
3. Record the actual repository revision and operator in the local change log.
4. Keep secrets and generated status data outside the public source tree.
5. Use the repository's Git commit as the authoritative current revision when Git is available.

Do not add generated CVS `$Id$`, Subversion revision markers, or fabricated historical metadata to source files. Compatibility with a traditional version-control client concerns file organization and operator procedure; it does not change the runtime interfaces or licensing boundaries.
