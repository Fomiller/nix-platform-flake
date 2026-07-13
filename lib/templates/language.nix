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
    # `rec` so dockerBuild can reference buildImage/runtimeImage below
    # instead of duplicating the version string — bumping a Go version is
    # then a one-line change that lands in both setupStep's implied
    # toolchain and the Dockerfile.
    go = rec {
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

      # The generated Dockerfile's entire body (see dockerfile.nix).
      dockerBuild = ''
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

    rust = rec {
      buildImage = "rust:1.82";
      runtimeImage = "gcr.io/distroless/cc-debian12";
      setupStep = ''
        - uses: dtolnay/rust-toolchain@stable'';
      buildCmd = "cargo build --release";
      testCmd = "cargo test --all-features";
      lintCmd = "cargo clippy -- -D warnings";
      dockerBuild = ''
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
