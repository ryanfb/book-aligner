#!/usr/bin/env ruby

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require 'csv'

filtered_csv, titles_csv, output_titles_csv, output_ids_csv = ARGV

output_titles = File.open(output_titles_csv, 'w')
output_ids = File.open(output_ids_csv, 'w')

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
  if filtered_matches[row[0]][row[1]] == 0
    output_titles.write [row[0], row[1], row[2]].join(',') + "\n"
  else
    output_ids.write [row[0], row[1], filtered_matches[row[0]][row[1]].to_i + row[2].to_i].join(',') + "\n"
  end
  filtered_matches[row[0]].delete(row[1])
end

$stderr.puts "Outputting remaining ID matches..."
filtered_matches.each_key do |ht|
  unless filtered_matches[ht].nil?
    filtered_matches[ht].each_key do |ia|
      unless filtered_matches[ht][ia].nil?
        output_ids.write [ht, ia, filtered_matches[ht][ia]].join(',') + "\n"
      end
    end
  end
end

output_titles.close
output_ids.close
