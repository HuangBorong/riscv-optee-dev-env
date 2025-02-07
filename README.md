# Development environment for building and testing OP-TEE on RISC-V architecture

## Download
```
git clone git@github.com:HuangBorong/riscv-optee-dev-env.git
cd ./riscv-optee-dev-env
git submodule update --init --recursive --progress
```

## Build
```
make qemu
make dts
make opensbi
make optee_os
```

### Show help
```
make help
```

## Run
```
make run
```

## Debug
```
make debug

# Then open another terminal
gdb-multiarch --tui /path/to/riscv-optee-dev-env/build/optee_os/core/tee.elf
```
