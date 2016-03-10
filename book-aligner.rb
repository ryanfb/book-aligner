#!/usr/bin/env ruby

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require 'csv'
require 'time'

internet_archive, hathifile = ARGV

identifiers = {}
ia_volumes = {}
ia_date = {}
ia_year = {}
ht_year = {}
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

def check_identifiers(ht_ia_match_scores, identifiers, ia_volumes, ia_published, volume_identifier, hathi_volume, hathi_published, hathi_identifiers, identifier_key)
  if !hathi_identifiers.nil? && !hathi_identifiers.empty?
    hathi_identifiers.split(',').each do |hathi_identifier|
      if identifiers[identifier_key].has_key?(hathi_identifier)
        identifiers[identifier_key][hathi_identifier].each do |ia_identifier|
          # if !hathi_volume.nil? && !hathi_volume.empty? && !ia_volumes[ia_identifier].nil? && !ia_volumes[ia_identifier].empty?
          #  if check_volumes(hathi_volume, ia_volumes[ia_identifier])
          #    puts [volume_identifier, hathi_volume, ia_identifier, ia_volumes[ia_identifier]].join(',')
          #  end
          # $stderr.puts [volume_identifier, hathi_published, ia_identifier, ia_published[ia_identifier]].join(' ')
          # if !hathi_published.nil? && !hathi_published.empty? && !ia_published[ia_identifier].nil? && !ia_published[ia_identifier].empty?
          #  if check_published(hathi_published, ia_published[ia_identifier])
          #    puts [volume_identifier, ia_identifier].join(',')
          #  end
          # else
          #  puts [volume_identifier, ia_identifier].join(',')
          # end
          ht_ia_match_scores[volume_identifier] ||= {}
          ht_ia_match_scores[volume_identifier][ia_identifier] ||= 0
          ht_ia_match_scores[volume_identifier][ia_identifier] += 1
        end
      end
    end
  end
end

$stderr.puts "Parsing Internet Archive metadata..."
CSV.foreach(internet_archive, :headers => true) do |row|
  ia_volumes[row['identifier']] = row['volume']
  if !row['year'].nil? && !row['year'].empty?
    ia_year[row['identifier']] = row['year']
  end
  if !row['date'].nil? && !row['date'].empty?
    begin
      # ia_date[row['identifier']] = Time.parse(row['date']).year.to_s
      # Just take the first digit string as year, since IA date metdata is…problematic
      ia_date[row['identifier']] = /^(\d+)/.match(row['date']).captures.first
    rescue Exception => e
      $stderr.puts(e.message + "\nSkipping #{row['date']} for #{row['identifier']}")
    end
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
CSV.foreach(hathifile, :headers => false, :col_sep => "\t", :quote_char => "\u{FFFF}") do |row|
  ht_year[row[0]] = row[16]
  check_identifiers(ht_ia_match_scores, identifiers, ia_volumes, nil, row[0], row[4], row[16], row[7], 'oclc-id')
  check_identifiers(ht_ia_match_scores, identifiers, ia_volumes, nil, row[0], row[4], row[16], row[8], 'isbn')
  check_identifiers(ht_ia_match_scores, identifiers, ia_volumes, nil, row[0], row[4], row[16], row[9], 'issn')
  check_identifiers(ht_ia_match_scores, identifiers, ia_volumes, nil, row[0], row[4], row[16], row[10], 'lccn')
end

$stderr.puts "Outputting match scores..."
ht_ia_match_scores.each_key do |ht|
  ht_ia_match_scores[ht].each_key do |ia|
    if (!ht_year[ht].nil? && !ht_year[ht].empty?) && ((!ia_year[ia].nil? && !ia_year[ia].empty?) || (!ia_date[ia].nil? && !ia_date[ia].empty?))
      if (!ia_year[ia].nil? && !ia_year[ia].empty? && check_published(ht_year[ht],ia_year[ia]))
        puts [ht, ia, ht_ia_match_scores[ht][ia] + 8].join(',')
      elsif check_published(ht_year[ht],ia_date[ia])
        puts [ht, ia, ht_ia_match_scores[ht][ia] + 4].join(',')
      end
    else
      puts [ht, ia, ht_ia_match_scores[ht][ia]].join(',')
    end
  end
end
