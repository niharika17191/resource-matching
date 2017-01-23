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
  puts application_data.select(:guid).where(:guid => '12345hgs12356') .to_a

  # begin
  # guid =dataset.select(:hash).to_a
  # puts guid
  # rescue
  # puts "create new"
  # end
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
  #   puts "hhhhhhhhhhhhhhhhhhhh"
  #   begin
  #   response = s3_client.head_object({
  #     bucket: "12345hgs12356", # required
  #     key: "7e6e288f6bcae507e9cd8a5da22775d0ff67e12ab", # required
  #     })
  # rescue
  #   puts "helllllllllllloooooo"
  # end
  #   #puts s.bucket
  #   puts "WWWWWWWWWWWWWWWWWWW"
  #    # bucket = s3.buckets['resource-match']
  #   # obj = bucket.objects['client.rb']
  #   # puts obj
  #
  #   # s3.buckets.each do |bucket|
  #   #   #puts bucket.tagging.tag_set
  #   #   if bucket.object('client.rb')
  #   #     puts bucket.name
  #   #   end
  #   # end
  #   #
  #   # s3.buckets.objects.each do |obj|
  #   #   puts obj.key
  #   # end
  #

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
        puts filename.class
        file = params['myfile'][:tempfile]
        puts file.path
        filename = params['myfile'][:filename]
        puts filename
        File.open("./server_applications/#{file}", 'wb') do |f|
          f.write(file.read)
          f.close
        end
        Zip::ZipFile.open("./server_applications/#{file}") { |zipfile|
          guid_json = JSON.parse(zipfile.file.read("guid.json"))
          guid = guid_json['GUID']
          #puts guid
          path = "/home/niharika/Desktop/ClientServer/server_applications" + "/" + guid
          #@application_path = Pathname.new(path)
          #puts path

          zipfile.each do |f|
            #puts f

            f1= f.to_s
            p1 = Pathname.new(f1)

            directory, base = p1.split
            # puts directory
            #puts base.class
            directory_s=directory.to_s
            base_s=base.to_s
            if directory_s== "."        #if it is file directly in root folder
              puts "directory ."
              file_content= zipfile.file.read(base_s)
              puts file_content
              hash_content= Digest::SHA1.hexdigest file_content
              puts hash_content
              puts guid
              s3_client.put_object(bucket: guid, key: hash_content, body: file_content)
              #zipfile.rename(base_s, hash_content)
            else                        #if its a directory
              pn=p1.to_s
              file_content = zipfile.file.read(pn)
              hash_content= Digest::SHA1.hexdigest file_content
              new_path = File.join(directory_s,hash_content)
              puts guid
              s3_client.put_object(bucket: guid, key: new_path, body: file_content)
              #zipfile.rename(p1, new_path)
              #end
            end
          end
        }
      #  %x( unzip "/home/niharika/Desktop/ClientServer/server_applications/#{file}" -d #{@application_path})
      end


    end                          #class end
