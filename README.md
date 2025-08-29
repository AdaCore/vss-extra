# VSS-Extra

[![Build](https://github.com/AdaCore/vss-extra/actions/workflows/main.yml/badge.svg)](https://github.com/AdaCore/vss-extra/actions/workflows/main.yml)
[![alire](https://img.shields.io/endpoint?url=https://alire.ada.dev/badges/vss_extra.json)](https://alire.ada.dev/crates/vss_extra.html)

## Warning - Work in Progress

This project is based on [`VSS`](https://github.com/AdaCore/VSS) (Virtual
String System). VSS has been split into two projects:

* [`vss-text`](https://github.com/AdaCore/vss-text): a library for Unicode text
  processing.
* [`vss-extra`](https://github.com/AdaCore/vss-extra) (this project): libraries
  for handling JSON, Regexp, XML and other features based on `vss-text`.

Significant API changes are planned in `vss-text` which will likely have an
impact on this project.

Moreover, `vss-extra` is planned to be further split into more focused
projects (e.g. JSON, Regexp, XML, etc.) and might ultimately disappear once all
features find a new home.

Note: Some Ada 2022 features are used in source code. This requires compiler
that supports them.

## Install

### Build from sources

Prefered way to install is to download sources and run

    make all install PREFIX=/path/to/install

### Using `Alire`

Or you can use [Alire](https://alire.ada.dev/) library manager:

    alr get --build vss_extra

Then you can use it as dependency in the project file:

    with "vss_json.gpr";

## Documentation

* [API Reference](https://adacore.github.io/VSS/)

## Maintainers

[@AdaCore](https://adacore.com/).

## Contribute

Feel free to dive in!
[Open an issue](https://github.com/AdaCore/vss-extra/issues/new)
or submit PRs.

## License

[Apache License v2.0 with LLVM Exceptions](LICENSE.txt).
