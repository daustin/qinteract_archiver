require 'rubygems'
require 'sequel'
require 'json'
require 'thor'

# banner
puts <<EOL
##########################################
#
#   qInteract Archiver
#   Dave Austin - ITMAT @ UPENN
#
#   Usage: ruby qinteract_archiver.rb <tabbed_list>
#
#   WARNING: ASSUMES INPUT FILE LIST IS SORTED 
#   BY PROJECT ID THEN ANALYSIS ID
#   
#   Should be run as root to avoid perm issues!
#
##########################################
EOL

### CLASS VARS

MD5CMD = 'md5sum' # needs to output only md5 hash, or a wsv with the hash as the first value
QINTERACT_DATA_PATH = '/export/www-data/www/htdocs/qInteract/data2'
QINTERACT_DBLIB_PATH = '/export/www-data/www/htdocs/qInteract/dblib'
QINTERACT_ARCHIVE_PATH = '/export/wdbackup'
CLIENT_ADDRESS = 'itmat@powmac.itmat.upenn.edu'
CLIENT_PATH = '/Users/itmat/qinteract_archiver_client.rb'
LIMS_PATH_PREFIX = '/export'

#indexes of columns in tsv file

INPUT_PATH_COL = 1
ANALYSIS_ID_COL = 2
QINTERACT_OWNER_COL = 3
PROJECT_NAME_COL = 4
ANALYSIS_NAME_COL = 5
CREATED_AT_COL = 6
PROT_DB_COL = 8
PROJECT_ID_COL = 10
MD5_COL = 11
LIMS_ASSET_ID_COL = 12
LIMS_PROJECT_ID_COL = 13
LIMS_PROJECT_NAME_COL = 14
LIMS_OWNER_COL = 15
LIMS_FULLNAME_COL = 16

#first lets get to the databases

puts 'Initializing database connections...'
qinteract_db = Sequel.connect('mysql://qinteractdba:qinteract@localhost/qinteract_dev') 
lims_db = Sequel.connect('mysql://ibfrw:ibfrw@localhost/itmat_lims')

#################################
####### HELPER CLASS ############
#########


