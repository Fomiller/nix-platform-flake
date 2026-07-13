# Thin wrapper: the actual Dockerfile body lives on the language archetype
# (language.nix's dockerBuild) so it can share buildImage/runtimeImage with
# whatever else needs them. This module's only job is prefixing the
# ownership header.
{ lang, header }: ''
  ${header}
  ${lang.dockerBuild}
''
