# VSS-Extra

[![Build](https://github.com/AdaCore/vss-extra/actions/workflows/main.yml/badge.svg)](https://github.com/AdaCore/vss-extra/actions/workflows/main.yml)
[![alire](https://img.shields.io/endpoint?url=https://alire.ada.dev/badges/vss_extra.json)](https://alire.ada.dev/crates/vss_extra.html)

A high level string and text processing library.

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

## The objectives

The objectives of this project are

* To introduce a definite type that represents a string of Unicode characters
  and provides a handy set of operations.
* The API should be encoding independent and allows efficient implementations
  depending on platform/application and avoid extra encoding conversions, e.g.
  an UTF-8 internal representation for Gtk+ applications, UCS-2 for native
  Windows applications and UTF-16 for WebAssembly.
* Besides separating string API from in-memory data representation, it should
  separate string API from input/output stream representation.
* To provide a clear, well-defined semantic for iteration over string
  elements, such as unicode unit, grapheme cluster, etc.
* To avoid string element integer indexes, because this isn't necessarily
  constant time and could mislead about indexed element kind.
* To prefer safe results over raising exceptions where possible.

Warning: This is experimental work in progress, everything is subject to
change. It may be or may be not part of GNATCOLL or standard Ada library
in the future.

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
* [Tips & Tricks](docs/Tips_and_Tricks.md)

## Maintainers

[@AdaCore](https://adacore.com/).

## Contribute

Feel free to dive in!
[Open an issue](https://github.com/AdaCore/vss-extra/issues/new)
or submit PRs.

## License

[Apache License v2.0 with LLVM Exceptions](LICENSE.txt).
