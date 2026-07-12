{ repoConfig, header }:
let
  owners = repoConfig.codeowners or [ "@Fomiller" ];
  ownersLine = builtins.concatStringsSep " " owners;
in ''
  ${header}
  * ${ownersLine}
''
