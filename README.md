# zIGA
InnocentGrey IGA format extractor in Zig language.

Tested on files from Flowers Series, Kara no Shoujou (殼/虛/天)


## Build
```sh
$ zig build-exe main.zig
```

## Usage
```sh
$ ./main [path_to_iga_file] [folder_to_place_extracted_files] ["xor"]
```

"xor": use XOR decryption on extracted files

Examples:
```sh
$ ./main bgm.iga ./bgm
$ ./main script.iga ./script xor
```
