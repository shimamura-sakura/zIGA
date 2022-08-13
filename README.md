# zIGA
InnocentGrey IGA format extractor in Zig language.

Tested on files from "Flowers - Le volume sur printemps"

## Build
```sh
$ zig build-exe main.zig
```

## Usage
```sh
$ ./main [path_to_iga_file] [folder_to_place_extracted_files] ["xor"]
```
Examples:
```sh
$ ./main bgm.iga ./bgm
$ ./main script.iga ./script xor
```
