# book-aligner

This repository is for experimental scripts to align books between HathiTrust, Internet Archive, Google Books, etc.

By "alignment", I mean that for a given volume in one repository, I want to try to find any matching volumes in the other repositories.

Ultimately, I want to be able to mash in a HT/IA/GB/etc. URL or other identifier and get a list of potential matches elsewhere on the web.

## Requirements

* `make`
* `curl`
* Ruby

## Usage

The default `make` target should download and run everything.

**WARNING**: this currently produces about 4.3GB of output.

## Algorithm

The `book-aligner.rb` script uses bulk metadata downloads from HathiTrust and the Internet Archive to find the complete set of identifiers that have any matching OCLC/LCCN/ISSN/ISBN identifier (~41M matches). These results are then filtered to those that have a matching volume number or publication year.

[![HT/IA/GB Relationship Diagram](http://i.imgur.com/KNr1BZzm.jpg)](http://imgur.com/KNr1BZz)

## Examples

Some examples of what I want for "matching volumes":

* Neue Jahrbücher für Philologie und Paedogogik, bd. 135. Note that the IA metadata does not record the volume number.
  * <https://archive.org/details/bub_gb_P5JJAAAAYAAJ>
  * <https://books.google.com/books?id=P5JJAAAAYAAJ>
  * <http://babel.hathitrust.org/cgi/pt?id=njp.32101076453875>
* Opvscvla academica collecta et animadversionibvs locvpletata, vol. 1. Note that if you search Google Books for the OCLC number `9772746` associated with this volume in IA/HT, it only returns [vol. 5](https://books.google.com/books?id=CVf-FBft1RIC).
  * <https://archive.org/details/opvscvlaacademi03heyngoog>
  * <https://books.google.com/books?id=n_VOqOVGGcYC>
  * <http://babel.hathitrust.org/cgi/pt?id=mdp.39015058525919>
