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
      next if file == '/home/niharika/Desktop/ClientServer/applications/12345hgs12356/guid.json'
      puts "Adding #{file}"
      path=path.to_s
      zipfile.add(file.sub(path + '/', ''), file)
    end
  end
end


def find_files()				#iteratively finds files in a directory

  hash=Array.new
  file_array =Array.new
  file_array =  Dir[ File.join('./applications/12345hgs12356/', '**', '*') ].reject { |p| File.directory? p }
  file_array.each do |file|
    absolute_path = Pathname.new(File.expand_path(file))
    project_root  = Pathname.new("/home/niharika/Desktop/ClientServer/applications/12345hgs12356")
    relative_path = absolute_path.relative_path_from(project_root)
    relative_file_path= relative_path.to_s
    directory,base = relative_path.split
    directory_s=directory.to_s
    base_s=base.to_s
    #puts directory
    #puts base
    if directory_s== "."        #if it is file directly in root folder
      file_content= File.read(file)
      #puts file_content
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
  jdata = {"ApplicationName"=> "12345hgs12356", "ApplicationFiles" => hash}.to_json
  #puts jdata
  return jdata
end



#
#

#{"ApplicationName":"12345hgs12356","ApplicationFiles":[{"FileName":"js/file.js","Hash":"js/a00603a5a4df7602c56ca18f4560fc114634ccd3"},{"FileName":"guid.json","Hash":"182cd0a588f4d106cfa99de7622fc7122e2d3d65"},{"FileName":"test.html","Hash":"7e6e288f6bcae507e9cd8a5da22775d0ff67e12a"}]}

 complete_json = find_files()
 #puts complete_json
blob_array=Array.new {Hash.new}
json=JSON.parse(complete_json)

json["ApplicationFiles"].each_index do |o|
  filename = Pathname.new("/home/niharika/Desktop/ClientServer/applications/12345hgs12356" + "/" + json["ApplicationFiles"][o]["FileName"] )
  size = File.size(filename)
  hash = json["ApplicationFiles"][o]["Hash"]
  access_time = File.atime(filename)
  hit_count = 0
  file_data= JSON.parse({"Hash"=>hash, "FileSize" => size, "access_time" => access_time, "hit_count" => hit_count }.to_json)
  blob_array << file_data
end
blob_json= JSON.parse({"Blob_array" => blob_array}.to_json)
#puts blob_json

jdata = {"Name" => json["ApplicationName"]}.to_json
begin
  File.new("./applications/12345hgs12356/guid.json", File::RDWR|File::CREAT|File::EXCL)
rescue
  #puts "file exists"
end





response = RestClient.post 'http://localhost:9292/apps', {:data => jdata}, {:content_type => :json, :accept => :json}
json_response=JSON.parse(response)
# puts json_response
# puts response.code
#puts json_response
if response.code == 200
  guidjson = JSON.parse(File.read("./applications/12345hgs12356/guid.json"))
  # puts guidjson
  # puts guidjson['GUID']
  # puts json_response['GUID']
  if guidjson['GUID']==json_response['GUID']
    blob_json["GUID"]= guidjson['GUID']
    blob_json = blob_json.to_json
    # puts blob_json
    match_response = RestClient.post 'http://localhost:9292/match', {:data => blob_json}, {:content_type => 'application/json', :accept => :json}
    #puts match_response
  end


     res=JSON.parse(match_response)
    guid=res['GUID']
    Dir.mkdir("/home/niharika/Desktop/ClientServer/applications/zip")
    json['ApplicationFiles'].each do |hash|
          if res['Unknown_Hash'].include? hash['Hash']
            filename= hash["FileName"]
            puts filename
            path = "/home/niharika/Desktop/ClientServer/applications/12345hgs12356" +"/"+ filename
            guid_path=  "/home/niharika/Desktop/ClientServer/applications/12345hgs12356/guid.json"
            guid_path=Pathname.new(guid_path)
            project_root  = Pathname.new(path)
            puts project_root
            FileUtils.cp_r guid_path,"/home/niharika/Desktop/ClientServer/applications/zip"
            absolute_path = Pathname.new(File.expand_path(project_root))
            application_root  = Pathname.new("/home/niharika/Desktop/ClientServer/applications/12345hgs12356")
            relative_path = absolute_path.relative_path_from(application_root)
            dir, file = relative_path.split
            dir = dir.to_s
            path = Pathname.new("/home/niharika/Desktop/ClientServer/applications/zip" + "/" + dir)
            puts path
            FileUtils.mkdir_p(path) unless File.exist?(path)
            FileUtils.cp_r project_root,path
          else
            puts "next file"
           end
        end
    compress("/home/niharika/Desktop/ClientServer/applications/zip","/home/niharika/Desktop/ClientServer/applications/zip.zip")
    app_file = File.open("/home/niharika/Desktop/ClientServer/applications/zip.zip")
    bits=RestClient.post 'http://localhost:9292/bits', :myfile => File.open("/home/niharika/Desktop/ClientServer/applications/zip.zip", 'rb')
    puts bits
    FileUtils.rm("/home/niharika/Desktop/ClientServer/applications/zip.zip")




  elsif response.code == 201
    puts "response is 201"
    puts response
    File.open('./applications/12345hgs12356/guid.json',"w") do |f|
      f.puts JSON.pretty_generate(json_response)
      f.close
  end
    response=JSON.parse(response)
    blob_json["GUID"]= response['GUID']
    blob_json = blob_json.to_json
    puts blob_json
    res = RestClient.post 'http://localhost:9292/match', {:data => blob_json}, {:content_type => 'application/json', :accept => :json}

    res=JSON.parse(res)
   guid=res['GUID']
   Dir.mkdir("/home/niharika/Desktop/ClientServer/applications/zip")
   json['ApplicationFiles'].each do |hash|
         if res['Unknown_Hash'].include? hash['Hash']
           filename= hash["FileName"]
           puts filename
           path = "/home/niharika/Desktop/ClientServer/applications/12345hgs12356" +"/"+ filename
           guid_path=  "/home/niharika/Desktop/ClientServer/applications/12345hgs12356/guid.json"
           guid_path=Pathname.new(guid_path)
           project_root  = Pathname.new(path)
           puts "sssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssssss"
           puts project_root
           FileUtils.cp_r guid_path,"/home/niharika/Desktop/ClientServer/applications/zip"
           absolute_path = Pathname.new(File.expand_path(project_root))
           application_root  = Pathname.new("/home/niharika/Desktop/ClientServer/applications/12345hgs12356")
           relative_path = absolute_path.relative_path_from(application_root)
           dir, file = relative_path.split
           dir = dir.to_s
           path = Pathname.new("/home/niharika/Desktop/ClientServer/applications/zip" + "/" + dir)
           puts path
           FileUtils.mkdir_p(path) unless File.exist?(path)
           FileUtils.cp_r project_root,path
         else
           puts "next file"
          end
       end
   compress("/home/niharika/Desktop/ClientServer/applications/zip","/home/niharika/Desktop/ClientServer/applications/zip.zip")
   app_file = File.open("/home/niharika/Desktop/ClientServer/applications/zip.zip")
   bits=RestClient.post 'http://localhost:9292/bits', :myfile => File.open("/home/niharika/Desktop/ClientServer/applications/zip.zip", 'rb')
   #puts bits
   FileUtils.rm("/home/niharika/Desktop/ClientServer/applications/zip.zip")

  end
