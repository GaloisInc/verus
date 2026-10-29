Below, you can find instructions for:

- [Building Verus](#building-the-project)
  - [Using Cargo](#build-with-cargo)
  - **[DEPRECATED]** [Using Vargo](#build-with-vargo)
- [Running Verus on the command line](#running-the-verifier)
- [Using Verus in an IDE](#ide-support)

# Building the Project

The main project source is in `source`.

`tools` contains miscellaneous scripts for Verus development.

See [`source/CODE.md`](source/CODE.md) for more details about files in `source`. See the
[official docs](https://rustc-dev-guide.rust-lang.org/) for more about the
normal Rust compiler.

## Step 1: Setup Z3

Change directory to `source`: `cd source`

### On Windows: Get Z3 and set the `VERUS_Z3_PATH` environment variable

Download the [Z3 binaries](https://github.com/Z3Prover/z3/releases).
Make sure you get Z3 4.16.0.
The Z3 `bin` folder contain the executable `z3.exe`.
Set the `VERUS_Z3_PATH` environment variable to the path of the Z3 executable file.

### On Unix/macOS/Windows: Get a local Z3

From `source`, use the script `./tools/get-z3.sh` (on Unix/macOs) or `./tools/get-z3.ps1` (on Windows) to download Z3.
The cargo `.config` will correctly set the `VERUS_Z3_PATH` environment variable for the verifier to find Z3.
If you run the verifier binary manually, set `VERUS_Z3_PATH` to `source/z3` or `source/z3.exe`.

## Step 2: Ensure you have a recent rustup installed

If you don't have it yet, obtain rustup from https://rustup.rs.
We have only tested recent versions (1.28.0); older versions of rustup may behave in way our build
process does not expect.

## Step 3: Build Verus

You should be in the `source` subdirectory.

First, ensure that the necessary Rust toolchain is installed. Run the following command:

```sh
rustup toolchain install
```

### Build with Cargo

The recommended way to build Verus is by using the Cargo-based tooling.

The following assumes that the `cargo-make` tool was installed via `cargo install cargo-make`.

Run the `build` task:

```sh
cargo make build
```

For more detail on the exact commands each `cargo-make` task runs, refer to their definitions in
`source/Makefile.toml`.

### Build with Vargo

**WARNING**: Vargo is being deprecated. Please use the Cargo-based tooling described in the section above.

First, activate the development environment with one of the following: (This is automatic for [direnv](https://direnv.net/) users[^1])

```sh
source ../tools/activate       # for bash and zsh
source ../tools/activate.fish  # for fish
..\tools\activate.bat          # for Windows
..\tools\activate.ps1          # for Windows (Power Shell)
```

This command builds (or re-builds) `vargo`, our cargo wrapper, and adds it to the `PATH` for the current shell.

Now, simply run,

```
vargo build --release
```

(Omit `--release` for a debug build.)

This will build everything you need to use Verus:

- The `rust_verify` binary, which verifies Verus code.
- Additional libraries that Verus code will need to include (`builtin`, `builtin_macros`, and `state_machines_macros`).
- The [Verus standard library, `vstd`](https://verus-lang.github.io/verus/verusdoc/vstd/), which is written in Verus. Our build system builds **and verifies** the `vstd` crate.

If everything is successful, you should see output indicating that various modules in `vstd` are being verified.

# Running the Verifier

## Ubuntu 22.04 container (x86-64)

Build from the repository root with Docker:

```sh
docker build -f tools/ubuntu-22.04/Dockerfile -t verus:ubuntu22.04 .
docker run --rm verus:ubuntu22.04
docker run --rm verus:ubuntu22.04 bash /opt/test-verus.sh
```

This compiles the checked-out Verus source and its libraries on Ubuntu 22.04,
using the Rust version in `rust-toolchain.toml`. The default container command
verifies the sample library crate in `tools/ubuntu-22.04/sample/src/lib.rs`.
The test script also compiles that crate and checks that a deliberately invalid
postcondition is rejected. No host Rust installation is needed.

To check the sample as a Cargo project (also verifying `vstd`, and downloading
Cargo dependencies on the first run):

```sh
docker run --rm verus:ubuntu22.04 cargo verus verify -- -V no-solver-version-check
```

The `build` stage contains **no Z3**. It builds `vstd` with `--no-verify`, so
compilation does not depend on a solver version. This compiles and exports
`vstd` but does **not** reverify its proofs. To build only these solver-independent
artifacts, add `--target build` to the Docker build command.

The separate `runtime` stage installs Z3 4.12.5's `x64-glibc-2.35` binary,
which runs on Ubuntu 22.04, instead of the newer binary downloaded by
`source/tools/get-z3.sh`. Verification uses `-V no-solver-version-check`;
this disables only the version check, not verification. Other solver releases
can be selected with `--build-arg Z3_VERSION=... --build-arg Z3_PLATFORM=...`,
without rebuilding Verus. The release must provide the corresponding GitHub
ZIP asset and be compatible with the container; bypassing the version check
does not guarantee arbitrary solver versions are compatible.

The image includes `verus`, `cargo-verus`, the required Rust toolchain, and the
source tree. To verify a different standalone library crate:

```sh
docker run --rm -v "$PWD/my-crate:/work:ro" verus:ubuntu22.04 \
    verus --crate-type=lib /work/src/lib.rs -V no-solver-version-check
```

To extract the built binaries and libraries (the destination must be empty):

```sh
mkdir -p source/target-verus/ubuntu22.04
docker run --rm verus:ubuntu22.04 tar -C /opt/verus-bin -cf - . \
    | tar -C source/target-verus/ubuntu22.04 -xf -
```

When running extracted binaries outside the image, also install the pinned
Rust toolchain, provide a compatible Z3 through `VERUS_Z3_PATH`, and pass
`-V no-solver-version-check`. Set `--build-arg BUILD_JOBS=2` when building on
machines with less memory (the default is four concurrent Cargo jobs).

## Command-line usage

After running the build steps above, you can verify an example file.
From the `source` directory, run:

```sh
cargo run --release -p rust_verify -- ../examples/vectors.rs
```

You can also run the verifier directly with:

on Linux and macOS:

```sh
./target-verus/release/verus ../examples/vectors.rs
```

on Windows:

```
.\target-verus\release\verus.exe ..\examples\vectors.rs
```

You should see something like the following, indicating that verification was a success:

```
verification results:: verified: 7 errors: 0
```

You can also add the `--compile` flag, which tells Verus to compile the Verus code into a binary via `rustc`. For example:

on Linux and macOS:

```sh
./target-verus/release/verus ../examples/doubly_linked_xor.rs --compile
./doubly_linked_xor
```

on Windows:

```
.\target-verus\release\verus.exe ..\examples\doubly_linked_xor.rs --compile
.\doubly_linked_xor.exe
```

To verify an entire crate, simply point Verus at your `src/main.rs` file for an executable project, or `src/lib.rs` for a library project. You'll need to add `--crate-type=lib` for the latter.

Now you're ready to write some Verus! Check out [our guide](https://verus-lang.github.io/verus/guide/getting_started.html) if you haven't yet.

Note that while `cargo` needs to be run from the `source` directory, the `verus` binary can be run (directly, or via a symlink) from any directory, which is useful when verifying and compiling a project elsewhere on your file-system.

# IDE Support

Once you have built Verus, you can use it in IDE clients (such as Visual Studio
Code, Emacs, or Vim) that support the LSP protocol. Follow [these instructions](https://verus-lang.github.io/verus/guide/ide_support.html).

[^1]: If you are a [direnv](https://direnv.net/) user this activation is performed automatically, i.e. you don't need to `source ../tools/activate`; instead, `vargo` will automatically be in your `PATH` as long as you are in the `source` subdirectory.
