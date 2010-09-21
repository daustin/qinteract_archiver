#!/usr/bin/ruby
#####################
#
#  README Updater
#  Dave Austin @ ITMAT UPENN
#
#  Updates disk id in read me, posts to iarchive. FOR UNZIPPED PROJECTS. 
#  Run from volume root!
#
#  Usage: ruby iarchive_readme_updater_unzip.rb <archive_folder_name>
#
#
#######

require 'rubygems'
require 'json'

MD5CMD = 'md5 -q' # needs to output only md5 hash, or a wsv with the hash as the first value 
PZIPCMD = '7za'

disk_id = File.basename(Dir.pwd)

unless File.exist? ARGV[0]
  
  puts "Could not find folder #{ARGV[0]} exiting"
  exit 1
  
end

folder_name = ARGV[0].strip.chomp('/')

puts "Updating archive #{folder_name}..."

# extract readme, alter and resave within
Dir.chdir "#{folder_name}" do

  # now this is where we extract the readme, alter it, and then save it to iarchive

  puts "Updating disk id"
      
  # import into memory
  
  json_hash = JSON.parse(File.read("README.json"))
  
  # add disk ID, save to ./ReADMEjson
  
  json_hash['archive_disk_id'] = disk_id
  
  fout = File.open("README.json", "w+")
  fout.write json_hash.to_json
  fout.close
    
  # post new README to iarchive
  new_id = 0
  
  puts "Uploading to iarchive..."
  cout = `curl -v -F "readme_file=@README.json" -u iarchive:iarchive http://bioinf.itmat.upenn.edu/iarchive/create 2>&1`
  cout.each_line do |el|
    new_id = $1 if el =~ /archive\/show\/(\d+)/
  end

  if new_id == 0
    puts "ERROR: Could not fetch new archive id from iarchive."
    exit  1
  end
  
  # add iarchive ID to existing JSON in memory
  puts "Updating iarchive id..."
  
  json_hash['iarchive_id'] = new_id

  fout = File.open("README.json", "w+")
  fout.write json_hash.to_json
  fout.close 

  puts "Uploading to iarchive..."
  `curl -v -F "readme_file=@README.json" -u iarchive:iarchive http://bioinf.itmat.upenn.edu/iarchive/update/#{new_id}`

end

puts "FILE UPDATED!"

