require 'fileutils'
require 'json'
require 'pathname'
require 'digest'
require 'find'
require 'rest-client'
require 'zip'


$directory_stack=[]
$tree_array = Array.new

#puts Dir.pwd

def compress(path, file)

  Zip::File.open(file, Zip::File::CREATE) do |zipfile|
    Dir.chdir path
    Dir.glob("**/*").reject {|fn| File.directory?(fn) }.each do |file|
      next if file == '/home/niharika/Desktop/ClientServer/applications/45sasa653276gdsffdd/guid.json'
      puts "Adding #{file}"
      path=path.to_s
      zipfile.add(file.sub(path + '/', ''), file)
    end
  end
end

first_push = Time.now
Find.find('./applications/45sasa653276gdsffdd/') { |path|
  path = Pathname.new(Pathname.pwd + path)
  #puts path
  if File.directory?path
      #puts "directory"
      $directory_stack << path
  end
  #puts path
}
#puts directory_stack
$file_hash_json = Hash.new
$request_json=Hash.new
def create_tree(dir)
    folder_array = Array.new
    joint_hash=Array.new
    folder_json=Hash.new
    file_json=Hash.new
    dir_json=Hash.new

    request_array=Array.new

    #puts dir
    dir.children.each do |child|
        if File.directory?child
            $tree_array.each do |d|

               child = child.to_s
              if d.include?(child)
                #puts child
                child_hash = d.fetch(child)
                #puts child_hash
                file_json[child.to_s] = child_hash["hash"]
              #puts file_json
                folder_array << file_json
                joint_hash << child_hash["hash"]
                request_array << child_hash["hash"]
              end
            end
        else
          file_content = File.read(child)
          #puts file_content
          hash_content= Digest::SHA1.hexdigest file_content
          $file_hash_json[child.to_s] = hash_content
          #puts child
          #puts child
          #puts hash_content
          file_json[child.to_s] =  hash_content
          #puts file_json
          folder_array << file_json
          joint_hash << hash_content
          request_array << hash_content
        end
  end
  folder_hash = Digest::SHA1.hexdigest joint_hash.join
  folder_json["hash"] = folder_hash
  folder_json["children"] = folder_array
  $request_json[folder_hash] = request_array
#puts $request_json
  #puts folder_json
  dir_json[dir.to_s] = folder_json

  $tree_array << dir_json
  #puts dir_json
   $request_json["start"] = folder_hash
  if $directory_stack.any?
    #puts $directory_stack.count
    directory=$directory_stack.pop
     create_tree(directory)
     return $request_json
  else
     return $request_json
  end

end

d=$directory_stack.pop
create_tree(d)
puts GC.stat
tree_calc = Time.now - first_push
puts "tree_calc"
puts tree_calc
#puts $request_json
$request_json["ApplicationName"] = "45sasa653276gdsffdd"

jdata = {"Name" => "45sasa653276gdsffdd"}.to_json
begin
  File.new("./applications/45sasa653276gdsffdd/guid.json", File::RDWR|File::CREAT|File::EXCL)
rescue
  puts "file exists"
end


#puts blob_json



