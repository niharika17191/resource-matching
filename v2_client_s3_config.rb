require 'sinatra/base'
require 'fileutils'
require 'json'
require 'pathname'
require 'aws-sdk'
require 'aws-sdk-core'
require 'aws-sdk-resources'
require 'zip'
require 'zip/zipfilesystem'
require 'digest'
require 'sequel'

DB = Sequel.sqlite('applications.db') #connection to local cache
begin
  DB.run 'CREATE TABLE application (guid VARCHAR(255) NOT NULL, appName VARCHAR(255) NOT NULL)'
rescue
  puts 'table exists'
end
class ServerDbApp < Sinatra::Base
  def compress(path)
    file = '//path.zip'
    path = Pathname.new(path)
    Zip::File.open(file, Zip::File::CREATE) do |zipfile|
      Dir.chdir path
      Dir.glob('**/*').reject { |fn| File.directory?(fn) }.each do |file|
        next if file == '//path/guid.json'
        puts "Adding #{file}"
        path = path.to_s
        zipfile.add(file.sub(path + '/', ''), file)
      end
    end
  end

  dataset = DB.from(:application)
  begin
    guid = dataset.select(:guid).where(appName: 'applicationnnnn').to_a
  rescue
    puts 'create new'
  end
  creds = JSON.parse(File.read('secrets.json'))  #connection to remote cache
  s3 = Aws::S3::Resource.new(region: 'us-west-2',
                             endpoint: 'https://s3-api.us-geo.objectstorage.softlayer.net',
                             credentials: Aws::Credentials.new(creds['AccessKeyId'], creds['SecretAccessKey']),
                             http_wire_trace: true)
  s3_client = Aws::S3::Client.new(region: 'us-west-2',
                                  endpoint: 'https://s3-api.us-geo.objectstorage.softlayer.net',
                                  credentials: Aws::Credentials.new(creds['AccessKeyId'], creds['SecretAccessKey']),
                                  http_wire_trace: true)

  post '/apps/?' do
    jdata = JSON.parse(params[:data])
    application_name = jdata['Name']
    begin
      guid = dataset.select(:guid).where(appName: application_name).to_a
      guid1 = guid[0][:guid].to_s
      if guid.any?
        data = { 'GUID' => guid1 }.to_json
        status 200
        return data
      end
    rescue
      puts 'created new entry'
    end
    s3.create_bucket(bucket: 'fuifll06', # required
                     create_bucket_configuration: {
                       location_constraint: 'us-standard'
                     })
    json_data = { 'Name' => application_name, 'GUID' => 'fuifll06' }.to_json
    dataset.insert(guid: 'fuifll06', appName: application_name)
    status 201
    return json_data
  end # apps end

  post '/match' do
    jdata = JSON.parse(params[:data])
    unknown_hash = []
    known_hash = []
    bucket = jdata['GUID']
    jdata['Blob_array'].each do |key|
      begin
          response = s3_client.head_object(bucket: bucket,
                                           key: key)
          known_hash << key
        rescue Aws::S3::Errors::NotFound => e
          unknown_hash << key
        end
    end
    jdata = { 'GUID' => jdata['GUID'], 'Known_Hash' => known_hash }.to_json
    return jdata
  end # match end

  post '/bits' do
    filename = params['myfile'][:filename]
    file_name = params['myfile'][:tempfile]
    File.open("./server_applications/#{file_name}", 'wb') do |f|
      f.path
      f.write(file_name.read)
      f.close
    end
    path = Pathname.new('//path')

    Zip::ZipFile.open("./server_applications/#{file_name}") do |zipfile|
      guid_json = JSON.parse(zipfile.file.read('guid.json'))
      guid = guid_json['GUID']
      zipfile.each do |zf|
        file_content = zf.get_input_stream.read
        if zf.size > 64 * 1024
          hash_content = Digest::SHA1.hexdigest file_content
          s3_client.put_object(bucket: 'fuifll06', key: hash_content, body: file_content)
          f_path = File.join(path, zf.name)
          dirname = File.dirname(f_path)
          FileUtils.mkdir_p(dirname) unless File.directory?(dirname)
          File.open(f_path, 'w') { |f| f.write(file_content) }
          zipfile.remove(zf)
        else
          f_path = File.join(path, zf.name)
          dirname = File.dirname(f_path)
          FileUtils.mkdir_p(dirname) unless File.directory?(dirname)
          File.open(f_path, 'w') { |f| f.write(file_content) }

        end
      end
    end

    guid_json['ApplicationFiles'].each do |file|
      if File.exist?("//path/#{file['FileName']}")
        puts 'NO GET'
      else
        begin
          s3_client.get_object(
            response_target: "//path/#{file['FileName']}",
            bucket: 'fuifll06',
            key: file['Hash']
          )
        rescue Aws::S3::Errors::NoSuchKey => error
          puts error
        end
      end
    end

    compress('//path')
    s3_client.put_object(bucket: 'fuifll06', key: 'apps.zip', body: File.open('//path.zip'))
    FileUtils.rm('//path.zip')
  end # bits end
end # class end


