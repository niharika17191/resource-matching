require 'sinatra/base'
require 'fileutils'
require 'rubygems'
require 'json'
require 'pathname'
require 'aws-sdk'
require 'aws-sdk-core'
require 'aws-sdk-resources'
require 'zip'
require 'zip/zipfilesystem'
require 'digest'
require 'sequel'

DB = Sequel.sqlite('sycths_applications.db')
begin
  DB.run "CREATE TABLE sycths_application (guid VARCHAR(255) NOT NULL, appName VARCHAR(255) NOT NULL)"
rescue
  puts  "table exists"
end

begin
  DB.run "CREATE TABLE sycths_application_data (guid VARCHAR(255) NOT NULL, hash VARCHAR(255),file_size INT(50), access_time DATETIME , hit_count INT(20))"
rescue
  puts "hash exists"
end
class ServerDbApp < Sinatra::Base


  dataset = DB.from(:sycths_application)
  # puts dataset
  application_data = DB.from(:sycths_application_data)
  #puts application_data.select(:guid).where(:guid => '12345hgs12356') .to_a


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

    post '/apps/?' do

      jdata = JSON.parse(params[:data])
      puts jdata
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
        if (application_data.where(:guid => jdata['GUID']).count) == 0
          puts "hello"
          jdata['Blob_array'].each do |hash|
            unknown_hash << hash['Hash']
            DB[:sycths_application_data].insert(jdata['GUID'],hash['Hash'],hash['FileSize'],hash['access_time'],hash['hit_count'] )
          end
        else
          jdata['Blob_array'].each do |hash|
            guid_match = application_data.where(:guid => jdata['GUID'])
            hash_match = guid_match.where(:hash => hash['Hash']).count
            if hash_match == 0
              unknown_hash << hash['Hash']
                DB[:sycths_application_data].insert(jdata['GUID'],hash['Hash'],hash['FileSize'],hash['access_time'],hash['hit_count'] )
            end
          end
        end
        puts "sssssssssssssss"
        puts unknown_hash
        return_data= {"GUID" => jdata['GUID'], "Unknown_Hash"=>unknown_hash}.to_json
        puts return_data
        return return_data
      end

      # #
      # #
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
            $guid = guid_json['GUID']
            puts $guid
            Zip::ZipFile.open("./server_applications/zip.zip") { |serverfile|
              clientfile.each do |cf|
                begin
                  serverfile.add(cf,serverfile)
                rescue Zip::EntryExistsError => e
                  puts e
                  serverfile.remove(cf)
                  cf.get_input_stream do |input_entry_stream|
                    serverfile.get_output_stream(cf.name) do |output_entry_stream|
                      output_entry_stream.write(input_entry_stream.read)
                    end
                  end
                end
              end
            }
          }
          s3_client.put_object(bucket: $guid, key: filename, body: File.open("/home/niharika/Desktop/ClientServer/server_applications/zip.zip"))
        end
        
      end


    end                          #class end
