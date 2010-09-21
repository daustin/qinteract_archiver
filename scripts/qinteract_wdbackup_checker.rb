#!/usr/bin/env ruby

require 'rubygems'
require 'sequel'
require 'json'

# banner
puts <<EOL
##########################################
#
#   qInteract Wdbackup checker
#   Dave Austin - ITMAT @ UPENN
#
#   Usage: ruby qinteract_wdbackup_checker.rb <tabbed_list>
#
#   Checks to see if analyses are flagged as archived in qinteract
#   If they are, then lists size of archive file.  and grand total
#
#   ALL SIZES IN KBs
#
##########################################
EOL

### CLASS VARS

QINTERACT_ARCHIVE_PATH = '/Volumes/WDBackup/wdbackup'

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
# qinteract_db = Sequel.connect('mysql://qinteractdba:qinteract@localhost:3306/qinteract_dev') 

qinteract_db = Sequel.connect(:adapter=>'mysql', :host=>'db', :database=>'qinteract_dev', :user=>'qinteractdba', :password=>'qinteract')

# build a uniq list of analyses from the file first

analyses = []
total_size = 0

File.open(ARGV[0]) do |f| 
f.each do |l|

  analyses << l.split("\t")[ANALYSIS_ID_COL].to_i

end
end

analyses.uniq!
analyses.sort!

# loop through

puts "filename\tsize"

analyses.each do |id|
  analysis = qinteract_db[:pipeline_analyses].where(:id => id).first
  if analysis.nil?
    puts "WARNING: ANALYSIS #{id} NOT FOUND"
    next
  end

  if analysis[:archived].to_i == 1
     if File.exist? "#{QINTERACT_ARCHIVE_PATH}/archive_#{id}.tgz"
       # get and print file and size
       size = File.size("#{QINTERACT_ARCHIVE_PATH}/archive_#{id}.tgz")
       total_size += size
       puts "#{QINTERACT_ARCHIVE_PATH}/archive_#{id}.tgz\t#{size/1024}"
     else
        puts "WARNING: #{QINTERACT_ARCHIVE_PATH}/archive_#{id}.tgz NOT FOUND!"
     end
  end

end

puts ""
puts "TOTAL SIZE: #{total_size/1024}"

