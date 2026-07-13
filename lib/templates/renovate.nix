# Not parameterized on `lang` — Renovate config is the same shape
# regardless of language archetype, so this only takes repoConfig (and
# doesn't even use it yet; kept for symmetry with the other templates and
# as the natural place to add per-repo Renovate overrides later, e.g.
# repoConfig.renovate.extraPackageRules).
#
# JSON has no comment syntax, so this hand-writes the ownership banner as
# `//` lines instead of using header.nix — Renovate's own config parser
# accepts JSON5, so `//` comments here are valid, not a lint error.
#
# The "flake" manager + packageRules block is what makes the update
# workflow in FOM-51 self-sustaining: Renovate watches flake.lock's
# `platform` input like any other dependency and opens a PR when a new
# platform tag appears, grouped separately from other flake input bumps.
{ repoConfig }: ''
  {
    // GENERATED FILE — managed by the fomiller platform flake.
    // Do not edit manually: changes will be overwritten by `nix run .#generate`.
    // To customize, edit repo.nix in this repository instead.
    "$schema": "https://docs.renovatebot.com/renovate-schema.json",
    "extends": ["config:recommended"],
    "flake": {
      "enabled": true
    },
    "packageRules": [
      {
        "matchManagers": ["flake"],
        "matchPackageNames": ["platform"],
        "groupName": "platform flake",
        "automerge": false
      }
    ]
  }
''
