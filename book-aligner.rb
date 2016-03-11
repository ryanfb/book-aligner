#!/usr/bin/env ruby

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require 'csv'

internet_archive_csv, hathifile_tsv = ARGV

identifiers = {}
ia_volumes = {}
ia_date = {}
ia_year = {}
ht_year = {}
hathi_volumes = {}
ht_ia_match_scores = {}

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

def check_published(ht_pub, ia_pub)
  return ht_pub == ia_pub
end

def check_standard_identifiers(ht_ia_match_scores, standard_identifiers, ht_identifier, identifier_string, standard_identifier_key)
  if !identifier_string.nil? && !identifier_string.empty?
    identifier_string.split(',').each do |identifier_to_check|
      if standard_identifiers[standard_identifier_key].has_key?(identifier_to_check)
        standard_identifiers[standard_identifier_key][identifier_to_check].each do |ia_identifier|
          ht_ia_match_scores[ht_identifier] ||= {}
          ht_ia_match_scores[ht_identifier][ia_identifier] ||= 0
          ht_ia_match_scores[ht_identifier][ia_identifier] += 1
        end
      end
    end
  end
end

$stderr.puts "Parsing Internet Archive metadata..."
CSV.foreach(internet_archive_csv, :headers => true) do |row|
  ia_volumes[row['identifier']] = row['volume']
  if !row['year'].nil? && !row['year'].empty?
    ia_year[row['identifier']] = row['year']
  end
  if !row['date'].nil? && !row['date'].empty?
    ia_date[row['identifier']] = /^(\d+)/.match(row['date']).captures.first
  end
  %w{oclc-id lccn issn isbn}.each do |identifier_type|
    if !row[identifier_type].nil? && !row[identifier_type].empty?
      identifiers[identifier_type] ||= {}
      identifiers[identifier_type][row[identifier_type]] ||= []
      identifiers[identifier_type][row[identifier_type]] << row['identifier']
    end
  end
end

$stderr.puts "Parsing HathiTrust metadata..."
CSV.foreach(hathifile_tsv, :headers => false, :col_sep => "\t", :quote_char => "\u{FFFF}") do |row|
  ht_year[row[0]] = row[16]
  hathi_volumes[row[0]] = row[4]
  check_identifiers(ht_ia_match_scores, identifiers, row[0], row[7], 'oclc-id')
  check_identifiers(ht_ia_match_scores, identifiers, row[0], row[8], 'isbn')
  check_identifiers(ht_ia_match_scores, identifiers, row[0], row[9], 'issn')
  check_identifiers(ht_ia_match_scores, identifiers, row[0], row[10], 'lccn')
end

$stderr.puts "Outputting match scores..."
ht_ia_match_scores.each_key do |ht|
  ht_ia_match_scores[ht].each_key do |ia|
    if (!ht_year[ht].nil? && !ht_year[ht].empty?) && ((!ia_year[ia].nil? && !ia_year[ia].empty?) || (!ia_date[ia].nil? && !ia_date[ia].empty?))
      if (!ia_year[ia].nil? && !ia_year[ia].empty? && check_published(ht_year[ht],ia_year[ia]))
        ht_ia_match_scores[ht][ia] += 16
      elsif check_published(ht_year[ht],ia_date[ia])
        ht_ia_match_scores[ht][ia] += 8
      end
    end
    if !hathi_volumes[ht].nil? && !hathi_volumes[ht].empty? && !ia_volumes[ia].nil? && !ia_volumes[ia].empty?
      if check_volumes(hathi_volumes[ht], ia_volumes[ia])
        ht_ia_match_scores[ht][ia] += 4
      end
    end

    puts [ht, ia, ht_ia_match_scores[ht][ia]].join(',')
  end
end
