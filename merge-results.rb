#!/usr/bin/env ruby

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require 'csv'

filtered_csv, titles_csv = ARGV

filtered_matches = {}

$stderr.puts "Parsing filtered CSV..."
CSV.foreach(filtered_csv, :headers => false) do |row|
  filtered_matches[row[0]] ||= {}
  filtered_matches[row[0]][row[1]] = row[2]
end

$stderr.puts "Parsing titles CSV..."
CSV.foreach(titles_csv, :headers => false) do |row|
  filtered_matches[row[0]] ||= {}
  filtered_matches[row[0]][row[1]] ||= 0
  filtered_matches[row[0]][row[1]] = filtered_matches[row[0]][row[1]].to_i + row[2].to_i
end

$stderr.puts "Outputting results..."
filtered_matches.each_key do |ht|
  filtered_matches[ht].each_key do |ia|
    puts [ht, ia, filtered_matches[ht][ia]].join(',')
  end
end
