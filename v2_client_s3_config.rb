require 'sinatra/base'
require 'fileutils'
require 'rubygems'
require 'json'
require 'pathname'
require 'aws-sdk'
require 'aws-sdk-core'
require 'aws-sdk-resources'
# require 'aws/s3'
require 'zip'
require 'zip/zipfilesystem'
require 'digest'
require 'sequel'


DB = Sequel.sqlite('applications.db')
begin
  DB.run "CREATE TABLE application (guid VARCHAR(255) NOT NULL, appName VARCHAR(255) NOT NULL)"
rescue
  puts  "table exists"
end
class ServerDbApp < Sinatra::Base


  def compress(path)

    file = "/home/niharika/Desktop/ClientServer/server_applications/apps.zip"
    #  FileUtils.rm file,:force => true
      puts "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD"
      puts path.class
      puts "SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS"
      path = Pathname.new(path)
    Zip::File.open(file, Zip::File::CREATE) do |zipfile|
      Dir.chdir path
      Dir.glob("**/*").reject {|fn| File.directory?(fn) }.each do |file|
        next if file == '/home/niharika/Desktop/ClientServer/server_applications/apps/guid.json'
        puts "Adding #{file}"
        path=path.to_s
        zipfile.add(file.sub(path + '/', ''), file)
      end
    end
  end

  dataset = DB.from(:application)
  puts "DDDDDDDDDDDDD"
  #puts dataset
  begin
    guid =dataset.select(:guid).where(:appName => 'applicationnnnn').to_a
  rescue
    puts "create new"
  end
  creds = JSON.load(File.read('secrets.json'))
  # x= Aws.config.update({
  #   region: 'us-west-2',
  #   #region: 'eu-central-1',
  #   #endpoint: 'https://s3-api.us-geo.objectstorage.softlayer.net'
  #   credentials: Aws::Credentials.new(creds['AccessKeyId'], creds['SecretAccessKey']),
  #   http_wire_trace: true
  #   })
  # s3 = new AWS.S3({
  #   region: 'us-west-2',
  #  endpoint: 'https://s3-api.us-geo.objectstorage.softlayer.net',
  #  credentials: Aws::Credentials.new(creds['AccessKeyId'], creds['SecretAccessKey']),
  #  http_wire_trace: true
  #  })
    s3= Aws::S3::Resource.new({
      region: 'us-west-2',
     endpoint: 'https://s3-api.us-geo.objectstorage.softlayer.net',
     credentials: Aws::Credentials.new(creds['AccessKeyId'], creds['SecretAccessKey']),
     http_wire_trace: true
     })
    s3_client= Aws::S3::Client.new({
      region: 'us-west-2',
     endpoint: 'https://s3-api.us-geo.objectstorage.softlayer.net',
     credentials: Aws::Credentials.new(creds['AccessKeyId'], creds['SecretAccessKey']),
     http_wire_trace: true
     })
  # Aws.config.update({
  #   #region: 'us-west-2',
  #   region: 'eu-central-1',
  #   #endpoint: 'https://s3-api.us-geo.objectstorage.softlayer.net'
  #   credentials: Aws::Credentials.new(creds['AccessKeyId'], creds['SecretAccessKey']),
  #   http_wire_trace: true
  #   })
  #   s3= Aws::S3::Resource.new
  #   s3_client= Aws::S3::Client.new
    resp = s3.buckets
    puts resp.to_a


    post '/apps/?' do

      jdata = JSON.parse(params[:data])
      application_name = jdata['Name']
      puts application_name
      begin
        guid =dataset.select(:guid).where(:appName => application_name).to_a
        puts guid
        guid1= guid[0][:guid].to_s
        puts guid1
        if guid.any?
          data = {"GUID" => guid1}.to_json
          status 200
          return data
        end
      rescue
        puts "created new entry"
      end
      s3.create_bucket({
        bucket: "45653276hjdshf", # required
        create_bucket_configuration: {
          location_constraint: 'us-standard'
        }
        })
        json_data= {"Name"=> application_name, "GUID"=> "45653276hjdshf"}.to_json
        dataset.insert(:guid => '45653276hjdshf', :appName => application_name)
        status 201
        return json_data
      end                                     #apps end


      post '/match' do

        jdata = JSON.parse(params[:data])
        puts jdata
        unknown_hash = Array.new
        known_hash = Array.new
        bucket = jdata['GUID']
        jdata['Blob_array'].each do |key|
          begin
            response = s3_client.head_object({
              bucket: bucket, # required
              key: key, # required
              })
              known_hash << key
              #if response.conte
            rescue Aws::S3::Errors::NotFound => e
              unknown_hash << key
            end
            # puts "unknown_hash"
            # puts unknown_hash
            # puts "unknown_hash"
          end
          puts "known_hash"
          # puts known_hash
          puts "known_hash"
          jdata = {"GUID"=> jdata['GUID'], "Known_Hash" => known_hash}.to_json
          puts "match time"
          puts Time.now
        end



        post '/bits' do


          filename = params['myfile'][:filename]
          #puts filename.class
          file_name = params['myfile'][:tempfile]
          #  puts file
          #puts "file"
          filename = params['myfile'][:filename]
          #puts filename
          File.open("./server_applications/#{file_name}", 'wb') do |f|
            f.path
            f.write(file_name.read)
            f.close
          end
            path = Pathname.new("/home/niharika/Desktop/ClientServer/server_applications/apps")

          Zip::ZipFile.open("./server_applications/#{file_name}") { |zipfile|

            guid_json = JSON.parse(zipfile.file.read("guid.json"))
            $guid_json = JSON.parse(guid_json)
            guid = $guid_json['GUID']
            zipfile.each do |zf|
              if zf.size > 64
              file_content= zf.get_input_stream.read
              hash_content= Digest::SHA1.hexdigest file_content
              s3_client.put_object(bucket: '45653276hjdshf', key: hash_content, body: file_content)
              f_path=File.join(path, zf.name)
              zipfile.extract(zf,f_path)
              zipfile.remove(zf)
            else
              f_path=File.join(path, zf.name)
              zipfile.extract(zf,f_path)

              end
            end

          }

            $guid_json["ApplicationFiles"].each do |file|
              if File.exists?("/home/niharika/Desktop/ClientServer/server_applications/apps/#{file["FileName"]}")
                puts "NO GET"
              else
              begin
                s3_client.get_object(
                response_target: "/home/niharika/Desktop/ClientServer/server_applications/apps/#{file["FileName"]}",
                bucket: '45653276hjdshf',
                key: file["Hash"])
              rescue Aws::S3::Errors::NoSuchKey => error
                puts error
              end
            end
            end

          compress("/home/niharika/Desktop/ClientServer/server_applications/apps")
          s3_client.put_object(bucket: '45653276hjdshf', key: 'apps.zip', body: File.open('/home/niharika/Desktop/ClientServer/server_applications/apps.zip'))
          FileUtils.rm("/home/niharika/Desktop/ClientServer/server_applications/apps.zip")
        end



      end                          #class end                   #class end

