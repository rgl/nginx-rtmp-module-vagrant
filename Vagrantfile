Vagrant.configure(2) do |config|
  config.vm.box = 'ubuntu-16.04-amd64'

  config.vm.hostname = 'streaming'

  config.vm.provider 'virtualbox' do |vb|
    vb.linked_clone = true
    vb.memory = 3072
    vb.cpus = 2
  end

  config.vm.network "private_network", ip: "10.0.0.2"

  config.vm.provision 'shell', path: 'provision-base.sh'
  config.vm.provision 'shell', path: 'provision-nginx-rtmp-module.sh'
  config.vm.provision 'shell', path: 'provision-videos.sh'
end
