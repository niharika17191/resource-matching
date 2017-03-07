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
      next if file == '/home/niharika/Desktop/ClientServer/applications/45653276hjdshf/guid.json'
      #      puts "Adding #{file}"
      path=path.to_s
      zipfile.add(file.sub(path + '/', ''), file)
    end
  end
end



def find_files()				#iteratively finds files in a directory

  hash=Array.new
  file_array =Array.new
  file_array =  Dir[ File.join('./applications/45653276hjdshf/', '**', '*') ].reject { |p| File.directory? p }
  file_array.each do |file|
    absolute_path = Pathname.new(File.expand_path(file))
    project_root  = Pathname.new("/home/niharika/Desktop/ClientServer/applications/45653276hjdshf")
    relative_path = absolute_path.relative_path_from(project_root)
    relative_file_path= relative_path.to_s
    directory,base = relative_path.split
    directory_s=directory.to_s
    base_s=base.to_s
    #    puts directory
    #    puts base
    if directory_s== "."        #if it is file directly in root folder
      file_content= File.read(file)
      #      puts file_content
      hash_content= Digest::SHA1.hexdigest file_content
    else                        #if its a directory
      file_content = File.read(file)
      hash_content= Digest::SHA1.hexdigest file_content
      new_path = File.join(directory_s,hash_content)
      hash_content=new_path
    end

    file_data= JSON.parse({"FileName" => relative_file_path, "Hash"=> hash_content}.to_json)
    hash << file_data
  end
  jdata = {"ApplicationName"=> "45653276hjdshf", "ApplicationFiles" => hash}.to_json
  #puts jdata
  return jdata
end


start = Time.now
complete_json = find_files()
blob_array=Array.new
json = JSON.parse(complete_json)
json["ApplicationFiles"].each_index do |o|
  file = json["ApplicationFiles"][o]["Hash"]
  blob_array << file
end
blob_json= JSON.parse({"Blob_array" => blob_array}.to_json)
#puts blob_json
sha_end = Time.now - start
jdata = {"Name" => json["ApplicationName"]}.to_json
begin
  File.new("./applications/45653276hjdshf/guid.json", File::RDWR|File::CREAT|File::EXCL)
rescue
  puts "file exists"
end





response = RestClient.post 'http://localhost:9000/apps', {:data => jdata}, {:content_type => :json, :accept => :json}
json_response=JSON.parse(response)
#puts json_response
#puts response.code
#puts json_response
if response.code == 200
  guidjson = JSON.parse(File.read("./applications/45653276hjdshf/guid.json"))
  guidjson = JSON.parse(guidjson)
  puts guidjson.class
  puts json_response['GUID']
  if guidjson['GUID'] == json_response['GUID']
    blob_json["GUID"]= guidjson['GUID']
    blob_json = blob_json.to_json
    #puts blob_json
    puts "above match"
    match_start= Time.now
    puts match_start
    match_response = RestClient.post 'http://localhost:9000/match', {:data => blob_json}, {:content_type => 'application/json', :accept => :json}
    match_end = Time.now - match_start
    puts match_response
    res=JSON.parse(match_response)
    guid=res['GUID']
    json["GUID"]= guid
    json = json.to_json
    File.open('./applications/45653276hjdshf/guid.json',"w") do |f|
      f.puts JSON.pretty_generate(json)
      f.close
    end

    puts json = JSON.parse(json)
    Dir.mkdir("/home/niharika/Desktop/ClientServer/applications/zip")
    json['ApplicationFiles'].each do |hash|
      if res['Known_Hash'].include?hash['Hash']
        #puts "file present"
      else
        json["ApplicationFiles"].each_index do |o|
          if hash['Hash'] == json["ApplicationFiles"][o]["Hash"]
            filename= json["ApplicationFiles"][o]["FileName"]
            path = "/home/niharika/Desktop/ClientServer/applications/45653276hjdshf" +"/"+ filename
            guid_path=  "/home/niharika/Desktop/ClientServer/applications/45653276hjdshf/guid.json"
            guid_path=Pathname.new(guid_path)
            project_root  = Pathname.new(path)
            #puts project_root
            FileUtils.cp_r guid_path,"/home/niharika/Desktop/ClientServer/applications/zip"
            absolute_path = Pathname.new(File.expand_path(project_root))
            application_root  = Pathname.new("/home/niharika/Desktop/ClientServer/applications/45653276hjdshf")
            relative_path = absolute_path.relative_path_from(application_root)
            dir, file = relative_path.split
            dir = dir.to_s
            path = Pathname.new("/home/niharika/Desktop/ClientServer/applications/zip" + "/" + dir)
            #puts path
            FileUtils.mkdir_p(path) unless File.exist?(path)
            FileUtils.cp_r project_root,path
          end
        end
      end
    end
    compress("/home/niharika/Desktop/ClientServer/applications/zip","/home/niharika/Desktop/ClientServer/applications/zip.zip")
    app_file = File.open("/home/niharika/Desktop/ClientServer/applications/zip.zip")
    bits_start = Time.now
    bits=RestClient.post 'http://localhost:9000/bits', :myfile => File.open("/home/niharika/Desktop/ClientServer/applications/zip.zip", 'rb')
    bits_end = Time.now - bits_start
    #  puts bits
    FileUtils.rm("/home/niharika/Desktop/ClientServer/applications/zip.zip")
  end
elsif response.code == 201
  #  puts "response is 201"
  #puts response
  json["GUID"]= json_response['GUID']

  File.open('./applications/45653276hjdshf/guid.json',"w") do |f|
    f.puts JSON.pretty_generate(json)
    f.close
  end

  response=JSON.parse(response)
  blob_json["GUID"]= response['GUID']
  blob_json = blob_json.to_json
  #puts blob_json
  match_start = Time.now
  puts match_start
  res = RestClient.post 'http://localhost:9000/match', {:data => blob_json}, {:content_type => 'application/json', :accept => :json}
  match_end = Time.now - match_start
  res = res.to_s
  path = response['Name']
  Dir.chdir("applications")
  path = Dir.pwd + "/" + path
  path=Pathname.new(path)
  #puts path.class
  begin
    File.new("./applications/zip.zip",File::RDWR|File::CREAT|File::EXCL)
  rescue
    puts "file exists"
  end
  #  puts json

  Dir.mkdir("/home/niharika/Desktop/ClientServer/applications/zip")
  FileUtils.copy_entry path, "/home/niharika/Desktop/ClientServer/applications/zip"
  guid_path=  "/home/niharika/Desktop/ClientServer/applications/45653276hjdshf/guid.json"
  FileUtils.cp_r guid_path,"/home/niharika/Desktop/ClientServer/applications/zip"
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
  bits_start = Time.now
  bits=RestClient.post 'http://localhost:9000/bits', :myfile => File.open("/home/niharika/Desktop/ClientServer/applications/zip.zip", 'rb')
  bits_end = Time.now - bits_start
  #puts bits
  FileUtils.rm("/home/niharika/Desktop/ClientServer/applications/zip.zip")
  #Dir.delete("/home/niharika/Desktop/ClientServer/applications/zip")
end

puts sha_end
puts match_start
puts match_end
puts bits_start
puts bits_end
puts Time.now - start
