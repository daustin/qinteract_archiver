require 'rubygems'
require 'sequel'
require 'json'

# banner
puts <<EOL
##########################################
#
#   Lims lookup
#   Dave Austin - ITMAT @ UPENN
#
#   Usage: ruby lims_lookup.rb <tabbed_list>
#   Attaches lims info to each qinteract record
#
#   Should be run as root to avoid perm issues!
#
##########################################
EOL

### CLASS VARS

MD5CMD = 'md5sum' # needs to output only md5 hash, or a wsv with the hash as the first value
LIMS_PATH_PREFIX = '/export'

#indexes of columns in tsv file

INPUT_PATH_COL = 9
LIMS_REFERENCE = 8

# is there a header?
header = true

#first lets get to the databases

# puts 'Initializing database connections...'
lims_db = Sequel.connect('mysql://ibfrw:ibfrw@localhost/itmat_lims')

fin = File.open(ARGV[0])
fin.each do |l|

next if l.strip.empty?

  if header
    header = false
    puts "#{l.strip}\tmd5\tLIMS_PK\tLIMS_Project_id\tLIMS_Project_name\tLIMS_login\tLIMS_user"
  else
  
    la = l.strip.split("\t")
  
    #lookup md5
    md5 = `#{MD5SUM} #{LIMS_PATH}#{la[INPUT_PATH_COL]}`
    md5 = md5.split(' ')[0]
  
    #lookup lims project info, find date folder and lims reference
    lims_ref = la[LIMS_REFERENCE]
    date_folder = lims_ref.split('/')[0]
    file_ref = lims_ref.split('/')[0]
  
    #now look it up
    ref = lims_db[:assets].where(:filesystem_name => file_ref, :filesystem_path => date_folder).first
    project = lims_db[:projects].where(:id => ref[:project_id].to_i).first
    user = lims_db[:users].where(:id => project[:user_id]).first

    #print it out
  
    puts "#{l.strip}\t#{ref[:id]}\t#{ref[:project_id]}\t#{project[:name]}\t#{user[:login]}\t#{user[:fname]} #{user[:lname]}"


  end

end

fin.close

