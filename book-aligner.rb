#!/usr/bin/env ruby

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require 'csv'

internet_archive, internet_archive_volumes_csv, hathifile = ARGV

identifiers = {}
ia_volumes = {}

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

def check_identifiers(identifiers, ia_volumes, volume_identifier, hathi_volume, hathi_identifiers, identifier_key)
  if !hathi_identifiers.nil? && !hathi_identifiers.empty?
    hathi_identifiers.split(',').each do |hathi_identifier|
      if identifiers[identifier_key].has_key?(hathi_identifier)
        identifiers[identifier_key][hathi_identifier].each do |ia_identifier|
          if !hathi_volume.nil? && !hathi_volume.empty? && !ia_volumes[ia_identifier].nil? && !ia_volumes[ia_identifier].empty?
            if check_volumes(hathi_volume, ia_volumes[ia_identifier])
              puts [volume_identifier, hathi_volume, ia_identifier, ia_volumes[ia_identifier]].join(',')
            end
          else
            puts [volume_identifier, hathi_volume, ia_identifier, ia_volumes[ia_identifier]].join(',')
          end
        end
      end
    end
  end
end

$stderr.puts "Parsing Internet Archive metadata..."
CSV.foreach(internet_archive, :headers => true) do |row|
  %w{oclc-id lccn issn isbn}.each do |identifier_type|
    if !row[identifier_type].nil? && !row[identifier_type].empty?
      identifiers[identifier_type] ||= {}
      identifiers[identifier_type][row[identifier_type]] ||= []
      identifiers[identifier_type][row[identifier_type]] << row['identifier']
    end
  end
end

$stderr.puts "Parsing Internet Archive volume metadata..."
CSV.foreach(internet_archive_volumes_csv, :headers => true) do |row|
  ia_volumes[row['identifier']] = row['volume']
end

$stderr.puts "Parsing HathiTrust metadata..."
CSV.foreach(hathifile, :headers => false, :col_sep => "\t", :quote_char => "\u{FFFF}") do |row|
  check_identifiers(identifiers, ia_volumes, row[0], row[4], row[7], 'oclc-id')
  check_identifiers(identifiers, ia_volumes, row[0], row[4], row[8], 'isbn')
  check_identifiers(identifiers, ia_volumes, row[0], row[4], row[9], 'issn')
  check_identifiers(identifiers, ia_volumes, row[0], row[4], row[10], 'lccn')
end
