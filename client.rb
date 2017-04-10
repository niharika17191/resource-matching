require 'fileutils'
require 'json'
require 'digest'
require 'rest-client'
require 'pathname'
require 'rubygems'
require 'zip'

def compress(path, file) # compress all the applications files with path and file name as argument
  Zip::File.open(file, Zip::File::CREATE) do |zipfile|
    Dir.chdir path
    Dir.glob('**/*').reject { |fn| File.directory?(fn) }.each do |file|
      next if file == '/path/guid.json'
      #      puts "Adding #{file}"
      path = path.to_s
      zipfile.add(file.sub(path + '/', ''), file)
    end
  end
end

def find_files	# creates json containing SHA and metadata
  hash = []
  blob_array = []
  file_array = Dir[File.join('./applications/fuifll06/', '**', '*')].reject { |p| File.directory? p }
  file_array.each do |file|
    absolute_path = Pathname.new(File.expand_path(file))
    project_root  = Pathname.new('/path')
    relative_path = absolute_path.relative_path_from(project_root)
    relative_file_path = relative_path.to_s
    directory, _base = relative_path.split
    directory_s = directory.to_s
    file_content = File.read(file)
    if directory_s == '.'
      # if it is file directly in root folder

    else # if its a directory
      new_path = File.join(directory_s, hash_content)
      hash_content = new_path
    end
    hash_content = Digest::SHA1.hexdigest file_content
    blob_array << hash_content if File.size(file) / 1024 > 64
    file_data = JSON.parse({ 'FileName' => relative_file_path, 'Hash' => hash_content }.to_json)
    hash << file_data
  end
  jdata = { 'ApplicationName' => 'fuifll06', 'ApplicationFiles' => hash }.to_json
  [jdata, blob_array]
end

# start = Time.now # calculates time of start
complete_json = find_files[0]
json = JSON.parse(complete_json)
blob_array = find_files[1]

blob_json = JSON.parse({ 'Blob_array' => blob_array }.to_json)
# sha_end = Time.now - start # time taken to calculate SHA
jdata = { 'Name' => json['ApplicationName'] }.to_json
begin
  File.new('./applications/fuifll06/guid.json', File::RDWR | File::CREAT | File::EXCL) # creates a guid for every new application
rescue
  puts 'file exists'
end

response = RestClient.post 'http://localhost:9292/apps', { data: jdata }, content_type: :json, accept: :json # first request that sends name of application and gets back guid
json_response = JSON.parse(response)
if response.code == 200 # if application already exist
  guidjson = JSON.parse(File.read('./applications/fuifll06/guid.json'))
  if guidjson['GUID'] == json_response['GUID']
    blob_json['GUID'] = guidjson['GUID']
    blob_json = blob_json.to_json
    # match_start = Time.now
    match_response = RestClient.post 'http://localhost:9292/match', { data: blob_json }, content_type: 'application/json', accept: :json # second request that sends a list of SHA and gets back known sha by server
    # match_end = Time.now - match_start
    # process_time_start = Time.now
    res = match_response
    guid = res['GUID']
    json['GUID'] = guid
    json = json.to_json
    File.open('./applications/fuifll06/guid.json', 'w') do |f|
      f.puts JSON.pretty_generate(json)
      f.close
    end
    Dir.mkdir('/path/zip')
    json['ApplicationFiles'].each do |hash|
      if res['Known_Hash'].include?hash['Hash']
        # puts "file present"
      else
        json['ApplicationFiles'].each_index do |o|
          next unless hash['Hash'] == json['ApplicationFiles'][o]['Hash']
          filename = json['ApplicationFiles'][o]['FileName']
          path = '/path' + '/' + filename
          guid_path = '/path/guid.json'
          guid_path = Pathname.new(guid_path)
          project_root = Pathname.new(path)
          FileUtils.cp_r guid_path, '/path/zip'
          absolute_path = Pathname.new(File.expand_path(project_root))
          application_root = Pathname.new('/path')
          relative_path = absolute_path.relative_path_from(application_root)
          dir, _file = relative_path.split
          dir = dir.to_s
          path = Pathname.new('/path/zip' + '/' + dir)
          FileUtils.mkdir_p(path) unless File.exist?(path)
          FileUtils.cp_r project_root, path
        end
      end
    end
    compress('/path/zip', '/path/zip.zip')
    File.open('/path/zip.zip')
    # bits_start = Time.now
    # process_time_end = Time.now - process_time_start
    RestClient.post 'http://localhost:9292/bits', myfile: File.open('/path/zip.zip', 'rb') # request sending changed files + files less than 64kb to server
    # bits_end = Time.now - bits_start
    FileUtils.rm('/path/zip.zip')
  end
elsif response.code == 201
  json['GUID'] = json_response['GUID']

  File.open('./applications/fuifll06/guid.json', 'w') do |f|
    f.puts JSON.pretty_generate(json)
    f.close
  end

  response = JSON.parse(response)
  blob_json['GUID'] = response['GUID']
  blob_json = blob_json.to_json
  # puts blob_json
  # match_start = Time.now
  res = RestClient.post 'http://localhost:9292/match', { data: blob_json }, content_type: 'application/json', accept: :json # second request that sends a list of SHA and gets back known sha by server
  # match_end = Time.now - match_start
  # process_time_start = Time.now

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

  Dir.mkdir('/path/zip')
  FileUtils.copy_entry path, '/path/zip'
  guid_path = '/path/guid.json'
  FileUtils.cp_r guid_path, '/path/zip'
  compress('/path/zip', '/path/zip.zip')
  File.open('/path/zip.zip')
  # bits_start = Time.now
  # process_time_end = Time.now - process_time_start
  RestClient.post 'http://localhost:9292/bits', myfile: File.open('/path/zip.zip', 'rb') # request sending changed files + files less than 64kb to server
  # bits_end = Time.now - bits_start
  FileUtils.rm('/path/zip.zip')
end


