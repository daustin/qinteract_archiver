require 'rubygems'
require 'json'

puts <<EOL
#######################
#
#  Update Prophet Paths
#  Dave Austin - ITMAT @ UPENN
#
#  Updates paths in prophet outputs so they will work 
#  on a default windows too installation
#
#  Usage: cd project_xxx; ruby update_prophet_paths.rb
#
#  - then open index.html in browser
#
############


EOL

HOST = 'http://localhost'
WEBROOT = 'C:/Inetpub/wwwroot'
TPP_BIN = '/tpp-bin'
PROJECT_ROOT = Dir.pwd

puts "HOST: #{HOST}"
puts "Using TPP Path: #{HOST}#{TPP_BIN}"
puts "CWD: #{PROJECT_ROOT}"

DATABASES = Dir.glob('data_files/*.fasta').sort
puts "Found Databases:"
puts DATABASES.join("\n")

exit 'README.json not found' unless File.exist? 'README.json'
readme = JSON.parse(File.read('README.json'))

index = File.open('index.html', 'w+')
index.write "<HTML><BODY><h1>List of Analyses</h1></BODY></HTML>\n\n"

readme['analyses'].each do |a|

  puts "Updating Analysis #{a['analysis_id']} - #{a['analysis_name']}"
  index.write "<p>Analysis: #{a['analysis_id']} - #{a['analysis_name']}: "
  Dir.chdir "analysis_#{a['analysis_id']}" do

    
    Dir.glob('*.xml').sort.each do |f|
      puts "Updating #{f}..."

    end

    Dir.glob('*.xslt').sort.each do |f|
      puts "Updating #{f}..."


    end

    Dir.glob('*.shtml').sort.each do |f|
      puts "Updating #{f}..."
      fout = File.open("#{f}.tmp",'w+')
      File.open(f).each do |l|
       
        if l =~ /<!--#include virtual=\"(.+pepxml2html.pl.+interact\.xml.+)\" -->/
          # pepxml
          fout.write "<!--#include virtual=\"#{TPP_BIN}/pepxml2html.pl?xmlfile=#{Dir.pwd}/interact.xml&restore_view=yes\" -->\n"
        elsif l =~ /<!--#include virtual=\"(.+pepxml2html.pl.+interact\.xml.+)\" -->/
          # pepxml
          fout.write "<!--#include virtual=\"#{TPP_BIN}/pepxml2html.pl?xmlfile=#{Dir.pwd}/interact.pep.xml&restore_view=yes\" -->\n"
        elsif l =~ /<!--#include virtual=\"(.+protxml2html.pl.+interact-prot\.xml.+)\" -->/ 
          #protxml
           fout.write "<!--#include virtual=\"#{TPP_BIN}/protxml2html.pl?xmlfile=#{Dir.pwd}/interact-prot.xml&restore_view=yes\" -->\n"
        elsif l =~ /<!--#include virtual=\"(.+protxml2html.pl.+interact\.prot\.xml.+)\" -->/ 
          #protxml
           fout.write "<!--#include virtual=\"#{TPP_BIN}/protxml2html.pl?xmlfile=#{Dir.pwd}/interact.prot.xml&restore_view=yes\" -->\n"

        else

          fout.write "#{l}\n"

        end

      end
      
      `mv #{f}.tmp #{f}`
      

    end
    

  end


end

index.write "</BODY></HTML>\n"
