require 'rubygems'
require 'thor'
require 'net/scp'
require 'digest/md5'
require 'pathname'
require 'ftools'
require 'fileutils'
require 'json'


class ClientHelper
  
  @pzip_bin = "/usr/local/bin/7za"
  @work_dir = "/tmp"
  @restore_dir = @work_dir + "/restore-" + Time.now.to_i.to_s
  
  def self.download_archive(archive_file_name)
    Net::SCP.start( "chutney.itmat.upenn.int", "arcuser", :password => "N180Vi" ) do |scp|
      scp.download(archive_file_name, "/tmp")
    end
  end
  
  def self.extract_readme_from_archive(archive_file_name)
    restore_dir = ClientHelper.decompress_file("README.json", archive_file_name)
    afn = Pathname.new(archive_file_name)
    File.move("#{restore_dir}/#{afn.basename.to_s.split(".").first}/README.json", afn.dirname)
    FileUtils.rm_rf([restore_dir])
    if (afn.dirname.to_s.eql?("."))
      return "README.json"
    else
      return afn.dirname.to_s + "/README.json"
    end
  end
  
  def self.update_archive(file_name, archive_file)
    `#{@pzip_bin} u -mx6 -mmt #{archive_file} #{file_name}`
  end
  
  def self.decompress_file(file_name, archive_file)
    `#{@pzip_bin} x -r -o#{@restore_dir } #{archive_file} #{file_name}`
    return @restore_dir
  end
  
  def self.update_readme_to_archive(readme_json_file,archive_file_name)
    ClientHelper.update_archive(readme_json_file, archive_file_name)
  end
  
  #Given an array of globbed file names, comma separated and will return 
  def self.compare_md5(array_archive_filenames, array_md5_hashes)
    bad_file_md5 = Array.new
    count = 0
    array_archive_filenames.split(",").each do | afn |
      if (array_md5_hashes.split(",")[count] != Digest::MD5.hexdigest(File.read(afn)))
        bad_file_md5 << "#{afn} != #{array_md5_hashes.split(',')[count]}"
      end
      count += 1
    end
    if (bad_file_md5.size == 0)
      return "MD5: PASS  - All files passed MD5 inspection"
    else
      return "MD5: ERROR - Following file/MD5 combination did not pass: " + bad_file_md5.join(", ")
    end
  end
  
  def self.append_json_md5(readme_json_file, hash_key, hash_value)
    jf = File.open(readme_json_file, "r")
    jdata = String.new
    jf.each_line do |jfline|
      jdata += jfline
    end
    jparsed = JSON.parse(jdata)
    jparsed['archive_md5'] = {} if jparsed['archive_md5'].nil?
    jparsed['archive_md5']["#{hash_key}"] = hash_value
    File.open(readme_json_file, 'w') {|f| f.write(JSON.generate(jparsed)) }
  end
  
  def self.append_json(readme_json_file, hash_key, hash_value)
     jf = File.open(readme_json_file, "r")
     jdata = String.new
     jf.each_line do |jfline|
       jdata += jfline
     end
     jparsed = JSON.parse(jdata)
     jparsed.update({"#{hash_key}" => hash_value})
     File.open(readme_json_file, 'w') {|f| f.write(JSON.generate(jparsed)) }
   end
  
end


class Client < Thor

  desc "download <file_name including path>", "Grabs the archive file from server"
  def download(archive_file_name)
    ClientHelper.download_archive(archive_file_name)
  end

  desc "md5 <array of archive filenames> <array of md5 hashes>", "Compares the MD5 checksum against the compressed file"
  def md5(array_archive_filenames, array_md5_hashes)
    result = ClientHelper.compare_md5(array_archive_filenames, array_md5_hashes)
    puts result
  end
  
  desc "update_readme <archive file name> <hash key> <hash value>", "Updates the README.json file contained inside of the compressed file"
  def update_readme(archive_file_name, hash_key, hash_value)
    readme_file = ClientHelper.extract_readme_from_archive(archive_file_name)
    ClientHelper.append_json(readme_file, hash_key, hash_value)
    ClientHelper.update_readme_to_archive(readme_file, archive_file_name)
  end
  
  desc "update_readme_md5 <archive file name> <hash key> <hash value>", "Updates the README.json file contained inside of the compressed file"
  def update_readme_md5(archive_file_name, hash_key, hash_value)
    readme_file = ClientHelper.extract_readme_from_archive(archive_file_name)
    ClientHelper.append_json_md5(readme_file, hash_key, hash_value)
    ClientHelper.update_readme_to_archive(readme_file, archive_file_name)
  end
  
end

