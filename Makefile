all: alignment-unique.csv alignment-filtered.csv

alignment-filtered.csv: alignment.csv
	grep -v ',[123]$$' $^ > $@

alignment-unique.csv: alignment.csv
	sort $^ | uniq > $@

alignment.csv: ia-oclc-lccn-issn-isbn-vol-pub.csv hathifile.tsv book-aligner.rb
	./book-aligner.rb ia-oclc-lccn-issn-isbn-vol-pub.csv hathifile.tsv > $@

hathifile.tsv:
	curl 'https://www.hathitrust.org/filebrowser/download/142568' | gunzip -c > $@

ia-oclc-lccn-issn-isbn.csv:
	curl -o $@ 'https://archive.org/advancedsearch.php?q=mediatype%3Atexts&fl%5B%5D=identifier&fl%5B%5D=oclc-id&fl%5B%5D=lccn&fl%5B%5D=issn&fl%5B%5D=isbn&sort%5B%5D=&sort%5B%5D=&sort%5B%5D=&rows=9999999&page=1&output=csv&save=yes'

ia-oclc-lccn-issn-isbn-vol.csv:
	curl -o $@ 'https://archive.org/advancedsearch.php?q=mediatype%3Atexts&fl%5B%5D=identifier&fl%5B%5D=oclc-id&fl%5B%5D=lccn&fl%5B%5D=issn&fl%5B%5D=isbn&fl%5B%5D=volume&sort%5B%5D=&rows=9999999&page=1&output=csv&save=yes'

ia-oclc-lccn-issn-isbn-vol-pub.csv:
	curl -o $@ 'https://archive.org/advancedsearch.php?q=mediatype%3Atexts&fl%5B%5D=identifier&fl%5B%5D=oclc-id&fl%5B%5D=lccn&fl%5B%5D=issn&fl%5B%5D=isbn&fl%5B%5D=volume&fl%5B%5D=date&fl%5B%5D=year&sort%5B%5D=&rows=9999999&page=1&output=csv&save=yes'

ia-goog.csv:
	curl -o $@ 'https://archive.org/advancedsearch.php?q=mediatype%3Atexts&fl%5B%5D=identifier&fl%5B%5D=google-id&fl%5B%5D=source&sort%5B%5D=&rows=9999999&page=1&output=csv&save=yes'

ia-oclc-lccn-issn-isbn-vol-pub-goog.csv: ia-oclc-lccn-issn-isbn-vol-pub.csv ia-goog.csv
	csvjoin -c "identifier" $^ > $@

clean:
	rm -fv alignment.csv alignment-unique.csv
