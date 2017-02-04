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

begin
  DB.run "CREATE TABLE marcs_application_data (guid VARCHAR(255) NOT NULL, hash VARCHAR(255))"
   rescue
puts "hash exists"
end
class ServerDbApp < Sinatra::Base


  dataset = DB.from(:marcs_application)
  # puts dataset
  application_data = DB.from(:marcs_application_data)
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

      def first_insert(jdata,hash)
        jdata[hash].each do |sec_hash|
          if jdata.keys.include?sec_hash
            DB[:marcs_application_data].insert(jdata['GUID'],sec_hash)
            first_insert(jdata, sec_hash)
          else
            DB[:marcs_application_data].insert(jdata['GUID'],sec_hash)
            $file_stack << sec_hash
            puts "§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§§"
            puts hash
          end
        end
      end

      def change_insert(jdata,hash)
        jdata[hash].each do |sec_hash|
          guid_match = DB[:marcs_application_data].where(:guid => jdata['GUID'])
          hash_match = guid_match.where(:hash => sec_hash).count
          if hash_match == 0
              if jdata.keys.include?sec_hash
            DB[:marcs_application_data].insert(jdata['GUID'],sec_hash)
          change_insert(jdata, sec_hash)
          else
            $file_stack << sec_hash
            DB[:marcs_application_data].insert(jdata['GUID'],sec_hash)
          end
          end
        end
      end

$file_stack = []
      post '/match' do

        jdata = JSON.parse(params[:data])
          return_data=Hash.new
          unknown_hash = Array.new
          bucket = jdata['GUID']
          if (application_data.where(:guid => jdata['GUID']).count) == 0
            DB[:marcs_application_data].insert(jdata['GUID'],jdata["start"])
            jdata[jdata["start"]].each do |hash|
              if jdata.keys.include?hash
                  DB[:marcs_application_data].insert(jdata['GUID'],hash)
                first_insert(jdata, hash)
              else
                  DB[:marcs_application_data].insert(jdata['GUID'],hash)
                $file_stack << hash
                puts "SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS"
                puts hash
              end
          end
          return_data["GUID"]=jdata['GUID']
          #puts $file_stack
          return_data["unknown_hash"]=$file_stack
          return_data = return_data.to_json
          return return_data

        else
          puts "already exist"
          jdata[jdata["start"]].each do |hash|
         guid_match = application_data.where(:guid => jdata['GUID'])
         hash_match = guid_match.where(:hash => hash).count
         puts hash_match
         if hash_match == 0
             if jdata.keys.include?hash
           DB[:marcs_application_data].insert(jdata['GUID'],hash)
          change_insert(jdata, hash)
         else
           $file_stack << hash
           DB[:marcs_application_data].insert(jdata['GUID'],hash)
         end
         end
       end
     end
        puts $file_stack
        return_data= {"GUID" => jdata['GUID'], "unknown_hash"=>$file_stack}.to_json
        return return_data
        end
    #
    #   # #
    #   # #
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
             Zip::ZipFile.open("./server_applications/zip.zip") { |serverfile|

              # Zip::File.open("./server_applications/#{file}", false) do |input|
              #   Zip::File.open("./server_applications/zip.zip", true) do |output|
              #     input.glob('my_folder_name/*') do |entry|
              #       entry.get_input_stream do |input_entry_stream|
              #         output.get_output_stream(entry.name) do |output_entry_stream|
              #           # you could also chunk this, rather than reading it all at once.
              #           output_entry_stream.write(input_entry_stream.read)
              #         end
              #       end
              #     end
              #   end
              # end


              clientfile.each do |cf|
                begin
                puts cf
                content =  cf.get_input_stream.read
                puts content
                serverfile.add(cf,serverfile)
              #  f_path= File.join(Pathname.new(serverfile.to_s), Pathname.new(cf.to_s))

              #  puts f_path

             rescue Zip::EntryExistsError => e
               puts e
              serverfile.remove(cf)
              content =  cf.get_input_stream.read
              puts content
              cf.get_input_stream do |input_entry_stream|
                serverfile.get_output_stream(cf.name) do |output_entry_stream|
                  output_entry_stream.write(input_entry_stream.read)
                    end
                  end
               #puts serverfile.extract(cf, f_path) { true }
             end
              end
            }
        }
        end

        s3_client.put_object(bucket: "12345hgs12356", key: filename, body: File.open("/home/niharika/Desktop/ClientServer/server_applications/zip.zip"))
      else
      end


    end                          #class end
