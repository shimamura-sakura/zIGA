# zIGA

InnocentGrey IGA format extractor in Zig language.

## Build
```sh
$ ./build.sh
or 
$ zig build-exe main.zig
```

## Usage
```sh
$ ./main [path_to_iga_file] [folder_to_place_extracted_files]
```

without output dir - list files

will automatically apply XOR to script files (.s)

Examples:
```sh
$ ./main bgm.iga # list files
$ ./main bgm.iga ./bgm
$ ./main script.iga ./script
```

## Note

might be difficult to port, because it uses MMAP_PRIVATE to avoid allocating memory