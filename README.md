# book-aligner

This repository is for experimental scripts to align books between HathiTrust, Internet Archive, Google Books, etc.

Ultimately, I want to be able to mash in a HT/IA/GB/etc. URL or other identifier and get a list of potential matches elsewhere on the web.

## Requirements

* `make`
* `curl`
* Ruby

## Usage

The default `make` target should download and run everything.

**WARNING**: this currently produces about 4.3GB of output.
