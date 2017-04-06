require 'fileutils'
require 'json'
require 'digest'
require 'rest-client'
require 'pathname'
require 'rubygems'
require 'zip'

def compress(path, file)
  Zip::File.open(file, Zip::File::CREATE) do |zipfile|
    Dir.chdir path
    Dir.glob('**/*').reject { |fn| File.directory?(fn) }.each do |file|
      next if file == '/home/niharika/Desktop/ClientServer/applications/fuifll06/guid.json'
      #      puts "Adding #{file}"
      path = path.to_s
      zipfile.add(file.sub(path + '/', ''), file)
    end
  end
end

def find_files	# iteratively finds files in a directory
  hash = []
  blob_array = []
  file_array = Dir[File.join('./applications/fuifll06/', '**', '*')].reject { |p| File.directory? p }
  file_array.each do |file|
    absolute_path = Pathname.new(File.expand_path(file))
    project_root  = Pathname.new('/home/niharika/Desktop/ClientServer/applications/fuifll06')
    relative_path = absolute_path.relative_path_from(project_root)
    relative_file_path = relative_path.to_s
    directory, _base = relative_path.split
    directory_s = directory.to_s
    #    puts directory
    #    puts base
    file_content = File.read(file)
    if directory_s == '.' # if it is file directly in root folder
      hash_content = Digest::SHA1.hexdigest file_content
    else # if its a directory
      hash_content = Digest::SHA1.hexdigest file_content
      new_path = File.join(directory_s, hash_content)
      hash_content = new_path
    end
    blob_array << hash_content if File.size(file) / 1024 > 64
    file_data = JSON.parse({ 'FileName' => relative_file_path, 'Hash' => hash_content }.to_json)
    hash << file_data
  end
  jdata = { 'ApplicationName' => 'fuifll06', 'ApplicationFiles' => hash }.to_json
  # puts blob_array
  [jdata, blob_array]
end

start = Time.now
complete_json = find_files[0]
json = JSON.parse(complete_json)
blob_array = find_files[1]

blob_json = JSON.parse({ 'Blob_array' => blob_array }.to_json)
# puts blob_json
sha_end = Time.now - start
puts 'sha_end'
puts sha_end
puts 'sha_end'
jdata = { 'Name' => json['ApplicationName'] }.to_json
begin
  File.new('./applications/fuifll06/guid.json', File::RDWR | File::CREAT | File::EXCL)
rescue
  puts 'file exists'
end

