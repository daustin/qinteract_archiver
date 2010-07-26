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

class PathUpdater

  ABS_PATH_MATCH = '/data/www/htdocs/qInteract/data2'
  URL_PATH_MATCH = '/qInteract/data2'
  SCHEMA_PATH_MATCH = '/opt/tpp/ppc64/schema'
  DB_PATH_MATCH = '/data/www/htdocs/qInteract/dblib'
  BIN_PATH_MATCH = '/tpp/cgi-bin'

  WEBROOT = 'C:/Inetpub/wwwroot'
  SCHEMA_PATH = 'C:/Inetpub/wwwroot/ISB/schema'
  TPP_BIN = '/tpp-bin'

  # does the actual updating

  def self.UpdateAbsPaths(f, prefix = Dir.pwd)
    
    # matches and updates absolute paths to data files
    count = 0
    fout = File.open("#{f}.tmp",'w+')
    infile = File.open(f)
    infile.each do |l|
      
      if l =~ /(#{ABS_PATH_MATCH}\S+)\"/ || l =~ /(#{ABS_PATH_MATCH}\S+) / || l =~ /(#{ABS_PATH_MATCH}\S+)\?/ || l =~ /(#{ABS_PATH_MATCH}\S+)&/
        count += 1
        # found something to replace
        # first get the basename of the file match, then construct the replace string
        basename = File.basename($1)
        replace = "#{prefix}/#{basename}"
        fout.write "#{l.gsub($1, replace)}"

      else
        
        fout.write "#{l}"
        
      end
      
    end
    infile.close
    fout.close    
    system "mv -f #{f}.tmp #{f}"
    puts "Replaced #{count} absolute paths."
    
  end
  
  def self.UpdateURLPaths(f, prefix = nil)
    
    # matches and updates relative url paths
    count = 0
    # get prefix if nil
    prefix = Dir.pwd.gsub(WEBROOT,'') if prefix.nil?

    fout = File.open("#{f}.tmp",'w+')
    infile = File.open(f)
    infile.each do |l|
      
      if l =~ /(#{URL_PATH_MATCH}.+\.xml)/ || l =~ /(#{URL_PATH_MATCH}.+\.xsl)/
        count += 1
        # found something to replace
        # first get the basename of the file match, then construct the replace string
        basename = File.basename($1)
        replace = "#{prefix}/#{basename}"
        fout.write "#{l.gsub($1, replace)}"

      else
        
        fout.write "#{l}"
        
      end
      
    end
    infile.close
    fout.close  
    system "mv -f #{f}.tmp #{f}"
    puts "Replaced #{count} relative url paths."
    
  end
  
  def self.UpdateDbPaths(f, prefix = Dir.pwd)
    
    # matches and updates absolute paths to db files
    count = 0
    fout = File.open("#{f}.tmp",'w+')
    infile = File.open(f)
    infile.each do |l|
      
      if l =~ /(#{DB_PATH_MATCH}.+\.fasta)/
        count += 1
        # found something to replace
        # first get the basename of the file match, then construct the replace string
        basename = File.basename($1)
        replace = "#{prefix}/#{basename}"
        fout.write "#{l.gsub($1, replace)}"

      else
        
        fout.write "#{l}"
        
      end
      
    end
    infile.close
    fout.close  
    system "mv -f #{f}.tmp #{f}"
    puts "Replaced #{count} absolute db paths."
  end
  
  def self.UpdateSchemaPaths(f, prefix = SCHEMA_PATH)
    
    # matches and updates absolute paths to schema files
    count = 0
    fout = File.open("#{f}.tmp",'w+')
    infile = File.open(f)
    infile.each do |l|
      
      if l =~ /(#{SCHEMA_PATH_MATCH}.+)\"/ ||  l =~ /(#{SCHEMA_PATH_MATCH}.+) /
        count += 1
        # found something to replace
        # first get the basename of the file match, then construct the replace string
        basename = File.basename($1)
        replace = "#{prefix}/#{basename}"
        fout.write "#{l.gsub($1, replace)}"

      else
        
        fout.write "#{l}"
        
      end
      
    end
    infile.close
    fout.close  
    system "mv -f #{f}.tmp #{f}"
    puts "Replaced #{count} absolute schema paths."

  
  end
  
  def self.UpdateBinPaths(f)
    
    # matches and updates relative bin urls to executables
    count = 0
    fout = File.open("#{f}.tmp",'w+')
    infile = File.open(f)
    infile.each do |l|
      
      if l =~ /(#{BIN_PATH_MATCH})/
        count += 1
        # found something to replace
        fout.write "#{l.gsub(BIN_PATH_MATCH, TPP_BIN)}"
        
      else
        
        fout.write "#{l}"
        
      end
      
    end
    infile.close
    fout.close  
    system "mv -f #{f}.tmp #{f}"
    puts "Replaced #{count} relative bin  paths."
  end
  

end

HOST = 'http://localhost'
WEBROOT = 'C:/Inetpub/wwwroot'
WEBROOT_URL_PREFIX = '/ISB/data' # prepended to relative urls to analysis files
SCHEMA_PATH = 'C:/Inetpub/wwwroot/ISB/schema'
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
       
    Dir.glob("*.{xml,xsl,shtml}").sort.each do |f|
      puts "Processing #{f}..."
      
      PathUpdater.UpdateAbsPaths(f)
      PathUpdater.UpdateURLPaths(f)
      PathUpdater.UpdateDbPaths(f, "#{PROJECT_ROOT}/data_files")
      PathUpdater.UpdateSchemaPaths(f)
      PathUpdater.UpdateBinPaths(f)

    end

  end


end

index.write "</BODY></HTML>\n"
