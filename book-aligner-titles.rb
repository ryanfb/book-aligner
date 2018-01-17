#!/usr/bin/env ruby

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require 'csv'

internet_archive_csv, hathifile_tsv = ARGV

identifiers = {}
ia_volumes = {}
ia_date = {}
ia_year = {}
ia_titles = {}
ht_year = {}
hathi_volumes = {}
ht_ia_match_scores = {}

def normalize_title(title)
  # strip accents
  title = title.unicode_normalize(:nfd).gsub(/\p{M}/,'')
  # strip punctuation
  title.gsub! /\p{P}/u, ''
  # convert multiple spaces to single space
  title.gsub! /\ +/, ' '
  title.strip!

  title.downcase
end

def check_published(ht_pub, ia_pub)
  return ht_pub == ia_pub
end

def check_volumes(ht_vol, ia_vol)
  if ht_vol == ia_vol
    return true
  end

  ht_vol_number_match = /(\d+)/.match(ht_vol)
  ia_vol_number_match = /(\d+)/.match(ia_vol)

  # if we don't get a number from both vol strings, just say it's a match
  if ht_vol_number_match.nil? || ht_vol_number_match.captures.empty? || ia_vol_number_match.nil? || ia_vol_number_match.captures.empty?
    return true
  else
    # if we get numbers from both vol strings, only say it's a match if they're the same
    ht_vol_number = ht_vol_number_match.captures.first
    ia_vol_number = ia_vol_number_match.captures.first
    if ht_vol_number == ia_vol_number
      return true
    end
  end

  return false
end

$stderr.puts "Parsing Internet Archive metadata..."
CSV.foreach(internet_archive_csv, :headers => true) do |row|
  unless row['title'].nil? || row['title'].empty? || normalize_title(row['title']).empty?
    ia_titles[normalize_title(row['title'])] ||= []
    ia_titles[normalize_title(row['title'])] << row['identifier']
  end
  if !row['year'].nil? && !row['year'].empty?
    ia_year[row['identifier']] = row['year']
  end
  if !row['date'].nil? && !row['date'].empty?
    date_match = /^(\d+)/.match(row['date'])
    if date_match
      ia_date[row['identifier']] = date_match.captures.first
    end
  end
  ia_volumes[row['identifier']] = row['volume']
end

$stderr.puts "Parsing HathiTrust metadata..."
CSV.foreach(hathifile_tsv, :headers => false, :col_sep => "\t", :quote_char => "\u{FFFF}") do |row|
  ht_year[row[0]] = row[16]
  hathi_volumes[row[0]] = row[4]

  unless row[11].nil? || row[11].empty? || normalize_title(row[11]).empty?
    if ia_titles.has_key?(normalize_title(row[11]))
      ia_titles[normalize_title(row[11])].each do |ia|
        ht = row[0]
        if (!ht_year[ht].nil? && !ht_year[ht].empty?) && ((!ia_year[ia].nil? && !ia_year[ia].empty?) || (!ia_date[ia].nil? && !ia_date[ia].empty?))
          if (!ia_year[ia].nil? && !ia_year[ia].empty? && check_published(ht_year[ht],ia_year[ia]))
            if check_volumes(hathi_volumes[ht], ia_volumes[ia])
              puts [ht, ia, 10].join(',')
            else
              # puts [ht, ia, 8].join(',')
            end
          elsif check_published(ht_year[ht],ia_date[ia])
            if check_volumes(hathi_volumes[ht], ia_volumes[ia])
              puts [ht, ia, 6].join(',')
            else
              # puts [ht, ia, 4].join(',')
            end
          end
        end
      end
    end
  end
end
