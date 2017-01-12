require 'fileutils'
require 'json'
require 'digest'
require 'rest-client'
require 'pathname'
require 'rubygems'
require 'zip'


def compress(path, file)

  Zip::File.open(file, Zip::File::CREATE) do |zipfile|
      Dir.chdir path
      Dir.glob("**/*").reject {|fn| File.directory?(fn) }.each do |file|
        next if file == '/home/niharika/Desktop/ClientServer/applications/appi/guid.json'
        puts "Adding #{file}"
        path=path.to_s
        zipfile.add(file.sub(path + '/', ''), file)
      end
    end
end


def find_files()				#iteratively finds files in a directory

  hash=Array.new
  file_array =Array.new
  file_array =  Dir[ File.join('./applications/appi/', '**', '*') ].reject { |p| File.directory? p }
  file_array.each do |file|
    absolute_path = Pathname.new(File.expand_path(file))
    project_root  = Pathname.new("/home/niharika/Desktop/ClientServer/applications/appi")
    relative_path = absolute_path.relative_path_from(project_root)
    relative_file_path= relative_path.to_s
    directory,base = relative_path.split
    directory_s=directory.to_s
    base_s=base.to_s
    puts directory
    puts base
    if directory_s== "."        #if it is file directly in root folder
      file_content= File.read(file)
      puts file_content
      hash_content= Digest::SHA1.hexdigest file_content
    else                        #if its a directory
        file_content = File.read(file)
        hash_content= Digest::SHA1.hexdigest file_content
        new_path = File.join(directory_s,hash_content)
        hash_content=new_path
    end

    file_data= JSON.parse({"FileName" => relative_file_path, "Hash"=>hash_content}.to_json)
    hash << file_data
  end
  jdata = {"ApplicationName"=> "appi", "ApplicationFiles" => hash}.to_json
  #puts jdata
  return jdata
end



complete_json = find_files()
puts complete_json
blob_array=Array.new
json=JSON.parse(complete_json)
json["ApplicationFiles"].each_index do |o|
  file = json["ApplicationFiles"][o]["Hash"]
  blob_array << file
end
blob_json= JSON.parse({"Blob_array" => blob_array}.to_json)
puts blob_json

jdata = {"Name" => json["ApplicationName"]}.to_json
begin
  File.new("./applications/appi/guid.json", File::RDWR|File::CREAT|File::EXCL)
rescue
  puts "file exists"
end





response = RestClient.post 'http://localhost:9292/apps', {:data => jdata}, {:content_type => :json, :accept => :json}
json_response=JSON.parse(response)
puts json_response
puts response.code
#puts json_response
if response.code == 200
  guidjson = JSON.parse(File.read("./applications/appi/guid.json"))
  #puts guidjson
  #puts guidjson['GUID']
  #puts json_response['GUID']
  if guidjson['GUID']==json_response['GUID']
    blob_json["GUID"]= guidjson['GUID']
    blob_json = blob_json.to_json
    #puts blob_json
    match_response = RestClient.post 'http://localhost:9292/match', {:data => blob_json}, {:content_type => 'application/json', :accept => :json}
    puts match_response
    res=JSON.parse(match_response)
    guid=res['GUID']
    Dir.mkdir("/home/niharika/Desktop/ClientServer/applications/zip")
    json['ApplicationFiles'].each do |hash|
        if res['Known_Hash'].include?hash['Hash']
          puts "file present"
        else
          json["ApplicationFiles"].each_index do |o|
            if hash['Hash'] == json["ApplicationFiles"][o]["Hash"]
            filename= json["ApplicationFiles"][o]["FileName"]
            path = "/home/niharika/Desktop/ClientServer/applications/appi" +"/"+ filename
            guid_path=  "/home/niharika/Desktop/ClientServer/applications/appi/guid.json"
            guid_path=Pathname.new(guid_path)
            project_root  = Pathname.new(path)
            puts project_root
            FileUtils.cp project_root,"/home/niharika/Desktop/ClientServer/applications/zip"
            FileUtils.cp guid_path,"/home/niharika/Desktop/ClientServer/applications/zip"
            end
          end
          end
        end
        compress("/home/niharika/Desktop/ClientServer/applications/zip","/home/niharika/Desktop/ClientServer/applications/zip.zip")
        app_file = File.open("/home/niharika/Desktop/ClientServer/applications/zip.zip")
        bits=RestClient.post 'http://localhost:9292/bits', :myfile => File.open("/home/niharika/Desktop/ClientServer/applications/zip.zip", 'rb')
        puts bits
        FileUtils.rm("/home/niharika/Desktop/ClientServer/applications/zip.zip")
      end
  elsif response.code == 201

  puts response
  response=JSON.parse(response)
  blob_json["GUID"]= response['GUID']
  blob_json = blob_json.to_json
  File.open('./applications/appi/guid.json',"w") do |f|
    f.puts JSON.pretty_generate(json_response)
    f.close
end
    res = RestClient.post 'http://localhost:9292/match', {:data => blob_json}, {:content_type => 'application/json', :accept => :json}
    res = res.to_s
    puts res
    if res == "Directory empty"
      puts response['Name']
      path = response['Name']
      Dir.chdir("applications")
      path = Dir.pwd + "/" + path
      path=Pathname.new(path)
      puts path.class
      begin
      File.new("./applications/zip.zip",File::RDWR|File::CREAT|File::EXCL)
      rescue
        puts "file exists"
      end
      puts json
      Dir.mkdir("/home/niharika/Desktop/ClientServer/applications/zip")
      FileUtils.copy_entry path, "/home/niharika/Desktop/ClientServer/applications/zip"
      # file_array =  Dir[ File.join("/home/niharika/Desktop/ClientServer/applications/zip", '**', '*') ].reject { |p| File.directory? p }
      # file_array.each do |o|
      #   filename = Pathname.new(o)
      #   path, name = File.split(filename)
      #   new_name = name
      #   file_content = File.read(o)
      #   hash_content= Digest::SHA1.hexdigest file_content
      #   new_path = File.join(path,hash_content)
      #   File.rename(o, new_path)
      # end


       compress("/home/niharika/Desktop/ClientServer/applications/zip","/home/niharika/Desktop/ClientServer/applications/zip.zip")
       app_file = File.open("/home/niharika/Desktop/ClientServer/applications/zip.zip")
       bits=RestClient.post 'http://localhost:9292/bits', :myfile => File.open("/home/niharika/Desktop/ClientServer/applications/zip.zip", 'rb')
       puts bits
       FileUtils.rm("/home/niharika/Desktop/ClientServer/applications/zip.zip")
       #Dir.delete("/home/niharika/Desktop/ClientServer/applications/zip")

      end

    end

