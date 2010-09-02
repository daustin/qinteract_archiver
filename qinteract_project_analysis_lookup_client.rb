#######################################
#
#     checks the archive disks for a given project, then looks for analysis in the archive
#
##


# column lookup

PROJECT_ID_COL = 7
ANALYSIS_ID_COL = 0
MD5CMD = 'md5 -q' # needs to output only md5 hash, or a wsv with the hash as the first value 
VOLUMES = [ "/Volumes/3440_Archive_001",
	    "/Volumes/3440_Archive_002",
	    "/Volumes/3440_Archive_003",
	    "/Volumes/3440_Archive_004" ]


File.read(ARGV[0]).each_line do |l|

project_id = l.split("\t")[PROJECT_ID_COL].strip
analysis_id = l.split("\t")[ANALYSIS_ID_COL].strip

# first figure out which drive the project is on..

puts "Checking for project #{project_id} analysis #{analysis_id}"

project_path = ''

  VOLUMES.each do |v|
  
    if File.exist? "#{v}/project_#{project_id}"

      project_path = "#{v}/project_#{project_id}"
      break
    
    end
  
  end

if project_path == ''
  
  puts "No project found for project #{project_id}"

else
  
  puts "Project #{project_id} already exists"
  #now lets look for the analysis...
  Dir.chdir project_path do 
    
    zout = `7za l project_#{project_id}.7z.001`
    zout.each_line do |zl|
      comp = zl.split(" ").last.strip
      if comp == "project_#{project_id}/analysis_#{analysis_id}"
        puts "Already found analysis #{analysis_id}!"
      end
    end
    
  end
  
end
    
  
end
   


