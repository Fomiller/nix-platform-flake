# Per-language build/test/lint commands, shared by the justfile and CI workflow
# templates so the two never drift from each other.
#
# Adding a new archetype ("Support repository archetypes" in FOM-51's future
# enhancements) means adding one more attrset here — every other template
# (workflows, justfile, Dockerfile) is written generically against these
# fields and needs no changes.
{ language }:
let
  archetypes = {
    go = {
      buildImage = "golang:1.23";
      runtimeImage = "gcr.io/distroless/static-debian12";

      # Spliced into the CI/release workflow templates right after
      # `actions/checkout` — see workflows.nix's `setupStepAt6`.
      setupStep = ''
        - uses: actions/setup-go@v5
          with:
            go-version-file: go.mod
            cache: true'';

      # Used verbatim as `run:` steps in CI and as recipe bodies in the
      # generated justfile — kept as single-line strings so they can be
      # dropped into either context without reflowing.
      buildCmd = "go build ./...";
      testCmd = "go test ./... -race -cover";
      lintCmd = "go vet ./...";

      # A function of the (possibly repo-overridden) images, not a
      # pre-baked string: mkRepository.nix calls this *after* merging
      # repoConfig.overrides.language, so overriding buildImage/runtimeImage
      # actually changes the emitted Dockerfile instead of the override
      # missing a value that was already baked in here.
      mkDockerBuild = { buildImage, runtimeImage }: ''
        FROM ${buildImage} AS build
        WORKDIR /src
        COPY go.mod go.sum ./
        RUN go mod download
        COPY . .
        RUN CGO_ENABLED=0 go build -o /out/app ./...

        FROM ${runtimeImage}
        COPY --from=build /out/app /app
        ENTRYPOINT ["/app"]'';
    };

    rust = {
      buildImage = "rust:1.82";
      runtimeImage = "gcr.io/distroless/cc-debian12";
      setupStep = ''
        - uses: dtolnay/rust-toolchain@stable'';
      buildCmd = "cargo build --release";
      testCmd = "cargo test --all-features";
      lintCmd = "cargo clippy -- -D warnings";
      mkDockerBuild = { buildImage, runtimeImage }: ''
        FROM ${buildImage} AS build
        WORKDIR /src
        COPY . .
        RUN cargo build --release

        FROM ${runtimeImage}
        COPY --from=build /src/target/release/app /app
        ENTRYPOINT ["/app"]'';
    };
  };
in
  # `attrname or default` isn't enough here because we want a descriptive
  # error, not a silent `null`, when repo.nix declares an unsupported
  # language — this is the only validation mkRepository does on `language`.
  archetypes.${language} or (throw
    "mkRepository: unsupported language '${language}' (known: ${toString (builtins.attrNames archetypes)})")
