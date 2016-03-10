#!/usr/bin/env ruby

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require 'csv'
require 'time'

internet_archive, hathifile = ARGV

identifiers = {}
ia_volumes = {}
ia_published = {}

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

def check_identifiers(identifiers, ia_volumes, ia_published, volume_identifier, hathi_volume, hathi_published, hathi_identifiers, identifier_key)
  if !hathi_identifiers.nil? && !hathi_identifiers.empty?
    hathi_identifiers.split(',').each do |hathi_identifier|
      if identifiers[identifier_key].has_key?(hathi_identifier)
        identifiers[identifier_key][hathi_identifier].each do |ia_identifier|
          # if !hathi_volume.nil? && !hathi_volume.empty? && !ia_volumes[ia_identifier].nil? && !ia_volumes[ia_identifier].empty?
          #  if check_volumes(hathi_volume, ia_volumes[ia_identifier])
          #    puts [volume_identifier, hathi_volume, ia_identifier, ia_volumes[ia_identifier]].join(',')
          #  end
          # $stderr.puts [volume_identifier, hathi_published, ia_identifier, ia_published[ia_identifier]].join(' ')
          if !hathi_published.nil? && !hathi_published.empty? && !ia_published[ia_identifier].nil? && !ia_published[ia_identifier].empty?
            if check_published(hathi_published, ia_published[ia_identifier])
              puts [volume_identifier, ia_identifier].join(',')
            end
          else
            puts [volume_identifier, ia_identifier].join(',')
          end
        end
      end
    end
  end
end

$stderr.puts "Parsing Internet Archive metadata..."
CSV.foreach(internet_archive, :headers => true) do |row|
  ia_volumes[row['identifier']] = row['volume']
  if !row['year'].nil? && !row['year'].empty?
    ia_published[row['identifier']] = row['year']
  elsif !row['date'].nil? && !row['date'].empty?
    begin
      # ia_published[row['identifier']] = Time.parse(row['date']).year.to_s
      # Just take the first digit string as year, since IA date metdata is…problematic
      ia_published[row['identifier']] = /^(\d+)/.match(row['date']).captures.first
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
  check_identifiers(identifiers, ia_volumes, ia_published, row[0], row[4], row[16], row[7], 'oclc-id')
  check_identifiers(identifiers, ia_volumes, ia_published, row[0], row[4], row[16], row[8], 'isbn')
  check_identifiers(identifiers, ia_volumes, ia_published, row[0], row[4], row[16], row[9], 'issn')
  check_identifiers(identifiers, ia_volumes, ia_published, row[0], row[4], row[16], row[10], 'lccn')
end
