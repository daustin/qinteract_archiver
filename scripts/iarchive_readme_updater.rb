#!/usr/bin/ruby
#####################
#
#  README Updater
#  Dave Austin @ ITMAT UPENN
#
#  Updates disk id in read me, posts to iarchive.
#
#  Usage: ruby iarchive_readme_updater.rb <archive_folder_name>
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
  
  # delete existing ./README.json
  
  system "rm -rf README.json"
  
  # fetch project_xxx/README.json from 7zip to cwd

  system "#{PZIPCMD} x -r #{folder_name}.7z.001 #{folder_name}/README.json"  
  
  # import into memory
  
  json_hash = JSON.parse(File.read("#{folder_name}/README.json"))
  
  # add disk ID, save to ./ReADMEjson
  
  json_hash['archive_disk_id'] = disk_id
  
  fout = File.open("#{folder_name}/README.json", "w+")
  fout.write json_hash.to_json
  fout.close
    
  # post new README to iarchive
  new_id = 0
  Dir.chdir(folder_name) do
    
    puts "Uploading to iarchive..."
    cout = `curl -v -F "readme_file=@README.json" -u iarchive:iarchive http://bioinf.itmat.upenn.edu/iarchive/create 2>&1`
    cout.each_line do |el|
      new_id = $1 if el =~ /archive\/show\/(\d+)/
    end

    exit "ERROR: Could not fetch new archive id from iarchive." if new_id == 0
    
  end
  
  # add iarchive ID to existing JSON in memory
  puts "Updating iarchive id..."
  
  json_hash['iarchive_id'] = new_id

  fout = File.open("#{folder_name}/README.json", "w+")
  fout.write json_hash.to_json
  fout.close 

  Dir.chdir(folder_name) do
    
    puts "Uploading to iarchive..."
    `curl -v -F "readme_file=@README.json" -u iarchive:iarchive http://bioinf.itmat.upenn.edu/iarchive/update/#{new_id}`
    
  end
  
  # puts "Updating README in 7zip..."
  
  # remove stale references to README.json
  
  # system "#{PZIPCMD} d -r -mmt=on #{folder_name}.7z README.json"
  
  # update README.json reference in 7z file
    
  # system "#{PZIPCMD} u -mx0 -mmt #{folder_name}.7z #{folder_name}/README.json"
  
  # cp readme to cwd and cleanup
  
  system "cp -v #{folder_name}/README.json ."
  system "rm -rf #{folder_name}/"

end

puts "FILE UPDATED!"

