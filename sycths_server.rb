
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
require 'find'

DB = Sequel.sqlite('sycthss_applications.db')
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
  #puts application_data.select(:guid).where(:guid => '45sasa653276hjdshf') .to_a


  creds = JSON.load(File.read('secrets.json'))
  # x= Aws.config.update({
  #   #region: 'us-west-2',
  #   region: 'eu-central-1',
  #   credentials: Aws::Credentials.new(creds['AccessKeyId'], creds['SecretAccessKey']),
  #   http_wire_trace: true
  #   })
  #   s3= Aws::S3::Resource.new
  #   s3_client= Aws::S3::Client.new
  #   resp = s3.buckets

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

   resp = s3.buckets
   puts resp.to_a


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
        bucket: "45sasa653276hjdshf", # required
        create_bucket_configuration: {
          location_constraint: "us-standard"
        }
        })
        json_data= {"Name"=> application_name, "GUID"=> "45sasa653276hjdshf"}.to_json
        dataset.insert(:guid => '45sasa653276hjdshf', :appName => application_name)
        status 201
        return json_data
      end                                     #apps end

      #DB[:movies].import([:id, :director, :title, :year], [[1, "Orson Welles", "Citizen Kane", 1941],[2, "Robert Wiene", "Cabinet of Dr. Caligari, The", 1920]])


      post '/match' do

        match_time = Time.now
        jdata = JSON.parse(params[:data])
        #puts jdata
        unknown_hash_data = Array.new
        unknown_hash_values = Array.new
        unknown_hash = Array.new
        known_hash = Array.new
        bucket = jdata['GUID']
        if (application_data.where(:guid => jdata['GUID']).count) == 0
          puts "hello"
          jdata['Blob_array'].each do |hash|
            unknown_hash << hash['Hash']
            unknown_hash_values = Array.new
            unknown_hash_values.push(jdata['GUID'])
            unknown_hash_values.push(hash['Hash'])
            unknown_hash_values.push(hash['FileSize'])
            unknown_hash_values.push(hash['access_time'])
            unknown_hash_values.push(hash['hit_count'])
            unknown_hash_data.push(unknown_hash_values)
          #  DB[:sycths_application_data].insert(jdata['GUID'],hash['Hash'],hash['FileSize'],hash['access_time'],hash['hit_count'] )
          end
          puts "LLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLL"
          puts unknown_hash_values[0][0]
          puts "LLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLLL"
          puts unknown_hash_values[1][0]
          DB[:sycths_application_data].import([:guid, :hash, :file_size, :access_time, :hit_count],unknown_hash_data)
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
        # puts "sssssssssssssss"
        # puts unknown_hash
        return_data= {"GUID" => jdata['GUID'], "Unknown_Hash"=>unknown_hash}.to_json
        $match_time_end = Time.now - match_time
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
          bucket: '45sasa653276hjdshf',
          key: 'zip.zip')
        rescue Aws::S3::Errors::NoSuchKey => $error
          puts $error
        end
        #file = Pathname.new("/home/niharika/Desktop/server_applications"+file_path)
        if $error
          s3_client.put_object(bucket: "45sasa653276hjdshf", key: filename, body: File.open("/home/niharika/Desktop/ClientServer/server_applications/#{file}"))
        else
          puts "ssssssssssssssssssssssssssssssssssssssssss"
          assemble_start = Time.now
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
          s3_start = Time.now
          s3_client.put_object(bucket: $guid, key: filename, body: File.open("/home/niharika/Desktop/ClientServer/server_applications/zip.zip"))
        end

        # assemble = Time.now - assemble_start


              puts "assemble"
              puts assemble
              puts "assemble"
              puts "match_time_end"
              puts $match_time_end
              s3_end = Time.now - s3_start
              puts "s3_end"
              puts s3_end
              puts "s3_end"

      end


    end                          #class end

