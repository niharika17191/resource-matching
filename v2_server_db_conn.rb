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
          known_hash<<key
         #if response.conte
        rescue Aws::S3::Errors::NotFound => e
          unknown_hash<<key
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
