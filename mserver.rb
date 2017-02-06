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
  x= Aws.config.update({
    #region: 'us-west-2',
    region: 'eu-central-1',
    credentials: Aws::Credentials.new(creds['AccessKeyId'], creds['SecretAccessKey']),
    http_wire_trace: true
    })
    s3= Aws::S3::Resource.new
    s3_client= Aws::S3::Client.new


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
      def first_insert(jdata,hash)
        jdata[hash].each do |sec_hash|
          if jdata.keys.include?sec_hash
            first_insert(jdata, sec_hash)
          else
            $file_stack << sec_hash
          end
        end
      end

      def change_insert(guidjson,guidkey,serverjson)
      guidjson[guidkey].each do |sec_hash|
            if serverjson.keys.include?sec_hash
            puts "present" +sec_hash
          else
            if guidjson.keys.include?sec_hash
              puts "does not exist" +sec_hash
              change_insert(guidjson,guidkey,serverjson)
            else
             $file_stack << sec_hash
             puts $file_stack
             puts "file does not exist" +sec_hash
           end
           end

        end
      end


      $file_stack = []
      post '/match' do

        return_data=Hash.new
        guidjson = params[:data]
        begin
          resp = s3_client.get_object(
          response_target: '/home/niharika/Desktop/ClientServer/server_applications/guidserver.json',
          bucket: '12345hgs12356',
          key: 'guid.json')
        rescue Aws::S3::Errors::NoSuchKey => e
          guidjson[guidjson["start"]].each do |hash|
            if guidjson.keys.include?hash
              first_insert(guidjson, hash)
            else
              $file_stack << hash
            end
          end
          return_data["GUID"]=guidjson['GUID']
          return_data["unknown_hash"]=$file_stack
          return_data=return_data.to_json
          status 201
          return return_data
        end
        serverjson = JSON.parse(File.read("./server_applications/guidserver.json"))
        puts serverjson.keys
        puts serverjson.keys.class
        if serverjson["start"]==guidjson["start"]
          #puts "no change"
        else
        guidjson[guidjson["start"]].each do |guidkey|
              if   serverjson[serverjson["start"]].include?guidkey
                puts "present" +guidkey
              else
                if guidjson.keys.include?guidkey
                  puts "does not exist" +guidkey
                  change_insert(guidjson,guidkey,serverjson)
              else
                puts "file does not exist" +guidkey
                 $file_stack << guidkey
                 puts $file_stack
               end

          end
        end
        return_data["GUID"]=guidjson['GUID']
        return_data["unknown_hash"]=$file_stack
        return_data= return_data.to_json
        return return_data
        end
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
          #f.path
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
          Zip::ZipFile.open("./server_applications/#{file}") { |clientfile|
            puts clientfile
            guid_json = JSON.parse(clientfile.file.read("guid.json"))
            $guid = guid_json['GUID']
            s3_client.put_object(bucket: $guid, key: "guid.json", body: clientfile.file.read("guid.json"))
            puts $guid
          }
          s3_client.put_object(bucket: "12345hgs12356", key: filename, body: File.open("/home/niharika/Desktop/ClientServer/server_applications/#{file}"))
        else
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
