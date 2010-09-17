#!/usr/bin/ruby
#####################
#
#  Client script that verifies each file in analysis 
#  FOR UNZIPPED PROJECTS
#  Dave Austin @ ITMAT UPENN
#
#
#######

require 'rubygems'
require 'json'
require 'restclient'

FILELIST_URL = 'http://bioinf.itmat.upenn.edu/qInteract2/analysis/files'
PROJECT_ID_COL = 11
VOLUMES = [ "/Volumes/3440_Archive_001",
	    "/Volumes/3440_Archive_002",
	    "/Volumes/3440_Archive_003",
	    "/Volumes/3440_Archive_004",
	    "/Volumes/3440_Archive_005" ]

# first read in projects and get a local project list

project_ids = []

# project_ids = [170,172,220,223,224,227,229,230,238,247,249,250,256,281,282] # timeout reruns - redo 1

# project_ids = [172,224,239,240,245] #missing file reruns - redo 2

# project_ids = [303,321] # file discrepancies - redo 3

project_file = File.open(ARGV[0])

project_file.each do |l|
  
  project_ids << l.split("\t")[10].to_i
  
end

project_file.close
project_ids.uniq!
project_ids.sort!

# then find path, enumerate through each project

project_ids.each do |pid|

  error = false
  puts "\n\nEXAMINING PROJECT #{pid}..."

  # get project path

  project_path = ''

  VOLUMES.each do |v|

    project_path = "#{v}/project_#{pid}" if File.exist? "#{v}/project_#{pid}"

  end

  if project_path.empty?
    puts "ERROR: PROJECT PATH NOT FOUND FOR PROJECT #{pid}"
    next
  else
    puts "Found project path: #{project_path}"
  end
  
  # get readme
    readme = {}
  
  begin
    readme = JSON.parse File.open("#{project_path}/README.json").read
  rescue
    puts "ERROR:  CANNOT LOAD README FOR PROJECT #{pid}"
    next
  end  
  
  # loop through each analysis in readme
  readme['analyses'].each do |analysis|
    
    puts "Checking analysis #{analysis['analysis_id']}..."
    
    remote_file_list = {}
    
    begin 
      # RestClient.get("#{FILELIST_URL}/#{analysis['analysis_id']}") do |res| 
        # puts res[0]
        # remote_file_list = JSON.parse res.to_s
      # end
      remote_file_list = JSON.parse `curl -s #{FILELIST_URL}/#{analysis['analysis_id']}`
    rescue Exception => e
      puts "ERROR: Could not build remote file list #{e.message}"
      error = true
      break
    end

    # check fasta file
    remote_fasta_path = File.basename(remote_file_list['fasta']['path'])
    remote_fasta_size = remote_file_list['fasta']['size'].to_i
    
    ext = File.extname(remote_fasta_path)
    new_filename = "#{File.basename(remote_fasta_path, ext)}.analysis_#{analysis['analysis_id']}#{ext}"
    if File.exist? "#{project_path}/data_files/#{new_filename}"
      puts "Using new filename: #{new_filename}"
      remote_fasta_path = new_filename
    end  
    
    if ! File.exist? "#{project_path}/data_files/#{remote_fasta_path}"
      puts "ERROR: COULD NOT FIND project_#{pid}/data_files/#{remote_fasta_path}"
      error = true
    elsif File.size "#{project_path}/data_files/#{remote_fasta_path}" != remote_fasta_size
      puts "ERROR: FOUND SIZE DISCREPANCY FOR project_#{pid}/data_files/#{remote_fasta_path}. Found #{File.size "#{project_path}/data_files/#{remote_fasta_path}"} expected #{remote_fasta_size}."
    
    else
      # do nothing
      
    end

    # check lims files
    remote_file_list['lims_files'].each do |rf|
      
      remote_file_path = File.basename(rf['path'])
      remote_file_size = rf['size'].to_i

      ext = File.extname(remote_file_path)
      new_filename = "#{File.basename(remote_file_path, ext)}.analysis_#{analysis['analysis_id']}#{ext}"
      if File.exist? "#{project_path}/data_files/#{new_filename}"
        puts "Using new filename: #{new_filename}"
        remote_file_path = new_filename
      end

      if ! File.exist? "#{project_path}/data_files/#{remote_file_path}"
        puts "ERROR: COULD NOT FIND project_#{pid}/data_files/#{remote_file_path}"
        error = true
      elsif File.size "#{project_path}/data_files/#{remote_file_path}" != remote_file_size
        puts "ERROR: FOUND SIZE DISCREPANCY FOR project_#{pid}/data_files/#{remote_file_path}. Found #{File.size "#{project_path}/data_files/#{remote_file_path}"} expected #{remote_file_size}."

      else
        # do nothing

      end
      
    end

    # check analysis files
    remote_file_list['analysis_files'].each do |rf|
      
      remote_file_path = File.basename(rf['path'])
      remote_file_size = rf['size'].to_i

      if ! File.exist? "#{project_path}/analysis_#{analysis['analysis_id']}/#{remote_file_path}"
        puts "ERROR: COULD NOT FIND project_#{pid}/analysis_#{analysis['analysis_id']}/#{remote_file_path}"
        error = true
      elsif File.size "#{project_path}/analysis_#{analysis['analysis_id']}/#{remote_file_path}" != remote_file_size
        puts "ERROR: FOUND SIZE DISCREPANCY FOR project_#{pid}/analysis_#{analysis['analysis_id']}/#{remote_file_path}. Found #{File.size "#{project_path}/analysis_#{analysis['analysis_id']}/#{remote_file_path}"} expected #{remote_file_size}."

      else
        # do nothing

      end
      
    end

    
  end
  
  if error
    puts "ERROR: PROJECT #{pid} NOT OK"
  else
    puts "PROJECT #{pid} OK"
  end

end

