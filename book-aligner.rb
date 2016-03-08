#!/usr/bin/env ruby

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require 'csv'

internet_archive, hathifile = ARGV

identifiers = {}

def check_identifiers(identifiers, volume_identifier, hathi_identifiers, identifier_key)
  if !hathi_identifiers.nil? && !hathi_identifiers.empty?
    hathi_identifiers.split(',').each do |hathi_identifier|
      if identifiers[identifier_key].has_key?(hathi_identifier)
        identifiers[identifier_key][hathi_identifier].each do |ia_identifier|
          puts [volume_identifier, ia_identifier].join(',')
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

$stderr.puts "Parsing HathiTrust metadata..."
CSV.foreach(hathifile, :headers => false, :col_sep => "\t", :quote_char => "\u{FFFF}") do |row|
  check_identifiers(identifiers, row[0], row[7], 'oclc-id')
  check_identifiers(identifiers, row[0], row[8], 'isbn')
  check_identifiers(identifiers, row[0], row[9], 'issn')
  check_identifiers(identifiers, row[0], row[10], 'lccn')
end
