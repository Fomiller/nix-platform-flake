# repo.nix's `codeowners` list becomes a single blanket `* @owner1 @owner2`
# rule. Defaults to `@Fomiller` alone so a repo.nix that doesn't mention
# codeowners at all still gets a valid, non-empty CODEOWNERS file rather
# than silently omitting one.
{ repoConfig, header }:
let
  owners = repoConfig.codeowners or [ "@Fomiller" ];
  ownersLine = builtins.concatStringsSep " " owners;
in ''
  ${header}
  * ${ownersLine}
''
