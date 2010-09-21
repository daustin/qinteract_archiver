require 'rubygems'
require 'sequel'
require 'json'

# banner
puts <<EOL
##########################################
#
#   qInteract Size Summary
#   Dave Austin - ITMAT @ UPENN
#
#   Usage: ruby qinteract_size_summary.rb 
#
#   Tries to output tsv of projects and their total sizes (in KBs). adds 40% to tgz for grand total estimation
#
#   Outputs:  project_id total_du_size total_tgz_size total_lims_size total_fasta_size apprx_grand_total
#
##########################################
EOL

### CLASS VARS

QINTERACT_DATA_PATH = '/data/www/htdocs/qInteract/data2'
QINTERACT_DBLIB_PATH = '/data/www/htdocs/qInteract/dblib'
QINTERACT_ARCHIVE_PATH = '/wdbackup'
LIMS_PATH_PREFIX = '/export'
LIMS_SCRIPT_PATH='/mnt/san/lims1'
LIMS_CURRENT_PATH = '/lims/data_files'

#first lets get to the databases

puts 'Initializing database connections...'
qinteract_db = Sequel.connect('mysql://qinteractdba:qinteract@db/qinteract_dev') 

# loop through each project
puts "project id\ttotal du size\ntotal tgz size\ttotal lims size\ttotal fasta size\testimated grand total"

qinteract_db[:pipeline_projects].each do |project|
  dir_total = 0
  tgz_total = 0
  lims_total = 0
  fasta_total = 0
  lims_inputs = []
  fasta_inputs = []
  
  analyses = qinteract_db[:pipeline_analyses].where(:pipeline_project_id => project[:id])
  analyses.each do |a|
    if a[:archived].to_i == 1
      # add to tgz
      fsize = `ls -l #{QINTERACT_ARCHIVE_PATH}/archive_#{a[:id]}.tgz`.split[4].to_i
      tgz_total += (fsize /1024).round 
      
    else
      # add to du
      dsize = `du -sk #{QINTERACT_DATA_PATH}/#{a[:path]}`.split(' ')[0].to_i
      dir_total += dsize
    end
  
    job = qinteract_db[:jobs].where(:pipeline_analysis_id => a[:id]).first
  
    # add fasta to array
    fasta = qinteract_db[:analysis_settings].where(:job_id => job[:id]).first[:prot_db]
    fasta_inputs << fasta
  
    # add lims files to array

    job[:runscript].each_line do |l|
      if l =~ /scp (#{LIMS_SCRIPT_PATH}\/.+) proteomics\@/
         # found a reference to a lims input
         path_array = $1.split('/')
         dname = path_array[path_array.length-2]
         fname = path_array.last
         # now lets see if we can find the file now..
         o = `find #{LIMS_CURRENT_PATH} -iname #{fname}`               
         o_array = o.split("\n")
         best = o_array.select {|p| p =~ /#{path_array[path_array.length-2]}/}
         if best.empty?
           last_file = o_array.last
         else
           last_file = best.last
         end
        lims_inputs << last_file

      end
      
    end

  
  end
  
  # go through each lims.uniq file and ls add it in
  lims_inputs.uniq.each do |f|
    fsize = `ls -l #{f}`.split(' ')[4].to_i
    lims_total += (fsize /1024).round
    
  end
  # go through each fasta.uniq file and ls add it in
  fasta_inputs.uniq.each do |f|
   
    fsize = `ls -l #{QINTERACT_DBLIB_PATH}/#{f}`.split(' ')[4].to_i
    fasta_total += (fsize /1024).round
    
  end

  #  print out
  puts "#{project[:id]}\t#{dir_total}\t#{tgz_total}\t#{lims_total}\t#{fasta_total}\t#{dir_total + (tgz_total*1.4) + lims_total + fasta_total}"
  
end

