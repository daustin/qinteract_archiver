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

MD5CMD = 'md5 -q' # needs to output only md5 hash, or a wsv with the hash as the first value 
disk_id = File.basename(Dir.pwd)

unless File.exist? ARGV[0]
  
  puts "Could not find folder #{ARGV[0]} exiting"
  exit 1
  
end

folder_name = ARGV[0]

# extract readme, alter and resave within
Dir.chdir "#{folder_name}" do
  puts "Updating README MD5"  

  # now this is where we extract the readme, alter it, and then save it to iarchive

  puts "Updating disk id"
  system "thor client:update_readme #{folder_name}.7z.001 archive_disk_id #{disk_id}"

  puts "Uploading to iarchive..."
  cout = `curl -v -F "readme_file=@README.json" -u iarchive:iarchive http://bioinf.itmat.upenn.edu/iarchive/create 2>&1`
  new_id = 0
  cout.each_line do |el|
    if el =~ /archive\/show\/(\d+)/
      new_id = $1 
    end
  end

  if new_id == 0
    puts "ERROR: Could not fetch new archive id from iarchive."
  else
      system "thor client:update_readme #{folder_name}.7z.001 iarchive_id #{new_id}"
      `curl -v -F "readme_file=@README.json" -u iarchive:iarchive http://bioinf.itmat.upenn.edu/iarchive/update/#{new_id}`
  end

end

puts "FILE UPDATED!"

