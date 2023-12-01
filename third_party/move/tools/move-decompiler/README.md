Demove decompiler
---

To build the decompiler, from the root directory of aptos-core, execute
the following command.

```
cargo build -p move-decompiler
```

Then to decompile a Move bytecode file, pass the file path as a command line
argument using `--bytecode` (or `-b`), as shown below.

```
decompiler --bytecode <file_path>
```

Please note that `<file_path>` should be replaced with the actual path to
the bytecode file you want to decompile.

For example:

```
cargo run -p move-decompiler -- -b third_party/move/tools/move-decompiler/tests/bytecode/BasicCoin.mv
```
