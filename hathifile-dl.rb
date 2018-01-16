#!/usr/bin/env ruby

require 'json'
require 'time'
require 'uri'
require 'net/http'
require 'pp'

def download(hathifile)
  unless File.exist?(hathifile['filename'])
    $stderr.puts "Downloading: #{hathifile['filename']}"
    `wget -c "#{hathifile['url']}"`
  end
end

hathifiles = JSON.parse(Net::HTTP.get(URI('https://www.hathitrust.org/sites/www.hathitrust.org/files/hathifiles/hathi_file_list.json')))

latest_full_hathifile = hathifiles.select{|h| h['full']}.sort_by{|h| Time.parse(h['created'])}.last
$stderr.puts latest_full_hathifile.inspect

downloads = [latest_full_hathifile]

hathifiles.select{|h| !h['full']}.each do |hathifile|
  if Time.parse(hathifile['created']) > Time.parse(latest_full_hathifile['created'])
    $stderr.puts hathifile['created']
    downloads << hathifile
  end
end

downloads.sort_by!{|h| Time.parse(h['created'])}

downloads.each{|h| download(h)}

downloads.each do |hathifile|
  Zlib::GzipReader.open(hathifile['filename']) do |gz|
    gz.each_line do |line|
      puts line
    end
  end
end
