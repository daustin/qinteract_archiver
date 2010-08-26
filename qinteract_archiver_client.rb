#!/usr/bin/ruby
#####################
#
#  Client script for qinteract archiver
#  Dave Austin @ ITMAT UPENN
#
#  Finds space on volumes, downloads and checks archive file
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

remote_path = ARGV[0]
remote_md5 = ARGV[1]
remote_size = ARGV[2]

#debug..
puts "remote path: #{remote_path}"
puts "remote md5: #{remote_md5}"
puts "remote size: #{remote_size}"

# first find volume that is big enough

current_vol = ''

VOLUMES.each do |v|

  if File.exist? v
    df_out = `df -k #{v}`
    cur_size = df_out.split("\n")[1].split(' ')[3]
    if (remote_size.to_i / 1024) < cur_size.to_i
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

# now download and check md5's

folder_name = File.basename(remote_path)
folder_name.chomp!('.*')
folder_name.chomp!('.7z')

Dir.chdir current_vol do

  `mkdir #{folder_name}`
  puts "Downloading #{remote_path}..."
  system "scp #{SERVERNAME}:#{remote_path} #{folder_name}"
  fnames = Dir.glob("#{folder_name}/#{folder_name}.7z.*").sort.join(',')
  md5 = `thor client:md5 #{fnames} #{remote_md5}`
  puts md5
  if md5 =~ /ERROR/  
    # bad checksum!
    # remove file
    puts "ERROR: BAD MD5SUM!  ABORTING"
    system "rm -rv #{folder_name}"
    exit 1

  end

  # extract readme, alter and resave within
  Dir.chdir folder_name do
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

    # put iarchive id into read me
    
    if new_id == 0
	    puts "ERROR: Could not fetch new archive id from iarchive."
    else
        system "thor client:update_readme #{folder_name}.7z.001 iarchive_id #{new_id}"
	`curl -v -F "readme_file=@README.json" -u iarchive:iarchive http://bioinf.itmat.upenn.edu/iarchive/update/#{new_id}`
    end

  end

end

puts "FILE ARCHIVED!"

