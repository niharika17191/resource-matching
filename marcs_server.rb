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

DB = Sequel.sqlite('marcs_applications.db')
begin
  DB.run "CREATE TABLE marcs_application (guid VARCHAR(255) NOT NULL, appName VARCHAR(255) NOT NULL)"
rescue
  puts  "table exists"
end
class ServerDbApp < Sinatra::Base


  dataset = DB.from(:marcs_application)
  creds = JSON.load(File.read('secrets.json'))
  # x= Aws.config.update({
  #   #region: 'us-west-2',
  #   region: 'eu-central-1',
  #   credentials: Aws::Credentials.new(creds['AccessKeyId'], creds['SecretAccessKey']),
  #   http_wire_trace: true
  #   })
  #   s3= Aws::S3::Resource.new
  #   s3_client= Aws::S3::Client.new

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


    post '/apps' do

      jdata = JSON.parse(params[:data])
    #  puts jdata
      application_name = jdata['Name']
      #puts application_name
      begin
        guid =dataset.select(:guid).where(:appName => application_name).to_a
        #puts guid
        guid1= guid[0][:guid].to_s
        #puts guid1
        if guid.any?
          data = {"GUID" => guid1}.to_json
          status 200
          return data
        end
      rescue
        #puts "created new entry"
      end
      s3.create_bucket({
        bucket: "45sasa653276gdsffdd", # required
        create_bucket_configuration: {
          location_constraint: "us-standard"
        }
        })
        json_data= {"Name"=> application_name, "GUID"=> "45sasa653276gdsffdd"}.to_json
        dataset.insert(:guid => '45sasa653276gdsffdd', :appName => application_name)

        status 201
        return json_data
      end                                     #apps end
      def first_insert(hash)
        $guidjson[hash].each do |sec_hash|
          if $guidjson.keys.include?sec_hash
            first_insert(sec_hash)
          else
            $file_stack << sec_hash
          end
        end
      end

      def change_insert(guidkey)
        $guidjson[guidkey].each do |sec_hash|
          if $serverjson.keys.include?sec_hash
            puts "present" +sec_hash
          elsif $serverjson.keys.empty?
            return $file_stack
          else
            if $guidjson.keys.include?sec_hash
              puts "does not exist" +sec_hash
              change_insert(sec_hash)
              return $file_stack
            else
              $file_stack << sec_hash
              puts sec_hash
              puts "file does not exist" +sec_hash

            end
            next
          end

        end
      end


      $file_stack = []
      post '/match' do

        return_data=Hash.new
        file = params['myfile'][:tempfile]
        File.open("./server_applications/#{file}", 'wb') do |f|
          #f.path
          f.write(file.read)
          f.close
        end
        $guidjson = JSON.parse(File.read("./server_applications/#{file}"))
       #$guidjson = params[:data]
        #puts $guidjson
        guid_download_time = Time.now
        begin
          resp = s3_client.get_object(
          response_target: '/home/niharika/Desktop/ClientServer/server_applications/guidserver.json',
          bucket: '45sasa653276gdsffdd',
          key: 'guid.json')
          $guid_download_time = Time.now - guid_download_time
          puts "guid_download_time"
          puts $guid_download_time
        rescue Aws::S3::Errors::NoSuchKey => e
          begin
          $guidjson[$guidjson["start"]].each do |hash|
            if $guidjson.keys.include?hash
              first_insert(hash)
            else
              $file_stack << hash
            end
          end
          rescue
            puts "error"
          end
          return_data["GUID"]=$guidjson['GUID']
          return_data["unknown_hash"]=$file_stack
          return_data=return_data.to_json
          status 201
          return return_data
        end
        match_time = Time.now
        $serverjson = JSON.parse(File.read("./server_applications/guidserver.json"))
        puts $serverjson.keys
        puts $serverjson.keys.class
        if $serverjson["start"]==$guidjson["start"]
          puts "no change"
        else
        $guidjson[$guidjson["start"]].each do |guidkey|
              if   $serverjson[$serverjson["start"]].include?guidkey
                puts "present" +guidkey
              else
                if $guidjson.keys.include?guidkey
                  puts "does not exist" +guidkey
                  change_insert(guidkey)
              else
                puts "file does not exist" +guidkey
                 $file_stack << guidkey
                 puts guidkey
               end

          end
        end
        $match_time_end = Time.now - match_time

        return_data["GUID"]=$guidjson['GUID']
        return_data["unknown_hash"]=$file_stack
        return_data= return_data.to_json
        puts return_data
        return return_data
        end
        end


      post '/bits' do

        bits_time = Time.now
        filename = params['myfile'][:filename]
        #puts filename.class
        file = params['myfile'][:tempfile]
        #  puts file
        #puts "file"
        filename = params['myfile'][:filename]
        #puts filename
        client_download_time = Time.now
        File.open("./server_applications/#{file}", 'wb') do |f|
          #f.path
          f.write(file.read)
          f.close
        end
        client_download_time = Time.now - client_download_time

        begin
          resp = s3_client.get_object(
          response_target: '/home/niharika/Desktop/ClientServer/server_applications/zip.zip',
          bucket: '45sasa653276gdsffdd',
          key: 'zip.zip')
        rescue Aws::S3::Errors::NoSuchKey => $error
          puts $error
        end
        #file = Pathname.new("/home/niharika/Desktop/server_applications"+file_path)
        if $error
          Zip::ZipFile.open("./server_applications/#{file}") { |clientfile|
            puts clientfile
            guid_json = JSON.parse(clientfile.file.read("guid.json"))
            $guid = guid_json['GUID']
            s3_client.put_object(bucket: $guid, key: "guid.json", body: clientfile.file.read("guid.json"))
            puts $guid
          }
          s3_put = Time.now
          s3_client.put_object(bucket: "45sasa653276gdsffdd", key: filename, body: File.open("/home/niharika/Desktop/ClientServer/server_applications/#{file}"))
          s3_comp = Time.now - s3_put
        else
          assemble_package = Time.now
          puts "ssssssssssssssssssssssssssssssssssssssssss"
          Zip::ZipFile.open("./server_applications/#{file}") { |clientfile|
            puts clientfile
            guid_json = JSON.parse(clientfile.file.read("guid.json"))
            $guid = guid_json['GUID']
            s3_client.put_object(bucket: $guid, key: "guid.json", body: clientfile.file.read("guid.json"))
            puts $guid
            Zip::ZipFile.open("./server_applications/zip.zip") { |serverfile|
              clientfile.each do |cf|
                begin
                  serverfile.add(cf,serverfile)
                rescue Zip::EntryExistsError => e
                  #puts e
                  serverfile.remove(cf)
                  puts  "removed file "
                  puts cf
                  puts  "removed file "
                  cf.get_input_stream do |input_entry_stream|
                    serverfile.get_output_stream(cf.name) do |output_entry_stream|
                      output_entry_stream.write(input_entry_stream.read)
                    end
                  end
                end
              end
            }
          }
          s3_put = Time.now
          s3_client.put_object(bucket: $guid, key: filename, body: File.open("/home/niharika/Desktop/ClientServer/server_applications/zip.zip"))
          s3_comp = Time.now - s3_put
        end
        assemble_package_time = Time.now - assemble_package
        puts "assemble_package"
        puts assemble_package_time
        puts "s3_comp"
        puts s3_comp
        puts "client_download_time"
        puts client_download_time
        puts "match_time"
        puts $match_time_end
        bits_time_end = Time.now - bits_time
        puts bits_time_end
        puts "guid_download_time"
        puts $guid_download_time
      end
    end                          #class end
