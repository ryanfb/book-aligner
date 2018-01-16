all: alignment-unique.csv alignment-filtered.csv alignment-filtered-joined-titles.csv alignment-filtered-joined-ids.csv ia-google-index.csv

alignment-filtered.csv: alignment.csv
	grep -v ',[123]$$' $^ > $@

alignment-unique.csv: alignment.csv
	sort $^ | uniq > $@

alignment.csv: ia-oclc-lccn-issn-isbn-vol-pub-title.csv hathifile.tsv book-aligner.rb
	bundle exec ./book-aligner.rb ia-oclc-lccn-issn-isbn-vol-pub-title.csv hathifile.tsv > $@

titles-alignment.csv: ia-oclc-lccn-issn-isbn-vol-pub-title.csv hathifile.tsv book-aligner-titles.rb
	./book-aligner-titles.rb ia-oclc-lccn-issn-isbn-vol-pub-title.csv hathifile.tsv > $@

hathifile.tsv:
	./hathifile-dl.rb > $@

ia-oclc-lccn-issn-isbn.csv:
	curl -o $@ 'https://archive.org/advancedsearch.php?q=mediatype%3Atexts&fl%5B%5D=identifier&fl%5B%5D=oclc-id&fl%5B%5D=lccn&fl%5B%5D=issn&fl%5B%5D=isbn&sort%5B%5D=&sort%5B%5D=&sort%5B%5D=&rows=9999999&page=1&output=csv&save=yes'

ia-oclc-lccn-issn-isbn-vol.csv:
	curl -o $@ 'https://archive.org/advancedsearch.php?q=mediatype%3Atexts&fl%5B%5D=identifier&fl%5B%5D=oclc-id&fl%5B%5D=lccn&fl%5B%5D=issn&fl%5B%5D=isbn&fl%5B%5D=volume&sort%5B%5D=&rows=9999999&page=1&output=csv&save=yes'

ia-oclc-lccn-issn-isbn-vol-pub.csv:
	curl -o $@ 'https://archive.org/advancedsearch.php?q=mediatype%3Atexts&fl%5B%5D=identifier&fl%5B%5D=oclc-id&fl%5B%5D=lccn&fl%5B%5D=issn&fl%5B%5D=isbn&fl%5B%5D=volume&fl%5B%5D=date&fl%5B%5D=year&sort%5B%5D=&rows=9999999&page=1&output=csv&save=yes'

alignment-filtered-joined-titles.csv alignment-filtered-joined-ids.csv: alignment-filtered.csv titles-alignment.csv merge-results.rb
	./merge-results.rb alignment-filtered.csv titles-alignment.csv alignment-filtered-joined-titles.csv alignment-filtered-joined-ids.csv

ia-goog.csv:
	curl -o $@ 'https://archive.org/advancedsearch.php?q=mediatype%3Atexts%20AND%20%28google-id:%5B%2A%20TO%20%2A%5D%20OR%20source:%5B%2A%20TO%20%2A%5D%29&fl%5B%5D=identifier&fl%5B%5D=google-id&fl%5B%5D=source&sort%5B%5D=&rows=9999999&page=1&output=csv&save=yes'

ia-google-index.csv: ia-goog.csv
	grep books.google $^ | cut -d, -f1,1 -f3,3 | gsed -r -e 's/https?\:\/\/books\.google\..+\/books\?id=//' -e 's/&.*"/"/' | grep -v -e '""' -e '"http:' > $@

ia-title.csv:
	curl -o $@ 'https://archive.org/advancedsearch.php?q=mediatype%3Atexts&fl%5B%5D=identifier&fl%5B%5D=title&fl%5B%5D=source&sort%5B%5D=&rows=9999999&page=1&output=csv&save=yes'

ia-lang.csv:
	curl -o $@ 'https://archive.org/advancedsearch.php?q=mediatype%3Atexts&fl%5B%5D=identifier&fl%5B%5D=language&sort%5B%5D=&rows=9999999&page=1&output=csv&save=yes'

ia-oclc-lccn-issn-isbn-vol-pub-goog.csv: ia-oclc-lccn-issn-isbn-vol-pub.csv ia-goog.csv
	csvjoin -c "identifier" $^ > $@

ia-oclc-lccn-issn-isbn-vol-pub-title.csv:
	curl -o $@ 'https://archive.org/advancedsearch.php?q=mediatype%3Atexts%20AND%20%28oclc-id:%5B%2A%20TO%20%2A%5D%20OR%20lccn:%5B%2A%20TO%20%2A%5D%20OR%20issn:%5B%2A%20TO%20%2A%5D%20OR%20isbn:%5B%2A%20TO%20%2A%5D%20OR%20title:%5B%2A%20TO%20%2A%5D%29&fl%5B%5D=identifier&fl%5B%5D=oclc-id&fl%5B%5D=lccn&fl%5B%5D=issn&fl%5B%5D=isbn&fl%5B%5D=volume&fl%5B%5D=date&fl%5B%5D=year&fl%5B%5D=title&sort%5B%5D=&rows=99999999&page=1&output=csv&save=yes'

clean:
	rm -fv alignment.csv alignment-unique.csv hathifile.tsv ia-oclc-lccn-issn-isbn-vol-pub-title.csv ia-goog.csv ia-google-index.csv alignment-filtered-joined-titles.csv alignment-filtered-joined-ids.csv alignment-filtered.csv titles-alignment.csv
