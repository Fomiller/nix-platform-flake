# Per-language build/test/lint commands, shared by the justfile and CI workflow
# templates so the two never drift from each other.
{ language }:
let
  archetypes = {
    go = {
      buildImage = "golang:1.23";
      runtimeImage = "gcr.io/distroless/static-debian12";
      setupStep = ''
        - uses: actions/setup-go@v5
          with:
            go-version-file: go.mod
            cache: true'';
      buildCmd = "go build ./...";
      testCmd = "go test ./... -race -cover";
      lintCmd = "go vet ./...";
      dockerBuild = ''
        FROM golang:1.23 AS build
        WORKDIR /src
        COPY go.mod go.sum ./
        RUN go mod download
        COPY . .
        RUN CGO_ENABLED=0 go build -o /out/app ./...

        FROM gcr.io/distroless/static-debian12
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
      dockerBuild = ''
        FROM rust:1.82 AS build
        WORKDIR /src
        COPY . .
        RUN cargo build --release

        FROM gcr.io/distroless/cc-debian12
        COPY --from=build /src/target/release/app /app
        ENTRYPOINT ["/app"]'';
    };
  };
in
  archetypes.${language} or (throw
    "mkRepository: unsupported language '${language}' (known: ${toString (builtins.attrNames archetypes)})")
