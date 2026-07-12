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
