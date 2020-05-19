# Membrane Opus plugin

This package provides tools for decoding/encoding audio with Opus codec.

It is a part of [Membrane Multimedia Framework](https://membraneframework.org).

The docs can be found at [HexDocs](https://hexdocs.pm/membrane_element_fdk_aac).

## Installation

The package can be installed by adding `membrane_opus_plugin` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:membrane_opus_plugin, "~> 0.1.0"}
  ]
end
```

This package depends on [libopus](http://opus-codec.org/docs/) library.

### Ubuntu
```
sudo apt-get install libopus-dev
```

### Arch/Manjaro
```
pacman -S opus
```

### MacOS
```
brew install opus
```

## Usage example

TODO

## Copyright and License

Copyright 2019, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane_opus_plugin)

[![Software Mansion](https://membraneframework.github.io/static/logo/swm_logo_readme.png)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane_opus_plugin)

Licensed under the [Apache License, Version 2.0](LICENSE)