class ArchiveHelper

  @@qdb = Sequel.connect('mysql://qinteractdba:qinteract@localhost/qinteract_dev') 
  @@ldb = Sequel.connect('mysql://ibfrw:ibfrw@localhost/itmat_lims')

  # compacts owner list and removes redundancies
  def self.compact_owners(owners = Array.new)

    compacted = []
    owners.sort! { |x,y| x[0] <=> y[1] }
    owners.uniq!
    owners.each do |o|
      
      # search for a better entry that has a fullname
      if o[1].nil? || o[1].strip == ''
        
        fully_named = owners.select { |os| (os[0] == o[0]) && (os[1].strip != '') }
        if fully_named.size > 0
          compacted << fully_named[0]
        else
          compacted << o
        end
        
      else  
        compacted << o
      end
      
    end
    
    return compacted.uniq
      
  end
  
  # gathers filenames from lims projects and compacts list
  def self.compact_lims_projects(lims_projects = [])

    compacted = []
    lims_projects.sort! {|x,y| x[:lims_project_id].to_i <=> y[:lims_project_id].to_i}
    lp_hash = {}
    last_lp_id = 0
    lims_projects.each do |lp|
      
      if last_lp_id != lp[:lims_project_id].to_i
        
        compacted << lp_hash unless lp_hash.empty?
        lp_hash = Hash.new
        lp_hash[:lims_project_id] = lp[:lims_project_id]
        lp_hash[:lims_project_name] = lp[:lims_project_name]
        lp_hash[:lims_project_owner] = lp[:lims_project_owner]
        lp_hash[:lims_project_decription] = lp[:lims_project_description]
        lp_hash[:files] = []
        
      end
      
      lp_hash[:files] << lp[:file]
      last_lp_id = lp[:lims_project_id].to_i
      
    end
  
    compacted << lp_hash
    return compacted
  
  end
  
  #
  # finalizes process by finishing the project_hash, fetching the rest of the files,
  # 
  def self.collect_and_archive(project_hash)
    
    # collect and compact owners information
    owners = []
    
    puts "Assembling owners list..."
    project_hash[:analyses].each do |a|
      owners << a[:owner] unless a[:owner].nil?

      a[:lims_projects].each do |lp|
        owners << lp[:lims_project_owner] unless lp[:lims_project_owner].nil?
      end

    end

    project_hash[:owners] = ArchiveHelper.compact_owners(owners)
    
    # loop through each analysis and copy directories, add to file_list
    
    puts "Adding other files to analyses..."    
    Dir.chdir project_hash[:archive_folder_name] do
    
      project_hash[:analyses].each do |a|
      
        analysis = @@qdb[:pipeline_analyses].where(:id => a[:analysis_id].to_i).first

        Dir.mkdir "analysis_#{a[:analysis_id]}"  

        ## check and handle if it is archived!
        if analysis[:archived] == 1
          
          puts "Analysis is archived to different location.  Retrieving #{QINTERACT_ARCHIVE_PATH}/archive_#{a[:analysis_id]}.tgz"
          # copy archive file to project directory and upzip
          `cp -v #{QINTERACT_ARCHIVE_PATH}/archive_#{a[:analysis_id]}.tgz .`
          `tar -xvf archive_#{a[:analysis_id]}.tgz`
          old_folder_name = `tar -tf archive_#{a[:analysis_id]}.tgz`
          old_folder_name = old_folder_name.split('/')[0]    
          # rename folder name
          `find #{old_folder_name} -type f -name '*' -exec mv {} analysis_#{a[:analysis_id]}/ \\;`
          # remove qinteract archived tar
          system "rm -rv #{old_folder_name}"
          system "rm -v archive_#{a[:analysis_id]}.tgz"
          
        else
      
          # build path to project directory
          project_path = "#{@@qdb[:pipeline_projects].where(:id => project_hash[:project_id]).first[:path]}"
          analysis_path = "#{@@qdb[:pipeline_analyses].where(:id => a[:analysis_id]).first[:path]}"
          `find #{QINTERACT_DATA_PATH}/#{analysis_path} -type f -name '*' -exec cp {} ./analysis_#{a[:analysis_id]}/ \\;`

        end

        Dir.glob("analysis_#{a[:analysis_id]}/*") do |f|
        
          # add into file_list 
          md5 = `#{MD5CMD} #{f}`
          project_hash[:file_list] << { :path => "#{f}", :md5 => md5.split(' ')[0] }
                    
        end

        puts "Added files for analysis #{a[:analysis_id]} - #{a[:analysis_name]}."
        
      end
    
      puts "Project contains #{project_hash[:file_list].size} total files."
      # save file hash as README.json, generate file list
      File.open("README.json", 'w+') { |f| f.write(project_hash.to_json) }
      `find . -type f > filelist.txt`
      puts "Generated filelist.txt"
    
    end
    
    # tar & zip directory
    puts "Zipping and compressing project..."
    system "thor archive:compress #{project_hash[:archive_folder_name]}"
    
    # call client script, for now just SCP archive to
    puts "Generating md5, size. Calling client script..."
    archive_md5 = `thor archive:md5 #{project_hash[:archive_folder_name]}`
    archive_md5.strip!
    archive_size = 0
    Dir.glob("#{project_hash[:archive_folder_name]}.7z.*") do |fs|

      archive_size += File.size("#{fs}").to_i

    end

    puts "RUNNING CLIENT: ssh #{CLIENT_ADDRESS} #{CLIENT_PATH} '#{Dir.pwd}/#{project_hash[:archive_folder_name]}.7z.*' #{archive_md5} #{archive_size}"

    ssh_out = `ssh #{CLIENT_ADDRESS} #{CLIENT_PATH} '#{Dir.pwd}/#{project_hash[:archive_folder_name]}.7z.*' #{archive_md5} #{archive_size}`

    puts "Client output: ==> "
    puts "#{ssh_out}"
    puts " <== "    

    # clean up
    puts "Cleaning up project stage space..."
    system "rm -rf #{project_hash[:archive_folder_name]}*"

    if ssh_out =~ /ERROR/
      
      puts "ERROR RECIEVED FROM CLIENT. ABORTING PROJECT #{project_hash[:project_id]} - #{project_hash[:project_name]}"
      exit 1

      
    else

      puts "FINISHED ARCHIVING PROJECT #{project_hash[:project_id]} - #{project_hash[:project_name]}"
      
    end
    
  end
    
  
