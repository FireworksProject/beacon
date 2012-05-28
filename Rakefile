task :default => :build

desc "Build App-Monitor"
build_deps = [
]
task :build do
    puts "Built App-Monitor"
end

desc "Run Treadmill tests for App-Monitor"
task :test => :setup do
    system 'bin/runtests'
end

task :setup => 'tmp/setup.dump' do
    puts "dev environment setup done"
end

task :clean do
    rm_rf 'tmp'
    rm_rf 'node_modules'
end

file 'tmp/setup.dump' => ['dev.list', 'tmp'] do |task|
    list = File.open(task.prerequisites.first, 'r')
    list.each do |line|
        npm_install(line)
    end
    File.open(task.name, 'w') do |fd|
        fd << "done"
    end
end

directory 'tmp'

def npm_install(package)
    sh "npm install #{package}" do |ok, id|
        ok or fail "npm could not install #{package}"
    end
end
