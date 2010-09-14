#!/usr/bin/ruby
#####################
#
#  Local Archiving script for qinteract archiver (NOT USED)
#  Dave Austin @ ITMAT UPENN
#
#  Finds space on volumes, zips local archive directory, 
#  Updates README with md5, disk location, etc
#  Sends README to iarchive app
#
#######

SERVERNAME = 'arcuser@backup.itmat.upenn.edu'
MD5CMD = 'md5 -q' # needs to output only md5 hash, or a wsv with the hash as the first value 
VOLUMES = [ "/Volumes/3440_Archive_001",
	    "/Volumes/3440_Archive_002",
	    "/Volumes/3440_Archive_003",
	    "/Volumes/3440_Archive_004" ]


# tar & zip directory
puts "Zipping and compressing project..."
unless File.exist? ARGV[0]
  
  puts "Could not find folder #{ARGV[0]} exiting"
  exit 1
  
end

system "thor archive:compress #{ARGV[0]}"

folder_name = ARGV[0]

zip_size = 0

Dir.glob("*.7z.*") do |z|

  zip_size += File.size(z)

end
	    
# first find volume that is big enough

current_vol = ''

VOLUMES.each do |v|

  if File.exist? v
    df_out = `df -k #{v}`
    cur_size = df_out.split("\n")[1].split(' ')[3]
    if (zip_size.to_i / 1024) < cur_size.to_i
       current_vol = v
       break
    end
  end

end

if current_vol == ''
   puts "ERROR: NO SPACE LEFT ON VOLUMES!"
   exit 1

end

puts "Using #{current_vol}"

`mkdir #{current_vol}/#{folder_name}`

`cp -v #{folder_name}.7z.* #{current_vol}/#{folder_name}`

# extract readme, alter and resave within
Dir.chdir "#{current_vol}/#{folder_name}" do
  puts "Updating README MD5"
  md5sums = File.open('md5sums.txt', 'w+')
  Dir.glob("#{folder_name}.7z.*") do |fn|
    single_md5 = `#{MD5CMD} #{fn}`
    single_md5 = single_md5.split(' ')[0]
    md5sums.write("#{fn}=#{single_md5}\n")
    system "which 7za " 
    system "thor client:update_readme_md5 #{folder_name}.7z.001 #{fn} #{single_md5}"
  end
  md5sums.close

  # now this is where we extract the readme, alter it, and then save it to iarchive

  puts "Updating disk id"
  system "thor client:update_readme #{folder_name}.7z.001 archive_disk_id #{File.basename(current_vol)}"

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

puts "FILE ARCHIVED!"