end

#################################
#################################

# placeholder vars. hashes 
last_project_id = 0
last_analysis_id = 0
project_hash = Hash.new
analysis_hash = Hash.new

# build nested hash array from excel file, loop until end!
puts "Processing #{ARGV[0]}..."
f = File.open(ARGV[0]).each do |l|
  la = l.strip.split("\t")
  
  this_project_id = la[PROJECT_ID_COL]
  this_analysis_id = la[ANALYSIS_ID_COL]
  
  if this_project_id != last_project_id
    #cleanup current hash and begin gathering and zipping 
    unless project_hash.empty?

      # add analysis to project hash and archive!
      analysis_hash[:lims_projects] = ArchiveHelper.compact_lims_projects(analysis_hash[:lims_projects])
      project_hash[:analyses] << analysis_hash
      puts "Post processing project hash.  Collecting and archiving files..."
      ArchiveHelper.collect_and_archive(project_hash)
            
    end
    
    project_hash = Hash.new
    
    # populate new values from row, init owners
    puts "Found new project #{la[PROJECT_ID_COL].to_i} - #{la[PROJECT_NAME_COL]}"
    project_hash[:archive_folder_name] = "project_#{la[PROJECT_ID_COL]}"
    project_hash[:project_name] = la[PROJECT_NAME_COL]
    project_hash[:project_id] = la[PROJECT_ID_COL].to_i
    project_hash[:owners] = []
    project_hash[:analyses] = []
    project_hash[:file_list] = Array.new
      
    # look up project owner and add to owner array
    project_hash[:owners] << [ "#{qinteract_db[:pipeline_projects].where(:id => la[PROJECT_ID_COL]).first[:owner]}", ''] 
    
    # create data_file dir
    puts "Creating project staging dirs."
    Dir.mkdir project_hash[:archive_folder_name]
    Dir.mkdir "#{project_hash[:archive_folder_name]}/data_files"          

  end
        
  if this_analysis_id != last_analysis_id
    
    # add existing analysis hash to project unless it's a new project
    unless this_project_id != last_project_id
      
      analysis_hash[:lims_projects] = ArchiveHelper.compact_lims_projects(analysis_hash[:lims_projects])
      project_hash[:analyses] << analysis_hash
      
    end
    
    # start new analysis hash
    analysis_hash = Hash.new
    
    puts "Found new analysis #{la[ANALYSIS_ID_COL].to_i} - #{la[ANALYSIS_NAME_COL]}"
    # now add analysis vars from db, etc
    analysis_hash[:analysis_id] = la[ANALYSIS_ID_COL].to_i
    analysis_hash[:analysis_name] = la[ANALYSIS_NAME_COL]
    analysis_hash[:owner] = [ la[QINTERACT_OWNER_COL], '' ] 
    analysis_hash[:created_at] = la[CREATED_AT_COL]

    # move prot_db to data_files, add to file list
    puts "Using prot db: #{la[PROT_DB_COL]}"
    analysis_hash[:prot_db] = "data_files/#{File.basename(la[PROT_DB_COL])}"
    
    file_hash = { :path => "data_files/#{File.basename(la[PROT_DB_COL])}" }
   
    if File.exist?("./#{project_hash[:archive_folder_name]}/data_files/#{File.basename(la[PROT_DB_COL])}")

      # take md5 of each file.  if they are different then rename with analysis ID and copy
      puts "Already added #{File.basename(la[PROT_DB_COL])}"
      existing_md5 = `#{MD5CMD} ./#{project_hash[:archive_folder_name]}/data_files/#{File.basename(la[PROT_DB_COL])}`
      existing_md5 = existing_md5.split(' ')[0]
      new_md5 = `#{MD5CMD} #{QINTERACT_DBLIB_PATH}/#{la[PROT_DB_COL]}`
      new_md5 = new_md5.split(' ')[0]
      
      if existing_md5 != new_md5
        
        ext = File.extname("#{QINTERACT_DBLIB_PATH}/#{la[PROT_DB_COL]}")
        base_no_ext = File.basename("#{QINTERACT_DBLIB_PATH}/#{la[PROT_DB_COL]}", ext)
        new_filename = "#{base_no_ext}.analysis_#{analysis_hash[:analysis_id]}#{ext}"        
        puts "Found name conflict. Saving new file as #{new_filename}. Updating Analysis hash accordingly."
        analysis_hash[:prot_db] = "data_files/#{new_filename}"
        file_hash[:path] = "data_files/#{new_filename}" # redo path

        # copy NEW file into data files and compute md5
        system "cp -v #{QINTERACT_DBLIB_PATH}/#{la[PROT_DB_COL]} ./#{project_hash[:archive_folder_name]}/data_files/#{new_filename}"
        puts "running #{MD5CMD} ./#{project_hash[:archive_folder_name]}/data_files/#{new_filename}"
        md5 = `#{MD5CMD} ./#{project_hash[:archive_folder_name]}/data_files/#{new_filename}`
        file_hash[:md5] = md5.split(' ')[0]
        project_hash[:file_list] << file_hash
        puts "Added prot_db file #{file_hash[:path]} to file list."
                        
      else
        
        # do nothing!
        
      end
      

    else

      # copy file into data files and compute md5
      system "cp -v #{QINTERACT_DBLIB_PATH}/#{la[PROT_DB_COL]} ./#{project_hash[:archive_folder_name]}/data_files"
      puts "running #{MD5CMD} ./#{project_hash[:archive_folder_name]}/data_files/#{File.basename(la[PROT_DB_COL])}"
      md5 = `#{MD5CMD} ./#{project_hash[:archive_folder_name]}/data_files/#{File.basename(la[PROT_DB_COL])}`
      file_hash[:md5] = md5.split(' ')[0]
      project_hash[:file_list] << file_hash
      puts "Added prot_db file #{file_hash[:path]} to file list."

    end
    
    # init lims projects
    analysis_hash[:lims_projects] = []

    # create search hash
    
    job = qinteract_db[:jobs].where(:pipeline_analysis_id => la[ANALYSIS_ID_COL]).order(:created_at).last
    unless job.nil?
      
      sequest_search = qinteract_db[:sequest_searches].where(:job_id => job[:id]).first
      mascot_search = qinteract_db[:mascot_searches].where(:job_id => job[:id]).first
      
      if sequest_search 
        puts "Adding Sequest search params to analysis"
        params = qinteract_db[:sequest_params].where(:id => sequest_search[:sequest_param_id]).first
        search = { :algorithm => 'sequest'}
        search[:params] = params.to_hash unless params.nil?
        analysis_hash[:search] = search
        
      elsif mascot_search
        
        puts "Adding Mascot search params to analysis"
        params = qinteract_db[:mascot_params].where(:id => mascot_search[:mascot_param_id]).first
        search = { :algorithm => 'mascot'}
        search[:params] = params.to_hash unless params.nil?
        analysis_hash[:search] = search
        
      else
        # do not add anything to analysis hash
      end

      analysis_setting = qinteract_db[:analysis_settings].where(:job_id => job[:id]).first
      analysis_hash[:xinteract_flags] = analysis_setting[:xinteract_flags] unless analysis_setting[:xinteract_flags].nil?
      analysis_hash[:protein_prophet_flags] = analysis_setting[:prophet_flags] unless analysis_setting[:prophet_flags].nil?
      analysis_hash[:ebp_flags] = analysis_setting[:ebp_flags] unless analysis_setting[:ebp_flags].nil?

    end
  
  end
  
  # add input file info to analysis hash 

  file_path = la[INPUT_PATH_COL]
  basename = File.basename file_path
  lims_hash = {:file => "data_files/#{basename}"}
  lims_hash[:lims_project_id] = la[LIMS_PROJECT_ID_COL].to_i unless la[LIMS_PROJECT_ID_COL].nil?
  lims_hash[:lims_project_name] = la[LIMS_PROJECT_NAME_COL] unless la[LIMS_PROJECT_NAME_COL].nil?
  lims_hash[:lims_project_description] =  lims_db[:projects].where(:id => la[LIMS_PROJECT_ID_COL].to_i).first[:description] unless la[LIMS_PROJECT_ID_COL].nil?
  lims_hash[:lims_project_owner] = [ la[LIMS_OWNER_COL], la[LIMS_FULLNAME_COL].strip ] unless la[LIMS_OWNER_COL].nil?
    
  # add input file info to file_list
  # copy input file to data_files, unless already there
  file_hash = { :path => "data_files/#{basename}" }
  file_hash[:asset_id] = la[LIMS_ASSET_ID_COL] unless la[LIMS_ASSET_ID_COL].nil? || la[LIMS_ASSET_ID_COL] =~ /not in the DB/
  file_hash[:lims_project_id] = la[LIMS_PROJECT_ID_COL].to_i unless la[LIMS_PROJECT_ID_COL].nil?
  file_hash[:lims_owner] = [[ la[LIMS_OWNER_COL], la[LIMS_FULLNAME_COL]]] unless la[LIMS_OWNER_COL].nil?
  
  if File.exist?("./#{project_hash[:archive_folder_name]}/data_files/#{basename}")
  
    # take md5 of each file.  if they are different then rename with analysis ID and copy
    puts "Already added #{File.basename(la[INPUT_PATH_COL])}"
    existing_md5 = `#{MD5CMD} ./#{project_hash[:archive_folder_name]}/data_files/#{File.basename(la[INPUT_PATH_COL])}`
    existing_md5 = existing_md5.split(' ')[0]
    new_md5 = `#{MD5CMD} #{LIMS_PATH_PREFIX}#{la[INPUT_PATH_COL]}`
    new_md5 = new_md5.split(' ')[0]
    
    if existing_md5 != new_md5
      
      ext = File.extname("#{LIMS_PATH_PREFIX}#{la[INPUT_PATH_COL]}")
      base_no_ext = File.basename("#{LIMS_PATH_PREFIX}#{la[INPUT_PATH_COL]}", ext)
      new_filename = "#{base_no_ext}.analysis_#{analysis_hash[:analysis_id]}#{ext}"        
      puts "Found name conflict. Saving new file as #{new_filename}. Updating lims hash accordingly."
      lims_hash[:file] = "data_files/#{new_filename}"
      file_hash[:path] = "data_files/#{new_filename}" # redo path

      # copy NEW file into data files and compute md5
      system "cp -v #{LIMS_PATH_PREFIX}#{la[INPUT_PATH_COL]} ./#{project_hash[:archive_folder_name]}/data_files/#{new_filename}"
      puts "running #{MD5CMD} ./#{project_hash[:archive_folder_name]}/data_files/#{new_filename}"
      md5 = `#{MD5CMD} ./#{project_hash[:archive_folder_name]}/data_files/#{new_filename}`
      file_hash[:md5] = md5.split(' ')[0]
      project_hash[:file_list] << file_hash
      puts "Added input file #{file_hash[:path]} to file list."
                      
    else
      
      # do nothing!
      
    end
    
  else
      
    # copy file into data files and compute md5
    system "cp #{LIMS_PATH_PREFIX}#{la[INPUT_PATH_COL]} ./#{project_hash[:archive_folder_name]}/data_files"
    puts "running #{MD5CMD} ./#{project_hash[:archive_folder_name]}/data_files/#{basename}"
    md5 = `#{MD5CMD} ./#{project_hash[:archive_folder_name]}/data_files/#{basename}`
    file_hash[:md5] = md5.split(' ')[0]
    project_hash[:file_list] << file_hash
    puts "Added input file #{file_hash[:path]} to file list."
        
  end

  #this was moved down here in case data files had a naming conflict
  analysis_hash[:lims_projects] << lims_hash unless la[LIMS_PROJECT_ID_COL].nil? 
  puts "Added input file #{lims_hash[:file]} to analysis #{analysis_hash[:analysis_name]}."

  last_project_id = this_project_id
  last_analysis_id = this_analysis_id
    
end

# add analysis to project hash and archive!
analysis_hash[:lims_projects] = ArchiveHelper.compact_lims_projects(analysis_hash[:lims_projects])
project_hash[:analyses] << analysis_hash
puts "Post processing project hash.  Collecting and archiving files..."
ArchiveHelper.collect_and_archive(project_hash)








