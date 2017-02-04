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

  dataset = DB.from(:application)
  puts "DDDDDDDDDDDDD"
  puts dataset
  begin
  guid =dataset.select(:guid).where(:appName => 'applicationnnnn').to_a
  rescue
  puts "create new"
  end
  creds = JSON.load(File.read('secrets.json'))
  x= Aws.config.update({
    #region: 'us-west-2',
    region: 'eu-central-1',
    credentials: Aws::Credentials.new(creds['AccessKeyId'], creds['SecretAccessKey']),
    http_wire_trace: true
    })
    s3= Aws::S3::Resource.new
    s3_client= Aws::S3::Client.new
    resp = s3.buckets
    #puts resp
    s=Aws::S3::BucketTagging.new(:bucket_name => 'resource-match')

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
          bucket: "12345hgs12356", # required
          create_bucket_configuration: {
            location_constraint: "eu-central-1"
          }
          })
          json_data= {"Name"=> application_name, "GUID"=> "12345hgs12356"}.to_json
           dataset.insert(:guid => '12345hgs12356', :appName => application_name)
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
          puts "unknown_hash"
          puts unknown_hash
          puts "unknown_hash"
        end
        puts "known_hash"
      puts known_hash
      puts "known_hash"
      jdata = {"GUID"=> jdata['GUID'], "Known_Hash" => known_hash}.to_json
      end



      post '/bits' do


        filename = params['myfile'][:filename]
        #puts filename.class
        file = params['myfile'][:tempfile]
      #  puts file
        #puts "file"
        filename = params['myfile'][:filename]
        #puts filename
        File.open("./server_applications/#{file}", 'wb') do |f|
          f.path
          f.write(file.read)
          f.close
        end
        begin
            resp = s3_client.get_object(
                              response_target: '/home/niharika/Desktop/ClientServer/server_applications/zip.zip',
                              bucket: '12345hgs12356',
                              key: 'zip.zip')
        rescue Aws::S3::Errors::NoSuchKey => $error
            puts $error
        end
        #file = Pathname.new("/home/niharika/Desktop/server_applications"+file_path)
        if $error
        s3_client.put_object(bucket: "12345hgs12356", key: filename, body: File.open("/home/niharika/Desktop/ClientServer/server_applications/#{file}"))
      else
        puts "ssssssssssssssssssssssssssssssssssssssssss"
        Zip::ZipFile.open("./server_applications/#{file}") { |clientfile|
          guid_json = JSON.parse(clientfile.file.read("guid.json"))
          guid = guid_json['GUID']
             Zip::ZipFile.open("./server_applications/zip.zip") { |serverfile|
              clientfile.each do |cf|
                begin
                serverfile.add(cf,serverfile)
                file_content= cf.get_input_stream.read
                hash_content= Digest::SHA1.hexdigest file_content
                s3_client.put_object(bucket: guid, key: hash_content, body: file_content)
             rescue Zip::EntryExistsError => e
               puts e
              serverfile.remove(cf)
              file_content= cf.get_input_stream.read
              hash_content= Digest::SHA1.hexdigest file_content
              s3_client.put_object(bucket: guid, key: hash_content, body: file_content)
              cf.get_input_stream do |input_entry_stream|
                serverfile.get_output_stream(cf.name) do |output_entry_stream|
                  output_entry_stream.write(input_entry_stream.read)
                    end
                  end
             end
              end
            }
        }
        end

        s3_client.put_object(bucket: guid, key: filename, body: File.open("/home/niharika/Desktop/ClientServer/server_applications/zip.zip"))
      end



    end                          #class end                   #class end
