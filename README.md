# Subsea Cable website and community

[Read the documentation](https://4gentsInc.github.io/subsea_cable_webpages/),
[report a finding](https://github.com/4gentsInc/subsea_cable_webpages/issues/new/choose),
or propose a language improvement under `proposals/`.

This repository contains the site builder, generated static output, and public
discussion. Language document originals are maintained separately. A finding or
proposal here is evidence for review; merging it does not activate language
behavior. See [Contributing](CONTRIBUTING.md).

## Local source layout

```text
pages/
  language/             # ignored local link or checkout of the language sources
    export/             # the document originals
  site/mkdocs.yml       # docs_dir: ../language/export
  scripts/build.py
  build/                # generated output, committed for deployment
```

Paths in `site/mkdocs.yml` are relative to that configuration file. Its
`../language/export` refers to `pages/language/export`, including when
`pages/language` is a symbolic link. No submodule, remote source fetch, or
document synchronization is performed by the builder.

Contributors without access to the source checkout can still submit findings,
SCP drafts, and builder changes. Rebuilding the full site requires the arranged
local `language/export/` source directory.

## Build and publish

Install Python 3.13 or newer, then run from this repository:

```sh
python -m venv .venv
# Activate .venv using your shell's activation command.
python -m pip install --requirement site/requirements.txt
python scripts/build.py
```

The command checks document selection, builds strictly, validates links and
anchors, and writes only generated public files to `build/`. There is no second
editable Markdown copy in this repository.

Review and commit the generated `build/` output alongside relevant builder
changes. A push affecting `build/` on `main`, or a manual run of the deployment
workflow, publishes that output to GitHub Pages. Actions **do not rebuild** the
site and do not need private source access. Set the repository's Pages source
to **GitHub Actions**.

```sh
git add build
git commit -m "site: publish updated documentation"
git push origin main
```

For a reviewed change, push your branch and open a PR instead. The `validate`
workflow checks the committed output and public intake tools without a
`language/` directory. To run those output checks locally:

```sh
python .github/scripts/check_site_publication.py --site-dir build --output-only
```