response = RestClient.post 'http://localhost:9292/apps', { data: jdata }, content_type: :json, accept: :json
json_response = JSON.parse(response)
if response.code == 200
  guidjson = JSON.parse(File.read('./applications/fuifll06/guid.json'))
  # guidjson = JSON.parse(guidjson)
  puts guidjson.class
  puts json_response['GUID']
  if guidjson['GUID'] == json_response['GUID']
    blob_json['GUID'] = guidjson['GUID']
    blob_json = blob_json.to_json
    # puts blob_json
    puts 'above match'
    match_start = Time.now
    puts match_start
    match_response = RestClient.post 'http://localhost:9292/match', { data: blob_json }, content_type: 'application/json', accept: :json
    match_end = Time.now - match_start
    puts 'match_end'
    puts match_end
    puts 'match_end'
    process_time_start = Time.now
    # res=JSON.parse(match_response)
    res = match_response

    guid = res['GUID']
    json['GUID'] = guid
    json = json.to_json
    File.open('./applications/fuifll06/guid.json', 'w') do |f|
      f.puts JSON.pretty_generate(json)
      f.close
    end

    # puts json = JSON.parse(json)
    Dir.mkdir('/home/niharika/Desktop/ClientServer/applications/zip')
    json['ApplicationFiles'].each do |hash|
      if res['Known_Hash'].include?hash['Hash']
        # puts "file present"
      else
        json['ApplicationFiles'].each_index do |o|
          next unless hash['Hash'] == json['ApplicationFiles'][o]['Hash']
          filename = json['ApplicationFiles'][o]['FileName']
          path = '/home/niharika/Desktop/ClientServer/applications/fuifll06' + '/' + filename
          guid_path = '/home/niharika/Desktop/ClientServer/applications/fuifll06/guid.json'
          guid_path = Pathname.new(guid_path)
          project_root = Pathname.new(path)
          # puts project_root
          FileUtils.cp_r guid_path, '/home/niharika/Desktop/ClientServer/applications/zip'
          absolute_path = Pathname.new(File.expand_path(project_root))
          application_root = Pathname.new('/home/niharika/Desktop/ClientServer/applications/fuifll06')
          relative_path = absolute_path.relative_path_from(application_root)
          dir, _file = relative_path.split
          dir = dir.to_s
          path = Pathname.new('/home/niharika/Desktop/ClientServer/applications/zip' + '/' + dir)
          # puts path
          FileUtils.mkdir_p(path) unless File.exist?(path)
          FileUtils.cp_r project_root, path
        end
      end
    end
    compress('/home/niharika/Desktop/ClientServer/applications/zip', '/home/niharika/Desktop/ClientServer/applications/zip.zip')
    File.open('/home/niharika/Desktop/ClientServer/applications/zip.zip')
    bits_start = Time.now
    puts "i'm sending the file to server"
    process_time_end = Time.now - process_time_start
    puts 'process_time_end'
    puts process_time_end
    puts 'process_time_end'
    RestClient.post 'http://localhost:9292/bits', myfile: File.open('/home/niharika/Desktop/ClientServer/applications/zip.zip', 'rb')
    bits_end = Time.now - bits_start
    puts 'bits_end'
    puts bits_end
    puts 'bits_end'
    FileUtils.rm('/home/niharika/Desktop/ClientServer/applications/zip.zip')
  end
elsif response.code == 201
  #  puts "response is 201"
  # puts response
  json['GUID'] = json_response['GUID']

  File.open('./applications/fuifll06/guid.json', 'w') do |f|
    f.puts JSON.pretty_generate(json)
    f.close
  end

  response = JSON.parse(response)
  blob_json['GUID'] = response['GUID']
  blob_json = blob_json.to_json
  # puts blob_json
  match_start = Time.now
  puts match_start
  res = RestClient.post 'http://localhost:9292/match', { data: blob_json }, content_type: 'application/json', accept: :json
  match_end = Time.now - match_start
  puts 'match_end'
  puts match_end
  puts 'match_end'
  process_time_start = Time.now

  res = res.to_s
  path = response['Name']
  Dir.chdir('applications')
  path = Dir.pwd + '/' + path
  path = Pathname.new(path)
  # puts path.class
  begin
    File.new('./applications/zip.zip', File::RDWR | File::CREAT | File::EXCL)
  rescue
    puts 'file exists'
  end
  #  puts json

  Dir.mkdir('/home/niharika/Desktop/ClientServer/applications/zip')
  FileUtils.copy_entry path, '/home/niharika/Desktop/ClientServer/applications/zip'
  guid_path = '/home/niharika/Desktop/ClientServer/applications/fuifll06/guid.json'
  FileUtils.cp_r guid_path, '/home/niharika/Desktop/ClientServer/applications/zip'
  compress('/home/niharika/Desktop/ClientServer/applications/zip', '/home/niharika/Desktop/ClientServer/applications/zip.zip')
  File.open('/home/niharika/Desktop/ClientServer/applications/zip.zip')
  bits_start = Time.now
  puts "i'm sending the file to server"
  process_time_end = Time.now - process_time_start
  puts 'process_time_end'
  puts process_time_end
  puts 'process_time_end'
  RestClient.post 'http://localhost:9292/bits', myfile: File.open('/home/niharika/Desktop/ClientServer/applications/zip.zip', 'rb')
  bits_end = Time.now - bits_start
  # puts bits
  puts 'bits_end'
  puts bits_end
  puts 'bits_end'
  FileUtils.rm('/home/niharika/Desktop/ClientServer/applications/zip.zip')
  # Dir.delete("/home/niharika/Desktop/ClientServer/applications/zip")
end

puts 'total_time'
puts Time.now - start
puts 'total_time'

