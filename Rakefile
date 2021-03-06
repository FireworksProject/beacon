ROOT = File.dirname __FILE__

task :default => :build

desc "Build App-Monitor"
build_deps = [
    'dist/package.json',
    'dist/lib/notifications.js',
    'dist/lib/monitor.js',
    'dist/lib/confserver.js',
    'dist/index.js',
    'dist/cli.js'
]
task :build => build_deps do
    puts "Built App-Monitor"
end

desc "Run Treadmill tests for App-Monitor"
task :test => [:build, :setup] do
    system 'bin/runtests'
end

task :setup => 'tmp/setup.dump' do
    puts "dev environment setup done"
end

task :clean do
    rm_rf 'tmp'
    rm_rf 'node_modules'
    rm_rf 'dist'
end

# Special development setup items that do not belong in production
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
directory 'dist'
directory 'dist/lib'

file 'dist/package.json' => ['package.json', 'dist'] do |task|
    FileUtils.cp task.prerequisites.first, task.name
    Dir.chdir 'dist'
    sh 'npm install' do |ok, id|
        ok or fail "npm could not install the monitor dependencies"
    end
    Dir.chdir ROOT
end

file 'dist/index.js' => ['index.coffee', 'dist'] do |task|
    brew_javascript task.prerequisites.first, task.name
end

file 'dist/lib/notifications.js' => ['lib/notifications.coffee', 'dist/lib'] do |task|
    brew_javascript task.prerequisites.first, task.name
end

file 'dist/lib/monitor.js' => ['lib/monitor.coffee', 'dist/lib'] do |task|
    brew_javascript task.prerequisites.first, task.name
end

file 'dist/lib/confserver.js' => ['lib/confserver.coffee', 'dist/lib'] do |task|
    brew_javascript task.prerequisites.first, task.name
end

file 'dist/cli.js' => ['cli.coffee', 'dist'] do |task|
    brew_javascript task.prerequisites.first, task.name, true
    File.chmod(0764, task.name)
end

def npm_install(package)
    sh "npm install #{package}" do |ok, id|
        ok or fail "npm could not install #{package}"
    end
end

def brew_javascript(source, target, node_exec=false)
    # If node_exec=true then include a shabang line
    File.open(target, 'w') do |fd|
        if node_exec
            fd << "#!/usr/bin/env node\n\n"
        end
        fd << %x[coffee -pb #{source}]
    end
end
