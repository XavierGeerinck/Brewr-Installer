# -*- mode: ruby -*-
# # vi: set ft=ruby :
require 'fileutils'
require 'rubygems'

require 'pp'
require 'json' # Ruby 1.9.2 gives us the JSON extension in it's core. So USE THAT

VAGRANTFILE_API_VERSION = "2"

# Config variables
BASE_PROJECT_DIR='projects/'

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
    # Get the folder names in the projects dir
    Dir.entries(BASE_PROJECT_DIR).select { |entry| File.directory? File.join(BASE_PROJECT_DIR,entry) and !(entry =='.' || entry == '..') }.each do |project_name|
        puts "==> takeoff: detected project '#{project_name}'"

        project_dir = BASE_PROJECT_DIR + project_name + '/'

        # Set new rules
        file = File.read(project_dir + 'config.json');
        json = JSON.parse(file)

        # Define vagrant box
        config.vm.define project_name do |project|
            # IF NO NFS: node_config.vm.synced_folder "www", "/var/www"
            #config.vm.synced_folder "www", "/var/www", :nfs => true, :mount_options => ['nolock,vers=3,udp']
            #['noatime,nolock,nosuid,vers=3,tcp,fsc']
            project.vm.synced_folder ".", json["synced_folder_location"], id: "core", :nfs => true,  :mount_options => ['nolock,vers=3,tcp,fsc,actimeo=2'], :linux__nfs_options => ["no_root_squash"], :map_uid => 0, :map_gid => 0

            # Configure Machine details
            project.vm.box = "coreos-stable"
            project.vm.box_url = "http://stable.release.core-os.net/amd64-usr/current/coreos_production_vagrant.json"
            project.vm.box_version = "= 647.2.0"
            project.vm.hostname = "#{project_name}"

            # Private network
            project.vm.network :private_network, ip: json["machine_ip"]

            # Fix authentication because of CoreOS
            project.ssh.insert_key = false

            # Disable guest additions
            project.vm.provider :virtualbox do |v|
                # On VirtualBox, we don't have guest additions or a functional vboxsf
                # in CoreOS, so tell Vagrant that so it can be smarter.
                v.check_guest_additions = false
                v.functional_vboxsf     = false

                # Set box details
                v.memory = 1024
                v.cpus = 1
                v.gui = false

                v.customize ['modifyvm', :id, '--natdnshostresolver1', 'on']

                v.name = "#{project_name}"
            end

            # plugin conflict
            if Vagrant.has_plugin?("vagrant-vbguest") then
                project.vbguest.auto_update = false
            end

            # Forward docker tcp port, should be: tcp://IP:2375
            # Run 'export DOCKER_HOST=tcp://IP:2375' to use it
            if $expose_docker_tcp
                project.vm.network "forwarded_port", guest: 2375, host: 2375, auto_correct: true
            end

            $scriptRemoveServiceFiles = <<-'EOF'
                echo "Removing all service files before provisioning them"
                if [ -d "/etc/systemd/system/multi-user.target.wants" ]
                then
                    rm -r /etc/systemd/system/multi-user.target.wants
                fi
            EOF

            # Enable the docker API and reload docker
            project.vm.provision :shell, :inline => "cat > /etc/systemd/system/docker-tcp.socket << 'EOF'
            [Unit]
            Description=Docker Socket for the API

            [Socket]
            ListenStream=2375
            Service=docker.service
            BindIPv6Only=both

            [Install]
            WantedBy=sockets.target"

            project.vm.provision :shell, :inline => "
            echo 'Ignore the warning, we need to stop and restart to enable proxy';
            systemctl enable docker-tcp.socket;
            systemctl stop docker;
            systemctl start docker-tcp.socket;
            systemctl start docker"

            # Disable automatic reboot in coreos
            project.vm.provision :shell, :inline => "echo \"REBOOT_STRATEGY=off\" >> /etc/coreos/update.conf"

            # Remove all service files before provisioning them
            project.vm.provision :shell, :inline => $scriptRemoveServiceFiles

            case ARGV[0]
            when "reload", "up"
                puts "==> takeoff: booting development environment for project '#{project_name}'"
                # Only forward ports on reload and up
                forward_ports(project, json["machine_ip"], json["programs"])
            else
              # do nothing
            end

            # Run the containers from the config above
            project.vm.provision :shell, :inline => "cd " + json["synced_folder_location"] + "; bash ./create.sh #{project_name}"
        end
    end
end

# Forward the ports that we need
def forward_ports(config, machine_ip, programs)
    # If no programs, return
    return if !programs

    programs.each do |program|
        next if !program || !program["docker_run_parameters"]

        program["docker_run_parameters"].each do |docker_command|
            next if !docker_command || !docker_command["param"] || !docker_command["value"]

            case docker_command["param"]
            when "-p"
                # If -p, then we have to forward the port. Delimiter is : and the first index is the port we need local
                ports = docker_command["value"].split(":")
                puts "==> takeoff: detected '#{ports[0]}', will forward on boot to ip '#{machine_ip}'"
                config.vm.network :forwarded_port, :host => ports[0], :guest => ports[0], :host_ip => '#{machine_ip}'
            end
        end
    end
end