response = RestClient.post 'http://localhost:9000/apps', {:data => jdata}, {:content_type => :json, :accept => :json}
json_response=JSON.parse(response)
if response.code == 200
  guidjson = JSON.parse(File.read("./applications/45sasa653276gdsffdd/guid.json"))

  if guidjson['GUID']==json_response['GUID']

    $request_json["GUID"]= guidjson['GUID']
    blob_json = $request_json.to_json
    File.open('./applications/45sasa653276gdsffdd/guid.json',"w") do |f|
          f.puts JSON.pretty_generate($request_json)
          f.close
      end
      #puts $request_json
      match_response=RestClient.post 'http://localhost:9000/match', :myfile => File.open("/home/niharika/Desktop/ClientServer/applications/45sasa653276gdsffdd/guid.json", 'rb')
     #match_response=RestClient.post 'http://localhost:9000/match', {:data => $request_json}, {:content_type => :json, :accept => :json}
     puts match_response
     res = JSON.parse(match_response)
    guid=res['GUID']
     Dir.mkdir("/home/niharika/Desktop/ClientServer/applications/zip")
     #puts $file_hash_json
    # puts $file_hash_json.values
     res['unknown_hash'].each do |unknown_hash|
       if $file_hash_json.values.include? unknown_hash
        #  puts "SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS"
        #  puts unknown_hash
        #  puts "SSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSSS"
         unknown_file =  $file_hash_json.key(unknown_hash)
         guid_path=  "/home/niharika/Desktop/ClientServer/applications/45sasa653276gdsffdd/guid.json"
         guid_path=Pathname.new(guid_path)
         project_root  = Pathname.new(unknown_file)
        #  puts project_root
        #  puts project_root.class
         FileUtils.cp_r guid_path,"/home/niharika/Desktop/ClientServer/applications/zip"
         absolute_path = Pathname.new(File.expand_path(project_root))
         #puts absolute_path
         application_root  = Pathname.new("/home/niharika/Desktop/ClientServer/applications/45sasa653276gdsffdd")
         relative_path = absolute_path.relative_path_from(application_root)
         dir, file = relative_path.split
         #puts dir
         dir = dir.to_s
         path = Pathname.new("/home/niharika/Desktop/ClientServer/applications/zip" + "/" + dir)
         #puts path
         FileUtils.mkdir_p(path) unless File.exists?(path)
         FileUtils.cp_r project_root,path
        else
         puts "next file"
       end
     end
     compress_time = Time.now
    compress("/home/niharika/Desktop/ClientServer/applications/zip","/home/niharika/Desktop/ClientServer/applications/zip.zip")
    compress_time_end = Time.now - compress_time
    bits_time = Time.now
    bits=RestClient.post 'http://localhost:9000/bits', :myfile => File.open("/home/niharika/Desktop/ClientServer/applications/zip.zip", 'rb')
   #puts bits
   bits_time_end = Time.now - bits_time
   puts bits_time_end
   second_push_end = Time.now - first_push
   puts second_push_end
    FileUtils.rm("/home/niharika/Desktop/ClientServer/applications/zip.zip")
#
#
#
end
  elsif response.code == 201
    puts "response is 201"
    puts response
    response=JSON.parse(response)
    $request_json["GUID"]= response['GUID']
    blob_json = $request_json.to_json
    File.open('./applications/45sasa653276gdsffdd/guid.json',"w") do |f|
          f.puts JSON.pretty_generate($request_json)
          f.close
      end
      res = RestClient.post 'http://localhost:9000/match', :myfile => File.open("/home/niharika/Desktop/ClientServer/applications/45sasa653276gdsffdd/guid.json", 'rb')
    #res = RestClient.post 'http://localhost:9000/match', {:data => $request_json}, {:content_type => :json, :accept => :json}
    res=JSON.parse(res)
    guid=res['GUID']
    compress_time = Time.now
   compress("/home/niharika/Desktop/ClientServer/applications/45sasa653276gdsffdd","/home/niharika/Desktop/ClientServer/applications/zip.zip")
   compress_time_end = Time.now - compress_time
   puts compress_time_end
   app_file = File.open("/home/niharika/Desktop/ClientServer/applications/zip.zip")
   bits_time= Time.now
   bits=RestClient.post 'http://localhost:9000/bits', :myfile => File.open("/home/niharika/Desktop/ClientServer/applications/zip.zip", 'rb'), :timeout=> 3600
   bits_time_end = Time.now - bits_time
   puts bits_time_end
      #puts bits
   first_push_end = Time.now - first_push
   puts first_push_end
   FileUtils.rm("/home/niharika/Desktop/ClientServer/applications/zip.zip")
   end

