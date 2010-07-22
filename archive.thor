require 'rubygems'
require 'thor'
require 'digest/md5'

class ArchiveHelper
  
  @pzip_bin = "/usr/bin/env 7za"
  @md5_bin = "/usr/bin/env md5"
  @work_dir = "/tmp"
  @restore_dir = @work_dir + "/restore-" + Time.now.to_i.to_s
  
  def self.compress(dir)
    `#{@pzip_bin} a -v2000m -mx6 -mmt -r #{dir.split("/").last}.7z #{dir}`
  end
  
  def self.list_archive(archive_file)
    system("#{@pzip_bin} l -mmt #{archive_file}")
  end
  
  def self.decompress_all(archive_file)
    `#{@pzip_bin} x -mmt -r -o#{@restore_dir} #{archive_file}`
  end
  
  def self.decompress_file(file_name, archive_file)
    `#{@pzip_bin} x -r -o#{@restore_dir } #{archive_file} #{file_name}`
    return @restore_dir
  end
  
  def self.test_archive(archive_file)
    system("#{@pzip_bin} t #{archive_file}")
  end
  
  def self.add_archive(file_name, archive_file)
    `#{@pzip_bin} a -mx6 -mmt #{archive_file} #{file_name}`
  end
  
  def self.update_archive(file_name, archive_file)
    `#{@pzip_bin} u -mx6 -mmt #{archive_file} #{file_name}`
  end
  
  def self.delete_archive(file_name, archive_file)
    `#{@pzip_bin} d -r -mmt=on #{archive_file} #{file_name}`
  end

  def self.md5_archive(array_archivefiles)
    md5_array = Array.new
    Dir.glob("#{array_archivefiles}.7z.*").sort.each do | archive_part |
      md5_array << Digest::MD5.hexdigest(File.read(archive_part))
    end
    return md5_array.join(",")
  end

end



class Archive < Thor
  
  desc "compress <dir>", "Compresses a directory"
  def compress(dir)
    ArchiveHelper.compress(dir)
  end
  
  desc "update <file name or wildcard> <archive file name>", "Updates file(s) contained within compressed file"
  def update(file_name, archive_file)
    ArchiveHelper.update_archive(file_name, archive_file)
  end
  
  desc "add <file name> <archive file name>", "Adds file(s) to compressed file"
  def add(file_name, archive_file)
    ArchiveHelper.add_archive(file_name, archive_file)
  end
  
  desc "delete <file name or wildcard> <archive file name>", "Delete file(s) contained within compressed file"
  def delete(file_name, archive_file)
    ArchiveHelper.delete_archive(file_name, archive_file)
  end
  
  desc "decompress_all <archive file name>", "Decompresses all contents of compressed file"
  def decompress_all(archive_file)
    ArchiveHelper.decompress_all(archive_file)
  end
  
  desc "decompress_file <file_name or wildcard> <archive file name>", "Decompress file or files from compressed file"
  def decompress_file(file_name, archive_file)
    ArchiveHelper.decompress_file(file_name, archive_file)
  end
  
  desc "test <archive file name>", "Tests integrity of archive file"
  def test(archive_file)
    ArchiveHelper.test_archive(archive_file)
  end
  
  desc "list <archive file name>", "Lists files contained in compressed file"
  def list(archive_file)
    ArchiveHelper.list_archive(archive_file)
  end
  
  desc "md5 <array of archive filenames>", "Returns the MD5 checksum for the compressed file"
  def md5(array_archivefiles)
    md5sum = ArchiveHelper.md5_archive(array_archivefiles)
    puts md5sum
  end
  
end

