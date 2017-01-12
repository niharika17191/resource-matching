require 'sinatra/base'
require 'aws-sdk'
require 'aws/s3'
require 'fileutils'
require 'rubygems'
require 'json'
require 'pathname'
require 'zip'
require 'zip/zipfilesystem'
require 'digest'



class DebugApp < Sinatra::Base

  # creds = JSON.load(File.read('secrets.json'))
  # x= Aws.config.update({
  #   region: 'us-west-2',
  #   credentials: Aws::Credentials.new(creds['AccessKeyId'], creds['SecretAccessKey'])
  #   })
  #   s3= Aws::S3::Resource.new
  #   s3_client= Aws::S3::Client.new
  #
  #   resp = s3.buckets
  #   puts resp
  #
  #   s3.buckets.each do |bucket|
  #     puts bucket
  # end
    post '/apps/?' do

      jdata = JSON.parse(params[:data])
      application_name = jdata['Name']
      puts application_name
      json = File.read("./server_applications/application.json")
      jsonvar = JSON.parse(json)
      application = jsonvar['application']
      application.each_index do |a|
        puts application[a]['Name']
        if application_name == application[a]['Name']
          data = {"GUID" => application[a]['GUID']}.to_json
          status 200
          return data
        end                                      #if end
      end                                       #each end
      Dir.mkdir('./server_applications/143')
      # s3.create_bucket({
      #   # acl: "private", # accepts private, public-read, public-read-write, authenticated-read
      #   bucket: "125366639", # required
      #   create_bucket_configuration: {
      #     location_constraint: "us-west-2", # accepts EU, eu-west-1, us-west-1, us-west-2, ap-south-1, ap-southeast-1, ap-southeast-2, ap-northeast-1, sa-east-1, cn-north-1, eu-central-1
      #   },
      #   # grant_full_control: "GrantFullControl",
      #   # grant_read: "GrantRead",
      #   # grant_read_acp: "GrantReadACP",
      #   # grant_write: "GrantWrite",
      #   # grant_write_acp: "GrantWriteACP"
      #   })
        json_data= {"Name"=> application_name, "GUID"=> "143"}.to_json
        jsn=JSON.parse(json_data)
        jsonvar['application'].push(jsn)
        File.open('./server_applications/application.json',"w") do |f|
          f.puts JSON.pretty_generate(jsonvar)
          f.close
        end                                       #file end
        status 201
        return json_data

      end                                     #apps end


      post '/match' do

        jdata = JSON.parse(params[:data])
        puts jdata
        return_array=Array.new
        pn= Pathname.new("/home/niharika/Desktop/ClientServer/server_applications")
        Dir['./server_applications/*/'].each do |dir|
          absolute_path = Pathname.new(File.expand_path(dir))
          directory=absolute_path.relative_path_from(pn)
          dirname= directory.to_s
          directory=Pathname(directory+"/"+"*")
          if dirname == jdata['GUID']
            puts "dirpresent"
            if Dir[directory].empty?
              puts "directory is empty ask client to send every thing"
              return "Directory empty"
            else
              puts "MatchFiles"
              app_folder = pn.to_s + "/" + jdata['GUID']
              app_folder = Pathname.new(app_folder)
            #  puts app_folder
              file_array =  Dir[ File.join(app_folder, '**', '*') ].reject { |p| File.directory? p }
              file_array.each do |file|
                absolute_path = Pathname.new(File.expand_path(file))
                #puts absolute_path
                project_root  = Pathname.new(app_folder)
                #puts project_root
                relative_path = absolute_path.relative_path_from(project_root)
                #puts relative_path
                relative_file_path= relative_path.to_s
                puts relative_file_path
                # puts relative_file_path.class
                # puts jdata["Blob_array"]
                # puts relative_file_path
                if jdata["Blob_array"].include?relative_file_path
                  puts true
                  return_array<<relative_file_path
                end
              end
              puts return_array
              return_data= {"GUID" => jdata['GUID'], "Known_Hash"=>return_array}.to_json
              puts return_data
              return return_data
            end
          end

        end

        "Done"
      end


      post '/bits' do


        filename = params['myfile'][:filename]
        puts filename.class
        file = params['myfile'][:tempfile]
        puts file.path
        filename = params['myfile'][:filename]
        puts filename
        # %x( which #{filename} )
        # value = %x( ls)
        #  puts value
        File.open("./server_applications/#{file}", 'wb') do |f|
          f.write(file.read)
          f.close
       end
        # value = %x( unzip "./public/#{filename}" -d "/home/niharika/Desktop/ClientServer/server_applications/143" )
        #  puts value
        # %x( cp(#{tempfile.path}, "/home/niharika/Desktop/ClientServer/server_applications/#{filename}"))
        # 'Yeaaup'
        # value = %x( unzip #{filename} -d "/home/niharika/Desktop/ClientServer/server_applications/143" )
        # puts value


        # Zip::File.open("./server_applications/#{file}") do |zip_file|
        #   # Handle entries one by one
        #   puts zip_file.class
        #   zip_file.each do |entry|
        #     # Extract to file/directory/symlink
        #     puts "Extracting #{entry.name}"
        #
        #     #entry.extract(dest_file)
        #
        #     # Read into memory
        #     #content = entry.get_input_stream.read
        #  end
        #  end


        Zip::ZipFile.open("./server_applications/#{file}") { |zipfile|
          guid_json = JSON.parse(zipfile.file.read("guid.json"))
          guid = guid_json['GUID']
          #puts guid
          path = "/home/niharika/Desktop/ClientServer/server_applications" + "/" + guid
            @application_path = Pathname.new(path)
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
              zipfile.rename(base_s, hash_content)
            else                        #if its a directory
                pn=p1.to_s
                file_content = zipfile.file.read(pn)
                hash_content= Digest::SHA1.hexdigest file_content
                directory, base = p1.split
                puts directory
                puts base_s
                puts Dir.pwd
                new_path = File.join(directory_s,hash_content)
                zipfile.rename(p1, new_path)
              #end
            end
           end
        }
         %x( unzip "/home/niharika/Desktop/ClientServer/server_applications/#{file}" -d #{@application_path})
      end



    end                          #class end


    # require 'sinatra/base'
    # require 'fileutils'
    # require 'rubygems'
    # require 'json'
    # require 'aws/s3'
    # require 'aws-sdk'
    #
    # #get '/' do
    # #	'hello'
    # #end
    #
    # class ServerApp < Sinatra::Base
    #
    #
    #   creds = JSON.load(File.read('secrets.json'))
    #   x= Aws.config.update({
    #   region: 'us-west-2',
    #   credentials: Aws::Credentials.new(creds['AccessKeyId'], creds['SecretAccessKey'])
    #   })
    #   s3= Aws::S3::Resource.new
    #   resp = s3.buckets
    #   puts resp
    #
    #   s3.buckets.each do |bucket|
    #     puts bucket
    #   end
    #  post '/apps/?' do
    #
    #   jdata = JSON.parse(params[:data])
    #   application_name = jdata['Name']
    #   puts application_name
    #   json = File.read("./server_applications/application.json")
    #   jsonvar = JSON.parse(json)
    #   application = jsonvar['application']
    #   application.each_index do |a|
    #    puts application[a]['Name']
    #    if application_name == application[a]['Name']
    #     data = {"GUID" => application[a]['GUID']}.to_json
    #     status 200
    #     return data
    #   end                                      #if end
    #  end                                       #each end
    #     #Dir.mkdir('./server_applications/129')
    #     s3.create_bucket({
    #                       # acl: "private", # accepts private, public-read, public-read-write, authenticated-read
    #                       bucket: "125366639", # required
    #                       create_bucket_configuration: {
    #                       location_constraint: "us-west-2", # accepts EU, eu-west-1, us-west-1, us-west-2, ap-south-1, ap-southeast-1, ap-southeast-2, ap-northeast-1, sa-east-1, cn-north-1, eu-central-1
    #                             },
    #                       # grant_full_control: "GrantFullControl",
    #                       # grant_read: "GrantRead",
    #                       # grant_read_acp: "GrantReadACP",
    #                       # grant_write: "GrantWrite",
    #                       # grant_write_acp: "GrantWriteACP"
    #                       })
    #     json_data= {"Name"=> application_name, "GUID"=> x.name}.to_json
    #     jsn=JSON.parse(json_data)
    #     jsonvar['application'].push(jsn)
    #     File.open('./server_applications/application.json',"w") do |f|
    #     	 f.puts JSON.pretty_generate(jsonvar)
    #     	 f.close
    #     end                                       #file end
    #     status 201
    #     return json_data
    #
    #  end                                     #apps end
    #
    #
    #
    #
    # post '/match' do
    #
    # #puts request.accept
    # #env['CONTENT_TYPE'] = 'application/json'
    # #puts request.content_type
    # puts params[:data]
    #   #  s3.buckets.each do |bucket|
    #   #    if jdata['GUID'] ==  bucket.name
    #   #     puts "helllloooo"
    #   #     guid=jdata['GUID']
    #   #     bucket.objects.each do |o|
    #   #        x=o.exists?
    #   #        if x == true
    #   #
    #   #       end
    #   #     end
    #   #     puts "heeeeeee"
    #   #   end
    #   # end
    #
    #
    #
    #   # x= bucket.objects.with_prefix('videos').collect(&:key)
    #   #puts bucket
    #   # AWS::S3::S3Object.store(
    #   #   filename,
    #   #   open(file.path),
    #   #   bucket,
    #   # )
    #   #   :access => :public_read
    #   # url = "https://#{bucket}.s3.amazonaws.com/#{filename}"
    #   # return url
    #   #
    #   # data= (params[:data])
    #   # client_hash= data['Hashes']
    #
    #
    #
    #  end                                     #match end
    # end                                    #class end

